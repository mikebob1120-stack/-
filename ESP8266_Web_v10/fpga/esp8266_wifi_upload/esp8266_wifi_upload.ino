#include <ESP8266WiFi.h>
#include "phone_assets.h"
#include <ESP8266WebServer.h>
// APP-only local API with FAT32 8.3 uploader. No browser pages are hosted.
// Transport: D8/GPIO15 TX, D7/GPIO13 RX, 115200 8N1, FPGA menu 4.
// Physical sectors use the framed UART bridge; FAT32 is owned by this sketch.
ESP8266WebServer web(80);
static const char SSID[]="FPGA-MUSIC", PASS[]="Music2026";
static uint8_t sec[512], checkSec[512], payload[512], name83[11];
static uint32_t volume, fatStart, fatSize, dataStart, totalSectors;
static uint32_t rootCluster, maxCluster, firstCluster, clustersNeeded;
static uint32_t expectedSize, receivedSize, fileCRC;
static uint32_t dirLba, cachedFatLba=0xffffffffUL;
static uint8_t dirOffset, sectorsPerCluster, fatCopies;
static uint16_t used=0;
static bool active=false, failed=true, geometry=false;
static bool chunkOk=false, chunkEnded=false;
static uint32_t lastProgress=0;
static String result="Ready";
// Bottom-board SW1/SW2/SW3 are active-low (external pull-ups).
// FPGA synthesizes the sound. ESP only sends framed control settings.
// Cold-start sound: one timbre (A), dry effect, metronome off.
// SW1/SW2/SW3 and phone controls may change these after startup.
static constexpr uint8_t START_TIMBRE_A=0, START_TIMBRE_B=2;
static constexpr uint8_t START_VOICE_MODE=0, START_EFFECT_MODE=0, START_METRONOME=0;
static uint8_t timbreA=START_TIMBRE_A, timbreB=START_TIMBRE_B;
static uint8_t voiceMode=START_VOICE_MODE;
static uint8_t effectMode=START_EFFECT_MODE, metronomeOn=START_METRONOME;
static uint8_t vibratoDepth=2; // Default V depth is now audibly stronger; FX still starts off.
// FPGA owns the power-on state. Do not replay locally cached mode/effect
// values when Wi-Fi starts or when the FPGA comes online later.
static bool controlDirty=false, effectDirty=false, depthDirty=false;
static uint32_t lastControlAttempt=0;
struct PerfButton {
  uint8_t pin;
  bool rawDown, stableDown, armed;
  uint32_t changedAt, pressedAt;
};
static PerfButton perfButtons[3]={{5,false,false,false,0,0},{4,false,false,false,0,0},
                                  {14,false,false,false,0,0}};
static uint16_t crc16(uint16_t c,uint8_t v){
  c ^= uint16_t(v)<<8;
  for(int i=0;i<8;i++) c=(c&0x8000)?(c<<1)^0x1021:c<<1;
  return c;
}
static uint32_t crc32(uint32_t c,uint8_t v){
  c^=v; for(int i=0;i<8;i++) c=(c>>1)^((c&1)?0xedb88320UL:0); return c;
}
static uint16_t readLe16(const uint8_t *p){return uint16_t(p[0])|(uint16_t(p[1])<<8);}
static uint32_t readLe32(const uint8_t *p){return uint32_t(p[0])|(uint32_t(p[1])<<8)|
  (uint32_t(p[2])<<16)|(uint32_t(p[3])<<24);}
