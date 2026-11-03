// One framed UART owns SD upload, phone controls and LCD state readback.
// 30 tone[3],31 FX[2],32 action/value[2],33 key-mask[1],34 snapshot[0],
// 35 cover tile[1]->512 packed index bytes,36 palette[0]->32 RGB565 bytes,
// 37 flags/volume/bend[3],38 vibrato-depth[1]. CRC16-CCITT frames.
module phone_control_bridge #(
    parameter integer CLK_HZ=24576000, parameter integer BAUD=115200,
    parameter integer KEY_TIMEOUT=14745600
)(
    input wire clk24m,reset,upload_mode,knob_takeover,
    input wire [2:0] ui_mode,
    input wire uart_rx,output wire uart_tx,
    output wire session_locked,
    output reg [1:0] timbre_a=0,timbre_b=2,voice_mode=0,effect_mode=0,
    output reg metronome=0,
    output reg [1:0] vibrato_depth=2'd2,
    output reg remote_valid=0,output reg [3:0] remote_action=0,
    output reg [2:0] remote_value=0,
    output reg [7:0] remote_keys=0,
    output reg [1:0] remote_settings=0,
    output reg [7:0] remote_volume=255,remote_bend=0,
    output reg snapshot_request=0,input wire snapshot_ack,
    input wire [767:0] snapshot_data,
    input wire cover_ready,output reg [16:0] cover_address=0,
    input wire [3:0] cover_index,
    output wire [3:0] palette_address,input wire [15:0] palette_color,
    output wire sd_cs_n,sd_sck,sd_mosi,input wire sd_miso
);
    wire frame_begin,data_valid,frame_end;
    wire [7:0] frame_type,frame_length,data_byte;
    reg ack=0,nack=0,send=0;
    wire disk_ack,disk_nack,disk_send;
    wire [8:0] response_index;
    wire response_done;
    wire [7:0] disk_data;
    reg [7:0] args[0:3];
    reg [2:0] arg_pos=0;
    reg [3:0] state=0;
    reg [1:0] response_kind=0;
    reg snapshot_locked=0;
    // UART consumes one byte every ~87 us. Read each pixel pair just
    // before it is needed, instead of a 512-byte register/multiplexer bank.
    reg [7:0] cover_byte=0;
    reg [3:0] cover_high=0;
    reg [8:0] cover_byte_index=0,cover_prepared_index=0;
    reg cover_first=0;
    reg [6:0] tile_no=0,crc_pos=0;
    reg [15:0] checksum=16'hffff;
    reg ack_meta=0,ack_sync=0;
    reg [23:0] key_age=0;
    wire can_play=ui_mode==1 || ui_mode==4 || ui_mode==5;
    wire disk_command=frame_type>=8'h10 && frame_type<=8'h21;
    wire [9:0] response_length=disk_send ? 10'd512 :
                                (response_kind==1)?10'd96:
                                (response_kind==3)?10'd32:10'd512;
    // The LCD snapshot handshake holds snapshot_data unchanged for the
    // entire transaction, so no second 768-bit copy is needed here.
    wire [7:0] crc_input=(crc_pos==7) ?
        {snapshot_locked,snapshot_data[62:56]} : snapshot_data[{crc_pos,3'b000} +: 8];
    wire [7:0] snapshot_byte=(response_index==94)?checksum[7:0]:
        (response_index==95)?checksum[15:8]:
        (response_index==7)?{snapshot_locked,snapshot_data[62:56]}:
        snapshot_data[{response_index,3'b000} +: 8];
    wire [7:0] response_byte=(response_kind==0)?disk_data:
         (response_kind==1)?snapshot_byte:
         (response_kind==2)?cover_byte:
         (response_index[0]?palette_color[15:8]:palette_color[7:0]);
    assign palette_address=response_index[4:1];
    function [15:0] crc_next;
        input [15:0] c;input [7:0] d;reg [15:0] v;integer k;
        begin
            v=c^{d,8'h00};
            for(k=0;k<8;k=k+1)v=v[15]?((v<<1)^16'h1021):(v<<1);
            crc_next=v;
        end
    endfunction
    upload_uart #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) uart (
        .clk(clk24m),.reset(reset),.rx(uart_rx),.tx(uart_tx),
        .frame_begin(frame_begin),.frame_type(frame_type),.frame_length(frame_length),
        .data_valid(data_valid),.data_byte(data_byte),.frame_end(frame_end),
        .commit_ok(ack|disk_ack),.commit_fail(nack|disk_nack),
        .response_start(send|disk_send),.response_data(response_byte),
        .response_length(response_length),.response_index(response_index),.response_done(response_done)
    );
    upload_sd_bridge storage (
        .clk24m(clk24m),.enable(upload_mode),
        .session_locked(session_locked),
        .begin_frame(frame_begin),.data_valid(data_valid),
        .frame_end(frame_end && disk_command && state==0),
        .frame_type(frame_type),.frame_length(frame_length),.data_byte(data_byte),
        .ack(disk_ack),.nack(disk_nack),.send_block(disk_send),
        .response_index(response_index),.response_data(disk_data),
        .sd_cs_n(sd_cs_n),.sd_sck(sd_sck),.sd_mosi(sd_mosi),.sd_miso(sd_miso)
    );
    always @(posedge clk24m) begin
        ack<=0;nack<=0;send<=0;remote_valid<=0;
        // Clear the phone volume owner as soon as the real knob is moved.
        // A simultaneous explicit 0x37 settings command takes precedence.
        if(knob_takeover) remote_settings[0]<=0;
        ack_meta<=snapshot_ack;ack_sync<=ack_meta;
        if(!can_play || reset)begin remote_keys<=0;key_age<=0;end
        else if(key_age>=KEY_TIMEOUT-1)begin
            remote_keys<=0;remote_settings[1]<=0;
        end else key_age<=key_age+1'b1;
        if(frame_begin) arg_pos<=0;
        if(data_valid && arg_pos<4)begin args[arg_pos[1:0]]<=data_byte;arg_pos<=arg_pos+1'b1;end
        if(disk_send)response_kind<=0;
        if(reset)begin
            state<=0;remote_keys<=0;remote_settings<=0;
            snapshot_request<=0;arg_pos<=0;ack<=0;nack<=0;send<=0;
            // FPGA startup agrees with the ESP cold-start values. The
            // 0x30/0x31 commands still take effect normally after reset.
            timbre_a<=2'd0;timbre_b<=2'd2;voice_mode<=2'd0;
            effect_mode<=2'd0;metronome<=1'b0;
            vibrato_depth<=2'd2;
        end else case(state)
            0: if(frame_end)begin
                case(frame_type)
                    8'h30: if(!session_locked && frame_length==3 && args[0]<3 && args[1]<3 && args[2]<3)begin
                        timbre_a<=args[0][1:0];timbre_b<=args[1][1:0];voice_mode<=args[2][1:0];ack<=1;
                    end else nack<=1;
                    8'h31: if(!session_locked && frame_length==2 && args[0]<3 && args[1]<2)begin
                        effect_mode<=args[0][1:0];metronome<=args[1][0];ack<=1;
                    end else nack<=1;
                    8'h32: if(!session_locked && frame_length==2 && args[0]>=1 && args[0]<=7 && args[1]<8)begin
                        remote_action<=args[0][3:0];remote_value<=args[1][2:0];remote_valid<=1;
                        remote_keys<=0;key_age<=0;ack<=1;
                    end else nack<=1;
                    8'h33: if(!session_locked && frame_length==1 && (can_play || args[0]==0))begin
                        remote_keys<=can_play?args[0]:8'd0;key_age<=0;ack<=1;
                    end else nack<=1;
                    8'h34: if(frame_length==0)begin
                        snapshot_request<=~snapshot_request;state<=1;
                    end else nack<=1;
                    8'h35: if(frame_length==1 && args[0]<128 && cover_ready)begin
                        tile_no<=args[0][6:0];cover_byte_index<=0;cover_first<=1;state<=4;
                    end else nack<=1;
                    8'h36: if(frame_length==0 && cover_ready)begin
                        response_kind<=3;ack<=1;send<=1;state<=9;
                    end else nack<=1;
                    8'h37: if(!session_locked && frame_length==3 && args[0]<4)begin
                        remote_settings<=args[0][1:0];remote_volume<=args[1];remote_bend<=args[2];
                        key_age<=0;ack<=1;
                    end else nack<=1;
                    8'h38: if(!session_locked && frame_length==1 && args[0]<4)begin
                        vibrato_depth<=args[0][1:0];ack<=1;
                    end else nack<=1;
                    default: if(!disk_command || !upload_mode)nack<=1;
                endcase
            end
            1: if(ack_sync==snapshot_request)begin
                snapshot_locked<=session_locked;
                checksum<=16'hffff;crc_pos<=0;state<=2;
            end
            2: begin
                checksum<=crc_next(checksum,crc_input);
                if(crc_pos==93)state<=3;
                else crc_pos<=crc_pos+1'b1;
            end
            3: begin
                response_kind<=1;ack<=1;send<=1;state<=9;
            end
            4: begin
                cover_address<={tile_no,10'd0}+{7'd0,cover_byte_index,1'b0};state<=5;
            end
            5: state<=6;
            6: begin
                cover_high<=cover_address<17'd130560 ? cover_index:4'd0;
                cover_address<=cover_address+1'b1;state<=7;
            end
            7: state<=8;
            8: begin
                cover_byte<={cover_high,(cover_address<17'd130560 ? cover_index:4'd0)};
                cover_prepared_index<=cover_byte_index;
                if(cover_first)begin
                    cover_first<=0;response_kind<=2;ack<=1;send<=1;state<=10;
                end else state<=9;
            end
            // Give upload_uart a clock to reset response_index to zero when
            // starting the stream, before tracking its byte prefetch index.
            10: state<=9;
            9: if(response_done)state<=0;
               else if(response_kind==2 && response_index!=cover_prepared_index)begin
                   cover_byte_index<=response_index;state<=4;
               end
            default: state<=0;
        endcase
    end
endmodule
