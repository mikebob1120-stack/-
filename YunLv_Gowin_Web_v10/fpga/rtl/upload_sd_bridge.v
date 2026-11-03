// UART remote 512-byte block device. No filesystem logic here: the ESP8266
// must verify FAT32 before issuing any sector writes. Enabled only in menu 4.
// Commands: 10 READ LBA4 -> ACK + 512 raw bytes;
//           11 WRITE_BEGIN LBA4 -> ACK;
//           12 DATA 1..128 bytes -> ACK;
//           13 WRITE_COMMIT len0 -> ACK after card accepts CMD24;
//           14 ABORT len0 -> ACK. All requests use upload_uart framing.
module upload_sd_bridge (
    input wire clk24m, input wire enable,
    output reg session_locked=0,
    input wire begin_frame, data_valid, frame_end,
    input wire [7:0] frame_type, frame_length, data_byte,
    output reg ack=0, nack=0, send_block=0,
    input wire [8:0] response_index,
    output wire [7:0] response_data,
    output wire sd_cs_n, sd_sck, sd_mosi, input wire sd_miso
);
    reg [7:0] frame_buf [0:127];
    reg [7:0] sector_buf [0:511];
    reg [7:0] frame_position=0;
    reg [9:0] sector_position=0;
    reg [7:0] copy_position=0, copy_length=0;
    reg [31:0] lba=0;
    reg [2:0] state=0;
    reg read_start=0, write_start=0;
    wire card_ready, card_busy, card_error, card_byte_valid;
    wire card_read_done, card_write_done;
    wire [8:0] card_byte_index, card_write_index;
    wire [7:0] card_byte_data;
    // One synchronous read port is shared by UART readback and CMD24.
    // This avoids two large asynchronous LUT muxes and permits BSRAM.
    reg [7:0] sector_read=0;
    wire [8:0] sector_read_address=(state==3)?card_write_index:response_index;
    wire sector_write=enable && ((card_byte_valid && state==2) || state==4);
    wire [8:0] sector_write_address=(state==2)?card_byte_index:
                                   sector_position[8:0]+{1'b0,copy_position};
    wire [7:0] sector_write_data=(state==2)?card_byte_data:frame_buf[copy_position[6:0]];
    wire [7:0] write_byte=sector_read;
    assign response_data=sector_read;
    always @(posedge clk24m) begin
        if(sector_write)sector_buf[sector_write_address]<=sector_write_data;
        sector_read<=sector_buf[sector_read_address];
    end
    sd_spi_reader disk (
        .clk24m(clk24m), .reset(!enable),
        .read_start(read_start), .sector_number(lba),
        .write_start(write_start), .write_sector(lba),
        .write_byte(write_byte), .write_index(card_write_index),
        .write_done(card_write_done),
        .ready(card_ready), .busy(card_busy), .error(card_error),
        .byte_valid(card_byte_valid), .byte_index(card_byte_index),
        .byte_data(card_byte_data), .read_done(card_read_done),
        .sd_cs_n(sd_cs_n), .sd_sck(sd_sck), .sd_mosi(sd_mosi), .sd_miso(sd_miso)
    );
    always @(posedge clk24m) begin
        ack<=0; nack<=0; read_start<=0; write_start<=0; send_block<=0;
        if (!enable) begin
            state<=0; frame_position<=0; sector_position<=0;
            session_locked<=0;
        end else begin
            if (begin_frame) frame_position<=0;
            if (data_valid && frame_position<128) begin
                frame_buf[frame_position[6:0]]<=data_byte;
                frame_position<=frame_position+1'b1;
            end
            case (state)
                0: if (frame_end) begin
                    case(frame_type)
                        8'h20: if(frame_length==0) begin session_locked<=1; ack<=1; end
                               else nack<=1;
                        8'h21: if(frame_length==0) begin session_locked<=0; ack<=1; end
                               else nack<=1;
                        8'h10: if (frame_length==4 && card_ready && !card_busy) begin
                            lba<={frame_buf[3],frame_buf[2],frame_buf[1],frame_buf[0]};
                            state<=1;
                        end else nack<=1;
                        8'h11: if (session_locked && frame_length==4 && card_ready && !card_busy) begin
                            lba<={frame_buf[3],frame_buf[2],frame_buf[1],frame_buf[0]};
                            sector_position<=0; ack<=1;
                        end else nack<=1;
                        8'h12: if (session_locked && frame_length!=0 && frame_length<=128 &&
                                   sector_position + {2'b0,frame_length} <= 10'd512) begin
                            copy_length<=frame_length;
                            copy_position<=0;
                            state<=4;
                        end else nack<=1;
                        8'h13: if (session_locked && frame_length==0 && sector_position==512 &&
                                   card_ready && !card_busy) begin
                            write_start<=1; state<=3;
                        end else nack<=1;
                        8'h14: begin sector_position<=0; ack<=1; end
                        default: nack<=1;
                    endcase
                end
                1: begin read_start<=1; state<=2; end
                2: if (card_read_done) begin
                    ack<=1; send_block<=1; state<=0;
                end else if (card_error) begin nack<=1; state<=0; end
                3: if (card_write_done) begin ack<=1; state<=0; end
                   else if (card_error) begin nack<=1; state<=0; end
                4: begin
                    if (copy_position+8'd1==copy_length) begin
                        sector_position<=sector_position+{2'b0,copy_length};
                        state<=0; ack<=1;
                    end else copy_position<=copy_position+1'b1;
                end
                default: state<=0;
            endcase
        end
    end
endmodule