static void put16(uint8_t *p,uint16_t v){p[0]=v; p[1]=v>>8;}
static void put32(uint8_t *p,uint32_t v){
  for(int i=0;i<4;i++)p[i]=uint8_t(v>>(i*8));
}
static bool frame(uint8_t cmd,const uint8_t *p,uint8_t n,uint32_t timeout=5000){
  while(Serial.available())Serial.read();
  uint16_t c=crc16(crc16(0xffff,cmd),n);
  Serial.write(0xa5); Serial.write(cmd); Serial.write(n);
  for(int i=0;i<n;i++){Serial.write(p[i]); c=crc16(c,p[i]);}
  Serial.write(uint8_t(c)); Serial.write(uint8_t(c>>8)); Serial.flush();
  uint32_t deadline=millis()+timeout;
  while((int32_t)(millis()-deadline)<0){
    if(Serial.available())return Serial.read()==0x06;
    yield();
  }
  return false;
}
static void cycleTimbreA(){
  timbreA=(timbreA+1)%3;
  if(timbreB==timbreA)timbreB=(timbreB+1)%3;
  controlDirty=true;
}
static void cycleTimbreB(){
  do {timbreB=(timbreB+1)%3;} while(timbreB==timbreA);
  controlDirty=true;
}
static void cycleVoiceMode(){voiceMode=(voiceMode+1)%3;controlDirty=true;}
static void cycleEffectMode(){effectMode=(effectMode+1)%3;effectDirty=true;}
static void toggleMetronome(){metronomeOn^=1;effectDirty=true;}
static void pollPerformanceButtons(){
  const uint32_t now=millis();
  for(uint8_t i=0;i<3;i++){
    PerfButton &b=perfButtons[i];
    const bool down=(digitalRead(b.pin)==LOW);
    if(down!=b.rawDown){b.rawDown=down;b.changedAt=now;}
    // A switch sampled low while ESP Wi-Fi/pull-ups are starting must not
    // become an artificial press on its first high reading. Arm each input
    // only after it has been released steadily for 50 ms.
    if(!b.armed){
      if(!down && (uint32_t)(now-b.changedAt)>=50){
        b.armed=true;b.stableDown=false;
      }
      continue;
    }
    if(down!=b.stableDown && (uint32_t)(now-b.changedAt)>=25){
      b.stableDown=down;
      if(down)b.pressedAt=now;
      else if(i==0){
        if((uint32_t)(now-b.pressedAt)>=650)cycleTimbreB();
        else cycleTimbreA();
      } else if(i==1)cycleVoiceMode();
      else if((uint32_t)(now-b.pressedAt)>=650)toggleMetronome();
      else cycleEffectMode();
    }
  }
  // Send only changed controls. Periodic replay overwrote the FPGA's M0,
  // beat-off startup after an FPGA-only reboot.
  if(!active && (controlDirty || effectDirty || depthDirty) &&
     (lastControlAttempt==0 || (uint32_t)(now-lastControlAttempt)>=1000)){
    uint8_t tone[3]={timbreA,timbreB,voiceMode};
    uint8_t effect[2]={effectMode,metronomeOn};
    if(controlDirty && frame(0x30,tone,3,120))controlDirty=false;
    if(effectDirty && frame(0x31,effect,2,120))effectDirty=false;
    if(depthDirty && frame(0x38,&vibratoDepth,1,120))depthDirty=false;
    lastControlAttempt=(controlDirty || effectDirty || depthDirty) ? (now ? now : 1) : 0;
  }
}
#ifdef FAT32_HOST_TEST
extern bool host_read(uint32_t lba,uint8_t *out);
extern bool host_write(uint32_t lba,const uint8_t *in);
static bool readSector(uint32_t lba,uint8_t *out){return host_read(lba,out);}
static bool writeSector(uint32_t lba,const uint8_t *in){return host_write(lba,in);}
#else
static bool readSector(uint32_t lba,uint8_t *out){
  uint8_t arg[4];put32(arg,lba);
  if(!frame(0x10,arg,4,4000))return false;
  uint32_t deadline=millis()+6000;
  for(int i=0;i<512;i++){
    while(!Serial.available()){
      if((int32_t)(millis()-deadline)>=0)return false;
      yield();
    }
    out[i]=uint8_t(Serial.read());
  }
  return true;
}
static bool writeSector(uint32_t lba,const uint8_t *in){
  uint8_t arg[4];put32(arg,lba);
  if(!frame(0x11,arg,4))return false;
  for(int i=0;i<512;i+=128)if(!frame(0x12,in+i,128))return false;
  if(!frame(0x13,nullptr,0,15000))return false;
  if(!readSector(lba,checkSec))return false;
  for(int i=0;i<512;i++)if(checkSec[i]!=in[i])return false;
  return true;
}
#endif
static bool loadGeometry(){
  if(!readSector(0,sec)||sec[510]!=0x55||sec[511]!=0xaa)return false;
  if(readLe16(sec+11)==512)volume=0;
  else {
    uint8_t type=sec[450];
    if(type!=0x0b&&type!=0x0c)return false;
    volume=readLe32(sec+454);
    if(!volume||!readSector(volume,sec))return false;
  }
  uint32_t reserved=readLe16(sec+14);
  sectorsPerCluster=sec[13]; fatCopies=sec[16]; fatSize=readLe32(sec+36);
  rootCluster=readLe32(sec+44)&0x0fffffffUL;
  totalSectors=readLe32(sec+32);
  if(readLe16(sec+11)!=512 || !reserved || !fatSize || !totalSectors ||
     !sectorsPerCluster || (sectorsPerCluster&(sectorsPerCluster-1)) ||
     sectorsPerCluster>128 || fatCopies==0 || fatCopies>2 ||
     readLe16(sec+17)!=0 || readLe16(sec+22)!=0 || rootCluster<2 ||
     ((readLe16(sec+40)&0x0080) && (readLe16(sec+40)&0x000f)) ||
     sec[510]!=0x55 || sec[511]!=0xaa)return false;
  fatStart=volume+reserved;
  dataStart=fatStart+fatCopies*fatSize;
  uint32_t overhead=reserved+fatCopies*fatSize;
  if(totalSectors<=overhead)return false;
  maxCluster=(totalSectors-overhead)/sectorsPerCluster+1;
  if(maxCluster<65525 || rootCluster>maxCluster || fatSize*128UL<=maxCluster)return false;
  cachedFatLba=0xffffffffUL; geometry=true; return true;
}
static bool fatEntry(uint32_t cluster,uint32_t &value){
  uint32_t lba=fatStart+(cluster>>7);
  if(lba!=cachedFatLba){if(!readSector(lba,sec))return false;cachedFatLba=lba;}
  value=readLe32(sec+4*(cluster&127))&0x0fffffffUL;
  return true;
}
static uint32_t clusterLba(uint32_t cluster){
  return dataStart+(cluster-2)*sectorsPerCluster;
}
static bool encodeShortName(const String &original){
  String s=original;s.toUpperCase(); int dot=s.lastIndexOf('.');
  if(dot<1||dot>8||s.length()!=dot+4)return false;
  String ext=s.substring(dot+1);
  if(!(ext=="WAV")&&!(ext=="NTE"))return false;
  memset(name83,' ',11);
  for(int i=0;i<dot;i++){
    char c=s[i];
    if(!((c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='_'))return false;
    name83[i]=c;
  }
  for(int i=0;i<3;i++)name83[8+i]=ext[i];
  return true;
}
static bool directorySlot(){
  uint32_t cluster=rootCluster, link=0;
  bool found=false;
  for(uint32_t depth=0;depth<4096;depth++){
    if(cluster<2||cluster>maxCluster)return false;
    for(uint8_t sector=0;sector<sectorsPerCluster;sector++){
      uint32_t lba=clusterLba(cluster)+sector;
      if(!readSector(lba,sec))return false;
      for(uint8_t e=0;e<16;e++){
        uint8_t *p=sec+e*32;
        if(p[0]==0||p[0]==0xe5){
          if(!found){found=true;dirLba=lba;dirOffset=e;}
          if(p[0]==0)return true;
        } else if(p[11]!=0x0f && (p[11]&0x18)==0 &&
                  memcmp(p,name83,11)==0)return false;
      }
    }
    if(!fatEntry(cluster,link))return false;
    if(link>=0x0ffffff8UL)return found;
    cluster=link;
  }
  return false;
}
static bool findFreeRun(){
  uint32_t streak=0,first=0,val=0;
  for(uint32_t c=2;c<=maxCluster;c++){
    if(!fatEntry(c,val))return false;
    if(val==0){if(streak++==0)first=c; if(streak==clustersNeeded){firstCluster=first;return true;}}
    else streak=0;
    if((c&1023)==0)yield();
  }
  return false;
}
static bool beginFile(const String &s,uint32_t size){
  if(!encodeShortName(s)||size==0||size>32UL*1024UL*1024UL){result="Invalid name or size (max 32 MiB)";return false;}
  if(name83[8]=='N' && size>256){result="NTE must be 1..256 bytes";return false;}
#ifndef FAT32_HOST_TEST
  if(!frame(0x20,nullptr,0)){result="Select FPGA menu 4 first";return false;}
#endif
  if(!loadGeometry()){result="Unsupported card: FAT32 required";return false;}
  expectedSize=size;receivedSize=0;used=0;fileCRC=0xffffffffUL;
  clustersNeeded=(size+(uint32_t)sectorsPerCluster*512-1)/
                 ((uint32_t)sectorsPerCluster*512);
  if(!directorySlot()){result="Duplicate name or root directory full";return false;}
  if(!findFreeRun()){result="No contiguous free area";return false;}
  return true;
}
static bool flushData(){
  if(!used)return true;
  uint32_t block=receivedSize-used;
  uint32_t lba=clusterLba(firstCluster)+block/512;
  if(lba>=volume+totalSectors)return false;
  for(uint16_t i=used;i<512;i++)payload[i]=0;
  bool ok=writeSector(lba,payload);
  used=0;return ok;
}
static bool appendData(const uint8_t *p,size_t n){
  if(n>expectedSize-receivedSize)return false;
  for(size_t i=0;i<n;i++){
    if(name83[8]=='N' && p[i]==0)return false;
    payload[used++]=p[i];fileCRC=crc32(fileCRC,p[i]);receivedSize++;
    if(name83[8]=='W' && receivedSize==12 &&
       (memcmp(payload,"RIFF",4)!=0 || memcmp(payload+8,"WAVE",4)!=0))return false;
    if(used==512 && !flushData())return false;
  }
  return true;
}
static bool commitFatChain(){
  const uint32_t last=firstCluster+clustersNeeded-1;
  for(uint32_t fs=firstCluster>>7;fs<=(last>>7);fs++){
    for(uint8_t f=0;f<fatCopies;f++){
      uint32_t lba=fatStart+f*fatSize+fs;
      if(!readSector(lba,sec))return false;
      uint32_t begin=firstCluster>fs*128?firstCluster:fs*128;
      uint32_t stop=last<fs*128+127?last:fs*128+127;
      for(uint32_t c=begin;c<=stop;c++){
        uint16_t off=(c&127)*4;
        uint32_t value=(c==last)?0x0fffffffUL:c+1;
        put32(sec+off,(readLe32(sec+off)&0xf0000000UL)|value);
      }
      if(!writeSector(lba,sec))return false;
    }
    yield();
  }
  cachedFatLba=0xffffffffUL;return true;
}
static bool commitFile(){
  if(receivedSize!=expectedSize||!flushData())return false;
  // Data have been read back. Only now allocate clusters, then publish the
  // directory entry last. Power loss here may leak new clusters, but must not
  // overwrite any old file or announce success.
  if(!commitFatChain())return false;
  if(!readSector(dirLba,sec))return false;
  uint8_t *e=sec+uint16_t(dirOffset)*32;
  if(e[0]!=0&&e[0]!=0xe5)return false;
  memset(e,0,32);memcpy(e,name83,11);e[11]=0x20;
  put16(e+20,firstCluster>>16);put16(e+26,firstCluster&0xffff);
  put32(e+28,expectedSize);
  return writeSector(dirLba,sec);
}
static void onChunkUpload(){
  HTTPUpload &u=web.upload();
  switch(u.status){
    case UPLOAD_FILE_START:
      chunkEnded=false;
      chunkOk=active && !failed;
      if(!chunkOk)result="No active upload; enter menu 4 and restart";
      break;
    case UPLOAD_FILE_WRITE:
      if(chunkOk && !appendData(u.buf,u.currentSize)){
        failed=true;active=false;chunkOk=false;
        result=String("WAV/NTE data invalid or SD write/readback error at byte ")+String(receivedSize);
        frame(0x21,nullptr,0);
      }
      break;
    case UPLOAD_FILE_END:
      chunkEnded=true;
      break;
    case UPLOAD_FILE_ABORTED:
      active=false;failed=true;chunkOk=false;result="Transfer aborted";
      frame(0x21,nullptr,0);break;
  }
}

// All phone requests use the existing D8/D7 UART. No extra pins or modules.
static uint8_t phoneReply[512];
static bool readReply(uint8_t command,const uint8_t *args,uint8_t len,uint16_t n){
  if(!frame(command,args,len,600))return false;
  const uint32_t deadline=millis()+1200;
  for(uint16_t i=0;i<n;i++){
    while(!Serial.available()){
      if((int32_t)(millis()-deadline)>=0)return false;
      yield();
    }
    phoneReply[i]=(uint8_t)Serial.read();
  }
  return true;
}
static void binaryReply(uint16_t n){
  web.sendHeader("Cache-Control","no-store");
  web.setContentLength(n);
  web.send(200,"application/octet-stream","");
  web.sendContent((const char*)phoneReply,n);
}
static void phoneRoutes(){
  web.on("/",HTTP_GET,[](){
    web.sendHeader("Cache-Control","no-store");
    web.sendHeader("Content-Encoding","gzip");
    web.send_P(200,"text/html; charset=utf-8",(const char*)PHONE_INDEX,sizeof(PHONE_INDEX));
  });
  web.on("/renderer.js",HTTP_GET,[](){
    web.sendHeader("Cache-Control","no-store");
    web.sendHeader("Content-Encoding","gzip");
    web.send_P(200,"application/javascript; charset=utf-8",(const char*)PHONE_RENDERER,sizeof(PHONE_RENDERER));
  });
  web.on("/app.js",HTTP_GET,[](){
    web.sendHeader("Cache-Control","no-store");
    web.sendHeader("Content-Encoding","gzip");
    web.send_P(200,"application/javascript; charset=utf-8",(const char*)PHONE_APP,sizeof(PHONE_APP));
  });
  web.on("/worker-source.js",HTTP_GET,[](){
    web.sendHeader("Cache-Control","no-store");
    web.sendHeader("Content-Encoding","gzip");
    web.send_P(200,"application/javascript; charset=utf-8",(const char*)PHONE_WORKER,sizeof(PHONE_WORKER));
  });
  web.on("/upload",HTTP_GET,[](){
    web.sendHeader("Location","/#uploadSection");web.send(302,"text/plain","");
  });
  web.on("/api/status",HTTP_GET,[](){
    if(!readReply(0x34,nullptr,0,96)){
      web.send(503,"text/plain","FPGA not responding: flash the matching phone-control FPGA firmware");return;
    }
    uint16_t c=0xffff;for(uint8_t i=0;i<94;i++)c=crc16(c,phoneReply[i]);
    if(phoneReply[0]!='Y'||phoneReply[1]!='L'||phoneReply[2]!=2){
      web.send(502,"text/plain","FPGA version mismatch: rebuild and program the v13 FPGA project");return;
    }
    if(readLe16(phoneReply+94)!=c){
      web.send(502,"text/plain","Invalid FPGA state checksum");return;
    }
    // Match the local button-cycle baselines to the actual FPGA state.
    // Keep a newly pressed button's pending change until its UART ACK.
    if(!controlDirty){
      timbreA=phoneReply[12]&3;timbreB=phoneReply[13]&3;voiceMode=phoneReply[14]&3;
    }
    if(!effectDirty){effectMode=phoneReply[15]&3;metronomeOn=phoneReply[16]&1;}
    if(!depthDirty)vibratoDepth=phoneReply[88]&3;
    binaryReply(96);
  });
  web.on("/api/action",HTTP_POST,[](){
    if(active){web.send(423,"text/plain","Upload is active");return;}
    int action=web.arg("action").toInt(),value=web.arg("value").toInt();
    if(action<1||action>7||value<0||value>7){web.send(400,"text/plain","Invalid action");return;}
    uint8_t a[2]={(uint8_t)action,(uint8_t)value};
    bool ok=frame(0x32,a,2,200);
    web.send(ok?200:409,"text/plain",ok?"OK":"FPGA refused: check upload lock or firmware");
  });
  web.on("/api/keys",HTTP_POST,[](){
    int value=web.arg("mask").toInt();
    if(active||value<0||value>255){web.send(409,"text/plain","Keys unavailable");return;}
    uint8_t a=(uint8_t)value;bool ok=frame(0x33,&a,1,150);
    web.send(ok?200:409,"text/plain",ok?"OK":"Enter PLAY LIVE first");
  });
  web.on("/api/tone",HTTP_POST,[](){
    int a=web.arg("a").toInt(),b=web.arg("b").toInt(),m=web.arg("mode").toInt();
    if(active||a<0||a>2||b<0||b>2||m<0||m>2){web.send(409,"text/plain","Tone unavailable");return;}
    uint8_t p[3]={(uint8_t)a,(uint8_t)b,(uint8_t)m};bool ok=frame(0x30,p,3,150);
    if(ok){timbreA=a;timbreB=b;voiceMode=m;controlDirty=false;}
    web.send(ok?200:409,"text/plain",ok?"OK":"Tone refused");
  });
  web.on("/api/effect",HTTP_POST,[](){
    int fx=web.arg("fx").toInt(),beat=web.arg("beat").toInt();
    if(active||fx<0||fx>2||beat<0||beat>1){web.send(409,"text/plain","Effect unavailable");return;}
    uint8_t p[2]={(uint8_t)fx,(uint8_t)beat};bool ok=frame(0x31,p,2,150);
    if(ok){effectMode=fx;metronomeOn=beat;effectDirty=false;}
    web.send(ok?200:409,"text/plain",ok?"OK":"Effect refused");
  });
  web.on("/api/vibrato",HTTP_POST,[](){
    int depth=web.arg("depth").toInt();
    if(active||depth<0||depth>3){web.send(409,"text/plain","Depth unavailable");return;}
    uint8_t p=(uint8_t)depth;bool ok=frame(0x38,&p,1,150);
    if(ok){vibratoDepth=p;depthDirty=false;}
    web.send(ok?200:409,"text/plain",ok?"OK":"Depth refused");
  });
  web.on("/api/settings",HTTP_POST,[](){
    int f=web.arg("flags").toInt(),v=web.arg("volume").toInt(),b=web.arg("bend").toInt();
    if(active||f<0||f>3||v<0||v>255||b<0||b>255){web.send(400,"text/plain","Invalid settings");return;}
    uint8_t p[3]={(uint8_t)f,(uint8_t)v,(uint8_t)b};bool ok=frame(0x37,p,3,150);
    web.send(ok?200:409,"text/plain",ok?"OK":"Settings refused");
  });
  web.on("/api/palette",HTTP_GET,[](){
    if(active||!readReply(0x36,nullptr,0,32)){web.send(409,"text/plain","Cover not ready");return;}
    binaryReply(32);
  });
  web.on("/api/cover",HTTP_GET,[](){
    int tile=web.arg("tile").toInt();
    if(active||tile<0||tile>127){web.send(400,"text/plain","Invalid cover tile");return;}
    uint8_t a=(uint8_t)tile;
    if(!readReply(0x35,&a,1,512)){web.send(409,"text/plain","Cover not ready");return;}
    binaryReply(512);
  });
}
void setup(){
  // FPGA reset establishes M0, dry effect, and metronome off. The ESP reads
  // that state from /api/status and sends 0x30/0x31 only for an explicit edit.
  timbreA=START_TIMBRE_A; timbreB=START_TIMBRE_B;
  voiceMode=START_VOICE_MODE;
  effectMode=START_EFFECT_MODE; metronomeOn=START_METRONOME;
  vibratoDepth=2;
  controlDirty=false; effectDirty=false; depthDirty=false; lastControlAttempt=0;
  Serial.begin(115200);
  Serial.swap();  // D8 TX, D7 RX
  pinMode(5,INPUT_PULLUP);pinMode(4,INPUT_PULLUP);pinMode(14,INPUT_PULLUP);
  for(uint8_t i=0;i<3;i++){
    perfButtons[i].rawDown=(digitalRead(perfButtons[i].pin)==LOW);
    perfButtons[i].stableDown=false;perfButtons[i].armed=false;
    perfButtons[i].changedAt=millis();perfButtons[i].pressedAt=millis();
  }
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(IPAddress(192,168,4,1),IPAddress(192,168,4,1),IPAddress(255,255,255,0));
  WiFi.softAP(SSID,PASS);
  web.on("/start",HTTP_POST,[](){
    if(active){web.send(409,"text/plain","Upload already active; reset ESP to abandon it");return;}
    failed=true;
    uint32_t size=strtoul(web.arg("size").c_str(),nullptr,10);
    if(!beginFile(web.arg("name"),size)){
      frame(0x21,nullptr,0);
      web.send(409,"text/plain",result);
      return;
    }
    active=true;failed=false;chunkOk=false;lastProgress=millis();
    result="Receiving";web.send(200,"text/plain",result);
  });
  web.on("/chunk",HTTP_POST,[](){
    if(chunkOk && chunkEnded && active && !failed){
      lastProgress=millis();
      web.send(200,"text/plain",String(receivedSize));
    } else web.send(409,"text/plain",result);
  },onChunkUpload);
  web.on("/finish",HTTP_POST,[](){
    if(!active || failed || receivedSize!=expectedSize){
      result=String("Incomplete upload: ")+String(receivedSize)+" / "+String(expectedSize);
      web.send(409,"text/plain",result);return;
    }
    if(commitFile())result=String("Saved and verified ")+String(receivedSize)+" bytes";
    else {failed=true;result="FAT commit failed; check card on PC";}
    active=false;frame(0x21,nullptr,0);
    web.send(failed?409:200,"text/plain",result);
  });
  web.on("/abort",HTTP_POST,[](){
    active=false;failed=true;result="Upload aborted";
    frame(0x21,nullptr,0);
    web.send(200,"text/plain",result);
  });
  phoneRoutes();
  web.onNotFound([](){web.send(404,"text/plain","Not found. Open http://192.168.4.1/");});
  web.begin();
}
void loop(){
  web.handleClient();
  if(active && (uint32_t)(millis()-lastProgress)>60000UL){
    active=false;failed=true;result="Upload timed out";
    frame(0x21,nullptr,0);
  }
  pollPerformanceButtons();
}
