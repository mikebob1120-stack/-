// ESP8266 performance controls over the same physical UART as SD upload.
// 30/len3: A B MODE; 31/len2: FX BEAT. Both use A5 framing and CRC16.
// Only enabled outside upload menu 4. ACK is returned after a valid update.
module instrument_ctrl_uart (
    input wire clk24m,
    input wire enable,
    input wire uart_rx,
    output wire uart_tx,
    output reg [1:0] timbre_a = 2'd0, // 0 triangle, 1 sine, 2 pulse
    output reg [1:0] timbre_b = 2'd2,
    output reg [1:0] voice_mode = 2'd0, // 0 A, 1 split, 2 A+B
    output reg [1:0] effect_mode = 2'd0, // 0 dry, 1 vibrato, 2 echo
    output reg metronome = 1'b0
);
    wire frame_begin, data_valid, frame_end;
    wire [7:0] frame_type, frame_length, data_byte;
    reg [7:0] param_a=0, param_b=2, param_mode=0;
    reg [1:0] byte_index=0;
    reg [7:0] effect_value=0, beat_value=0;
    wire valid_tone = frame_end && frame_type==8'h30 && frame_length==8'd3 &&
                      param_a<=8'd2 && param_b<=8'd2 && param_mode<=8'd2;
    wire valid_effect = frame_end && frame_type==8'h31 && frame_length==8'd2 &&
                        effect_value<=8'd2 && beat_value<=8'd1;
    wire valid_command=valid_tone || valid_effect;

    upload_uart #(.CLK_HZ(24576000), .BAUD(115200)) link (
        .clk(clk24m), .reset(!enable), .rx(uart_rx), .tx(uart_tx),
        .frame_begin(frame_begin), .frame_type(frame_type),
        .frame_length(frame_length), .data_valid(data_valid),
        .data_byte(data_byte), .frame_end(frame_end),
        .commit_ok(valid_command), .commit_fail(frame_end && !valid_command),
        .response_length(10'd512), .response_start(1'b0), .response_data(8'h00),
        .response_index(), .response_done()
    );

    always @(posedge clk24m) begin
        if (!enable) byte_index<=0;
        else begin
            if (frame_begin) byte_index<=0;
            if (data_valid) begin
                if (frame_type==8'h31) begin
                    if (byte_index==0) effect_value<=data_byte;
                    else if (byte_index==1) beat_value<=data_byte;
                end else begin
                    case (byte_index)
                        0: param_a<=data_byte;
                        1: param_b<=data_byte;
                        2: param_mode<=data_byte;
                        default: ;
                    endcase
                end
                if (byte_index!=2'd3) byte_index<=byte_index+1'b1;
            end
            if (valid_tone) begin
                timbre_a<=param_a[1:0];
                timbre_b<=param_b[1:0];
                voice_mode<=param_mode[1:0];
            end
            if (valid_effect) begin
                effect_mode<=effect_value[1:0];
                metronome<=beat_value[0];
            end
        end
    end
endmodule
