'use strict';
(()=>{
const $=id=>document.getElementById(id),canvas=$('lcd'),ctx=canvas.getContext('2d',{alpha:false});ctx.imageSmoothingEnabled=false;
const names=['主菜单','PLAY LIVE','SD 选曲','跟弹选曲','WAV 播放','跟弹演奏','Wi-Fi 上传','开机封面'];
let state=null,connected=false,tab=1,busy=false,uploading=false,commands=[],desiredMask=0,sentMask=0,lastKey=0,lastPoll=0,lastGood=0;
let settings=0,phoneVolume=255,phoneBend=0,volumeDragging=false,lastVolumeInput=0,cover=null,coverPalette=null,coverTile=0,coverWorking=null,coverWasReady=false;
let vibPending=null,vibSeq=0,vibDragging=false;
const pointers=new Map();
function message(t){$('message').textContent=t}
async function req(path,method='GET',body=null,contentType='application/octet-stream'){
 const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),path.startsWith('/api/')?4000:180000);
 try{
  const r=await fetch(path,{method,body:method==='GET'?undefined:body,headers:method==='GET'?{}:{'Content-Type':contentType},cache:'no-store',signal:abort.signal});
  const bytes=new Uint8Array(await r.arrayBuffer());
  if(!r.ok)throw Error(new TextDecoder().decode(bytes)||'开发板未响应');
  return bytes;
 }finally{clearTimeout(timer)}
}
function crc16(p){let c=65535;for(let i=0;i<94;i++){c^=p[i]<<8;for(let k=0;k<8;k++)c=(c&32768)?((c<<1)^0x1021)&65535:(c<<1)&65535}return c}
function online(v){connected=v;$('connection').textContent=v?'● 开发板已连接':'○ 未连接开发板';$('connection').classList.toggle('on',v);document.querySelectorAll('.device').forEach(b=>b.disabled=!v||uploading)}
function syncControls(){if(!state)return;for(const[id,v]of[['toneA',state.a],['toneB',state.b],['voice',state.voice],['effect',state.fx],['beat',state.beat]])if(document.activeElement!==$(id))$(id).value=String(v);if(!vibDragging&&!vibPending)$('vibDepth').value=String(state.vibDepth);if(!volumeDragging&&!settingsDirty&&Date.now()-lastVolumeInput>=500)$('volume').value=state.volume;if(!(settings&2)&&document.activeElement!==$('bend'))$('bend').value=state.bend}
let worker=null,renderBusy=false,renderPending=null,coverSent=false;
try{worker=new Worker(URL.createObjectURL(new Blob([window.LCD_WORKER_SOURCE],{type:'application/javascript'})));worker.onmessage=e=>{if(e.data.error){message('画面同步失败：'+e.data.error);renderBusy=false;return}ctx.putImageData(new ImageData(new Uint8ClampedArray(e.data.pixels),480,272),0,0);renderBusy=false;if(renderPending){const s=renderPending;renderPending=null;draw(s)}};worker.onerror=()=>{renderBusy=false;message('浏览器不支持画面渲染，请使用新版 Chrome 或 Edge')};}catch(e){message('无法启动 LCD 渲染器：'+e.message)}
function draw(s){if(!worker)return;if(renderBusy){renderPending=s;return}if(cover&&!coverSent){worker.postMessage({type:'cover',indices:cover,colors:coverPalette});coverSent=true}renderBusy=true;worker.postMessage({type:'frame',state:s})}
function clearCover(){cover=null;coverPalette=null;coverWorking=null;coverTile=0;coverSent=false;if(worker)worker.postMessage({type:'cover',indices:null,colors:null})}
function queue(fn){return new Promise((resolve,reject)=>{commands.push({fn,resolve,reject});pump()})}
async function action(a,v=0){if(!connected)throw Error('先连接 FPGA-MUSIC 并烧录配套固件');releaseLocal();await queue(()=>req('/api/action?action='+a+'&value='+v,'POST'));lastPoll=0}
function safe(p){p.catch(e=>message(e.message))}
function releaseLocal(){pointers.clear();desiredMask=0;phoneBend=0;$('bend').value=0;if(settings&2){settings&=1;settingsDirty=true}}
function release(){releaseLocal();if(connected)safe(queue(()=>req('/api/keys?mask=0','POST')))}
let settingsDirty=false,lastCoverError=0;
async function poll(){lastPoll=Date.now();const p=await req('/api/status');if(p.length!==96||p[0]!==89||p[1]!==76||p[2]!==2||crc16(p)!==(p[94]|p[95]<<8))throw Error('状态校验失败：请将 ESP 和 FPGA 都更新为 v13');const wasConnected=connected;state=LCD.decode(p);state.vibDepth=p[88];state.phoneVolumeActive=!!(p[89]&1);if(vibPending&&vibPending.acked&&state.vibDepth===vibPending.value)vibPending=null;if(!volumeDragging&&!settingsDirty&&Date.now()-lastVolumeInput>=500)settings=(settings&2)|(state.phoneVolumeActive?1:0);online(true);if(!wasConnected){clearCover();message('已连接开发板。模式一跟随 LCD；模式二自动进入 PLAY LIVE。');}lastGood=Date.now();$('screenMode').textContent=names[state.mode]||'硬件状态';syncControls();
 if(state.mode===7&&!state.cover&&coverWasReady)clearCover();coverWasReady=!!state.cover;draw(state);
}
async function readCover(){if(!coverPalette){const p=await req('/api/palette');if(p.length!==32)throw Error('调色板长度错误');coverPalette=new Uint16Array(16);for(let i=0;i<16;i++)coverPalette[i]=p[i*2]|p[i*2+1]<<8;coverWorking=new Uint8Array(65536)}else{const p=await req('/api/cover?tile='+coverTile);if(p.length!==512)throw Error('封面数据长度错误');coverWorking.set(p,coverTile*512);coverTile++;if(coverTile===128){cover=coverWorking;coverWorking=null;coverSent=false;draw(state);message('开机封面已从开发板同步。按 S1 或点击确认进入菜单。')}else message('正在从开发板同步封面 '+Math.floor(coverTile*100/128)+'%，可随时按 S1 进入菜单。')}}
async function pump(){if(busy||uploading||document.hidden)return;busy=true;
 try{
  const now=Date.now();
  if(connected&&(desiredMask!==sentMask||((desiredMask||phoneBend)&&now-lastKey>=150))){const m=desiredMask;await req('/api/keys?mask='+m,'POST');sentMask=m;lastKey=Date.now();lastPoll=0;}
  else if(commands.length){const q=commands.shift();try{q.resolve(await q.fn())}catch(e){q.reject(e)}}
  else if(connected&&settingsDirty){settingsDirty=false;await req('/api/settings?flags='+settings+'&volume='+phoneVolume+'&bend='+phoneBend,'POST');lastPoll=0}
  else if(now-lastPoll>=(connected?150:1500)){try{await poll()}catch(e){online(false);releaseLocal();message('未连接：'+e.message+'。请检查 Wi-Fi 和配套固件。')}}
  else if(connected&&state.mode===7&&state.cover&&!cover&&now-lastCoverError>2000){try{await readCover()}catch(e){lastCoverError=Date.now();message('封面同步暂缓：'+e.message)}}
 }catch(e){releaseLocal();message(e.message)}finally{busy=false;setTimeout(pump,15)}
}
$('mirrorTab').onclick=()=>{tab=1;$('mirrorTab').classList.add('active');$('pianoTab').classList.remove('active');release();$('tip').textContent='手机与 LCD 使用同一份硬件状态 · 点击菜单或使用下方 S1 / S2';message('模式一：跟随开发板当前页面，板上操作也会同步到手机。')};
$('pianoTab').onclick=()=>{safe((async()=>{await action(4);tab=2;$('pianoTab').classList.add('active');$('mirrorTab').classList.remove('active');$('tip').textContent='第一排 SOL · LA · SI · HIGHDO，第二排 DO · RE · MI · FA · 支持多指同时弹奏';message('模式二：已请求开发板进入 PLAY LIVE，触摸琴键由开发板扬声器发声。')})())};
$('confirm').onclick=()=>safe(action(1));$('next').onclick=()=>safe(action(2));$('back').onclick=()=>safe(action(3));$('release').onclick=release;$('retry').onclick=()=>{lastPoll=0;message('正在重新查询开发板…');pump()};
$('wifi').onclick=()=>{release();message('请在手机系统设置中连接 FPGA-MUSIC，密码 Music2026，然后返回本页面。')};
function coord(e){const r=canvas.getBoundingClientRect();return[(e.clientX-r.left)*480/r.width,(e.clientY-r.top)*272/r.height]}
function keyAt(e){const[x,y]=coord(e);let col=-1,row=-1;for(let i=0;i<4;i++)if(x>=16+i*116&&x<120+i*116)col=i;if(y>=24&&y<124)row=0;else if(y>=148&&y<248)row=1;return col<0||row<0?0:1<<(row===0?col+4:col)}
function updateKeys(){desiredMask=0;for(const m of pointers.values())desiredMask|=m;pump()}
canvas.addEventListener('pointerdown',e=>{e.preventDefault();if(!connected||uploading||!state)return;canvas.setPointerCapture(e.pointerId);if(state.mode===1||state.mode===5){pointers.set(e.pointerId,keyAt(e));updateKeys()}else if(tab===1){const[x,y]=coord(e);if(state.mode===7)safe(action(1));else if(state.mode===0&&x>=26&&x<454){const n=Math.floor((y-42)/54);if(n>=0&&n<4&&y<90+n*54)safe(action(5,n))}else if((state.mode===2||state.mode===3)&&state.catalog&&x>=28&&x<452&&y>=58&&y<250){const n=(state.song&4)+Math.floor((y-58)/50);if(n<state.count&&(y-58)%50<42)safe((async()=>{await action(6,n);await action(1)})())}}});
canvas.addEventListener('pointermove',e=>{if(!pointers.has(e.pointerId))return;e.preventDefault();pointers.set(e.pointerId,keyAt(e));updateKeys()});
for(const event of['pointerup','pointercancel','lostpointercapture'])canvas.addEventListener(event,e=>{if(pointers.delete(e.pointerId))updateKeys()});
window.addEventListener('blur',release);window.addEventListener('pagehide',()=>{releaseLocal();if(connected)try{navigator.sendBeacon('/api/keys?mask=0',new Blob([]))}catch(_){}});document.addEventListener('visibilitychange',()=>{if(document.hidden)release();else{clearCover();lastPoll=0;pump()}});window.stopNotes=release;
function setTone(){if(!state)return;let a=+$('toneA').value,b=+$('toneB').value,m=+$('voice').value;if(a===b){b=(a+1)%3;$('toneB').value=b}safe(queue(()=>req('/api/tone?a='+a+'&b='+b+'&mode='+m,'POST')));lastPoll=0}
for(const id of['toneA','toneB','voice'])$(id).onchange=setTone;
for(const id of['effect','beat'])$(id).onchange=()=>{safe(queue(()=>req('/api/effect?fx='+$('effect').value+'&beat='+$('beat').value,'POST')));lastPoll=0};
$('vibDepth').addEventListener('pointerdown',()=>vibDragging=true);for(const event of['pointerup','pointercancel','lostpointercapture'])$('vibDepth').addEventListener(event,()=>vibDragging=false);
$('vibDepth').oninput=()=>{const depth=Number($('vibDepth').value),seq=++vibSeq;vibPending={value:depth,seq,acked:false};safe(queue(()=>req('/api/vibrato?depth='+depth,'POST')).then(()=>{if(vibPending&&vibPending.seq===seq)vibPending.acked=true;lastPoll=0}).catch(e=>{if(vibPending&&vibPending.seq===seq)vibPending=null;throw e}));lastPoll=0};
$('volume').addEventListener('pointerdown',()=>volumeDragging=true);for(const event of['pointerup','pointercancel','lostpointercapture'])$('volume').addEventListener(event,()=>volumeDragging=false);$('volume').oninput=()=>{lastVolumeInput=Date.now();settings|=1;phoneVolume=+$('volume').value;settingsDirty=true;pump()};$('bend').oninput=()=>{settings|=2;phoneBend=+$('bend').value;settingsDirty=true;pump()};
for(const event of['pointerup','pointercancel','change'])$('bend').addEventListener(event,()=>{phoneBend=0;$('bend').value=0;settingsDirty=true;pump()});
$('physical').onclick=()=>{settings=0;phoneBend=0;settingsDirty=true;message('已请求恢复底板旋钮和 FSR 控制');pump()};
$('enterUpload').onclick=()=>safe(action(5,3));
$('uploadButton').onclick=()=>safe((async()=>{const f=$('file').files[0],s=$('uploadProgress');if(!f){s.textContent='请先选择手机中的 WAV 或 NTE 文件';return}if(!connected||!state||state.mode!==6){s.textContent='请先点击“进入第 4 项”，等待 LCD 和手机都显示上传页';return}if(!/^[A-Za-z0-9_]{1,8}\.(WAV|NTE)$/i.test(f.name)||!f.size||f.size>33554432||(/\.nte$/i.test(f.name)&&f.size>256))throw Error('文件名需为 8.3 格式，WAV 最大 32 MiB，NTE 为 1～256 字节');release();while(busy)await new Promise(r=>setTimeout(r,20));uploading=true;online(true);$('uploadButton').disabled=true;let started=false;try{s.textContent='正在检查 SD 卡与空闲空间…';await req('/start?name='+encodeURIComponent(f.name)+'&size='+f.size,'POST');started=true;for(let off=0;off<f.size;){const end=Math.min(off+8192,f.size),chunk=new Uint8Array(await f.slice(off,end).arrayBuffer()),boundary='----YunLvPhoneBoundary';const head=new TextEncoder().encode('--'+boundary+'\r\nContent-Disposition: form-data; name="file"; filename="PART.BIN"\r\nContent-Type: application/octet-stream\r\n\r\n'),tail=new TextEncoder().encode('\r\n--'+boundary+'--\r\n'),body=new Uint8Array(head.length+chunk.length+tail.length);body.set(head);body.set(chunk,head.length);body.set(tail,head.length+chunk.length);await req('/chunk','POST',body,'multipart/form-data; boundary='+boundary);off=end;s.textContent='已写入并验证 '+off+' / '+f.size+' 字节（'+Math.floor(off*100/f.size)+'%）'}s.textContent='正在提交 FAT 和目录，请保持供电…';s.textContent=new TextDecoder().decode(await req('/finish','POST'));started=false}catch(e){s.textContent='上传停止：'+e.message;if(started)try{await req('/abort','POST')}catch(_){}throw e}finally{uploading=false;$('uploadButton').disabled=false;lastPoll=0;pump()}})());
online(false);ctx.fillStyle='#08101f';ctx.fillRect(0,0,480,272);ctx.fillStyle='#83a8c5';ctx.font='18px sans-serif';ctx.textAlign='center';ctx.fillText('等待连接 FPGA-MUSIC',240,132);pump();
})();
