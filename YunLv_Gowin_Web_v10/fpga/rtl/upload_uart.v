// 115200 8N1 receive side of the ESP8266 upload protocol.
// A5 type len payload crc16-low crc16-high. CRC-16/CCITT-FALSE covers
// type, len and data. A frame is acknowledged ONLY when the filesystem
// backend asserts commit_ok. Invalid frames receive 0x15 (NAK).
module upload_uart #(
    parameter integer CLK_HZ = 24576000,
    parameter integer BAUD = 115200
) (
    input wire clk, input wire reset, input wire rx, output reg tx = 1'b1,
    output reg frame_begin = 0,
    output reg [7:0] frame_type = 0,
    output reg [7:0] frame_length = 0,
    output reg data_valid = 0,
    output reg [7:0] data_byte = 0,
    output reg frame_end = 0,
    input wire commit_ok, input wire commit_fail,
    input wire response_start, input wire [7:0] response_data,
    input wire [9:0] response_length,
    output reg [8:0] response_index = 0,
    output reg response_done = 0
);
    localparam integer DIV = (CLK_HZ + BAUD/2) / BAUD;
    reg rx_meta = 1, rx_sync = 1;
    reg [15:0] rx_count = 0;
    reg [3:0] rx_bit = 0;
    reg [7:0] rx_shift = 0;
    reg rx_busy = 0;
    reg byte_valid = 0;
    reg [7:0] byte_value = 0;
    reg [2:0] state = 0;
    reg [7:0] remaining = 0;
    reg [15:0] crc = 16'hffff;
    reg [21:0] frame_idle = 0;
    reg [7:0] crc_low = 0;
    reg tx_busy = 0;
    reg stream_active = 0;
    reg [9:0] stream_left = 0;
    reg [9:0] tx_shift = 10'h3ff;
    reg [3:0] tx_bit = 0;
    reg [15:0] tx_count = 0;

    function [15:0] crc_next;
        input [15:0] c;
        input [7:0] d;
        reg [15:0] v;
        integer k;
        begin
            v = c ^ {d,8'h00};
            for (k=0; k<8; k=k+1)
                v = v[15] ? ((v << 1) ^ 16'h1021) : (v << 1);
            crc_next = v;
        end
    endfunction

    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
        byte_valid <= 0;
        if (!rx_busy) begin
            if (!rx_sync) begin
                rx_busy <= 1;
                rx_count <= DIV/2 + DIV - 1;
                rx_bit <= 0;
                rx_shift <= 0;
            end
        end else if (rx_count != 0) rx_count <= rx_count - 1'b1;
        else if (rx_bit < 8) begin
            rx_shift[rx_bit[2:0]] <= rx_sync;
            rx_bit <= rx_bit + 1'b1;
            rx_count <= DIV - 1;
        end else begin
            rx_busy <= 0;
            if (rx_sync) begin
                byte_value <= rx_shift;
                byte_valid <= 1;
            end
        end
        if (reset) begin rx_busy<=0; byte_valid<=0; rx_count<=0; end
    end

    always @(posedge clk) begin
        frame_begin <= 0;
        data_valid <= 0;
        frame_end <= 0;
        response_done <= 0;
        if (state==0 || state==6 || byte_valid) frame_idle<=0;
        else if (frame_idle==22'd2457599) begin
            frame_idle<=0;
            state<=0;
        end else frame_idle<=frame_idle+1'b1;
        if (response_start) begin
            stream_active <= 1;
            response_index <= 0;
            stream_left <= response_length;
        end
        if (tx_busy) begin
            if (tx_count != 0) tx_count <= tx_count - 1'b1;
            else if (tx_bit == 9) begin
                tx_busy <= 0;
                tx <= 1;
            end else begin
                tx_shift <= {1'b1,tx_shift[9:1]};
                tx <= tx_shift[1];
                tx_bit <= tx_bit + 1'b1;
                tx_count <= DIV - 1;
            end
        end
        if (byte_valid && state != 6) begin
            case (state)
                0: if (byte_value == 8'ha5) state <= 1;
                1: begin frame_type <= byte_value; crc <= crc_next(16'hffff,byte_value); state <= 2; end
                2: begin
                    frame_length <= byte_value;
                    remaining <= byte_value;
                    crc <= crc_next(crc,byte_value);
                    frame_begin <= 1;
                    state <= byte_value == 0 ? 4 : 3;
                end
                3: begin
                    data_byte <= byte_value;
                    data_valid <= 1;
                    crc <= crc_next(crc,byte_value);
                    remaining <= remaining - 1'b1;
                    if (remaining == 1) state <= 4;
                end
                4: begin crc_low <= byte_value; state <= 5; end
                5: if ({byte_value,crc_low} == crc) begin
                    frame_end <= 1;
                    state <= 6;
                end else begin
                    state <= 0;
                    tx_shift <= {1'b1,8'h15,1'b0};
                    tx <= 0; tx_bit <= 0;
                    tx_count <= DIV - 1; tx_busy <= 1;
                end
            endcase
        end
        if (state == 6 && (commit_ok || commit_fail) && !tx_busy) begin
            tx_shift <= {1'b1,(commit_ok ? 8'h06 : 8'h15),1'b0};
            tx <= 0; tx_bit <= 0;
            tx_count <= DIV - 1; tx_busy <= 1;
            state <= 0;
        end else if (stream_active && !tx_busy) begin
            tx_shift <= {1'b1,response_data,1'b0};
            tx <= 0; tx_bit <= 0;
            tx_count <= DIV - 1; tx_busy <= 1;
            stream_left <= stream_left-1'b1;
            if (stream_left <= 1) begin
                stream_active <= 0;
                response_done <= 1;
            end else response_index <= response_index + 1'b1;
        end
        if (reset) begin
            state<=0; tx<=1; tx_busy<=0; stream_active<=0;
            frame_begin<=0; frame_end<=0; data_valid<=0;
        end
    end
endmodule
