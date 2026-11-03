// SD 卡底层，只读、不写卡。上电初始化后，每次读取一个 512 字节扇区。
// SPI 模式：DAT3=CS，CMD=MOSI，DAT0=MISO，CLK=SCK。
// 初始化时钟 192 kHz，初始化成功后 12.288 MHz；系统时钟始终为 24.576 MHz。
module sd_spi_reader (
    input wire clk24m, input wire reset,
    input wire read_start, input wire [31:0] sector_number,
    input wire write_start, input wire [31:0] write_sector,
    input wire [7:0] write_byte, output reg [8:0] write_index = 0,
    output reg write_done = 0,
    output reg ready = 0, output reg busy = 1, output reg error = 0,
    output reg byte_valid = 0, output reg [8:0] byte_index = 0,
    output reg [7:0] byte_data = 0, output reg read_done = 0,
    output reg sd_cs_n = 1, output reg sd_sck = 0,
    output reg sd_mosi = 1, input wire sd_miso
);
    // 一个字节的 SPI 收发器。MOSI 在下降沿改变，MISO 在上升沿采样。
    reg fast_clock = 0;
    reg transfer_start = 0;
    reg [7:0] transfer_tx = 8'hff;
    reg transfer_busy = 0, transfer_done = 0;
    reg [7:0] transfer_rx = 0, tx_shift = 0, rx_shift = 0;
    reg [2:0] bit_number = 7;
    reg [6:0] half_clock_count = 0;

    always @(posedge clk24m) begin
        transfer_done <= 0;
        if (reset) begin
            transfer_busy <= 0; transfer_done <= 0;
            sd_sck <= 0; sd_mosi <= 1;
            half_clock_count <= 0; bit_number <= 7;
            tx_shift <= 0; rx_shift <= 0; transfer_rx <= 0;
        end else if (transfer_start && !transfer_busy) begin
            transfer_busy <= 1;
            tx_shift <= transfer_tx; rx_shift <= 0;
            bit_number <= 7; half_clock_count <= 0;
            sd_sck <= 0; sd_mosi <= transfer_tx[7];
        end else if (transfer_busy) begin
            if (half_clock_count == (fast_clock ? 7'd0 : 7'd63)) begin
                half_clock_count <= 0;
                sd_sck <= ~sd_sck;
                if (!sd_sck) begin
                    rx_shift <= {rx_shift[6:0], sd_miso};
                end else if (bit_number == 0) begin
                    transfer_rx <= rx_shift;
                    transfer_busy <= 0; transfer_done <= 1; sd_mosi <= 1;
                end else begin
                    bit_number <= bit_number - 1'b1;
                    tx_shift <= {tx_shift[6:0], 1'b1};
                    sd_mosi <= tx_shift[6];
                end
            end else half_clock_count <= half_clock_count + 1'b1;
        end
    end

    localparam POWER_WAIT=0, DUMMY_SEND=1, DUMMY_WAIT=2,
        COMMAND_GAP=3, GAP_WAIT=4, COMMAND_SEND=5, COMMAND_WAIT=6,
        RESPONSE_SEND=7, RESPONSE_WAIT=8, CHECK_CMD0=9, CHECK_CMD8=10,
        EXTRA_SEND=11, EXTRA_WAIT=12, CHECK_R7=13, CHECK_CMD55=14,
        CHECK_ACMD41=15, INIT_PAUSE=16, CHECK_CMD58=17, CHECK_OCR=18,
        CHECK_CMD16=19, IDLE=20, CHECK_READ=21, TOKEN_SEND=22,
        TOKEN_WAIT=23, DATA_SEND=24, DATA_WAIT=25, CRC_SEND=26,
        CRC_WAIT=27, FINISH_SEND=28, FINISH_WAIT=29, FAILED=30,
        CHECK_WRITE=31, WRITE_TOKEN_SEND=32, WRITE_TOKEN_WAIT=33,
        WRITE_DATA_PREP=34, WRITE_DATA_SEND=35, WRITE_DATA_WAIT=36,
        WRITE_CRC_SEND=37, WRITE_CRC_WAIT=38,
        WRITE_RESPONSE_SEND=39, WRITE_RESPONSE_WAIT=40,
        WRITE_BUSY_SEND=41, WRITE_BUSY_WAIT=42,
        WRITE_FINISH_SEND=43, WRITE_FINISH_WAIT=44;
    reg [5:0] state = POWER_WAIT, command_return = 0, extra_return = 0;
    reg [47:0] command_shift = 0;
    reg [2:0] command_byte = 0, extra_count = 0;
    reg [3:0] dummy_count = 0;
    reg [7:0] response = 0, response_count = 0;
    reg [31:0] extra_data = 0;
    reg sd_version2 = 0, high_capacity = 0;
    reg [8:0] data_count = 0;
    reg crc_count = 0;
    reg [19:0] token_count = 0;
    reg [25:0] watchdog = 0;
    reg [18:0] pause_count = 0;

    // task 只是把重复的“准备命令”写法放在一起，不是额外硬件模块。
    task command;
        input [5:0] number;
        input [31:0] argument;
        input [7:0] crc;
        input [5:0] return_to;
        begin
            command_shift <= {2'b01, number, argument, crc};
            command_byte <= 0; command_return <= return_to;
            state <= COMMAND_GAP;
        end
    endtask

    always @(posedge clk24m) begin
        transfer_start <= 0; byte_valid <= 0; read_done <= 0; write_done <= 0;
        if (reset) begin
            ready <= 0; busy <= 1; error <= 0; fast_clock <= 0;
            sd_cs_n <= 1; state <= POWER_WAIT;
            pause_count <= 0; watchdog <= 0;
            dummy_count <= 0; sd_version2 <= 0; high_capacity <= 0;
            transfer_start <= 0; transfer_tx <= 8'hff;
            byte_index <= 0; byte_data <= 0; write_index <= 0;
            response_count <= 0; token_count <= 0;
        end else begin
            if (state == IDLE || state == FAILED) watchdog <= 0;
            else watchdog <= watchdog + 1'b1;

            case (state)
                POWER_WAIT: begin
                    if (pause_count == 19'd245759) begin
                        pause_count <= 0; state <= DUMMY_SEND;
                    end else pause_count <= pause_count + 1'b1;
                end
                DUMMY_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= DUMMY_WAIT;
                end
                DUMMY_WAIT: if (transfer_done) begin
                    if (dummy_count == 9) command(0, 0, 8'h95, CHECK_CMD0);
                    else begin dummy_count <= dummy_count + 1'b1; state <= DUMMY_SEND; end
                end
                // 每条命令前先释放 CS，并补足八个时钟，再选中卡。
                COMMAND_GAP: begin
                    sd_cs_n <= 1; transfer_tx <= 8'hff;
                    transfer_start <= 1; state <= GAP_WAIT;
                end
                GAP_WAIT: if (transfer_done) begin sd_cs_n <= 0; state <= COMMAND_SEND; end
                COMMAND_SEND: begin
                    transfer_tx <= command_shift[47:40]; transfer_start <= 1;
                    state <= COMMAND_WAIT;
                end
                COMMAND_WAIT: if (transfer_done) begin
                    if (command_byte == 5) begin response_count <= 0; state <= RESPONSE_SEND; end
                    else begin
                        command_shift <= {command_shift[39:0], 8'hff};
                        command_byte <= command_byte + 1'b1; state <= COMMAND_SEND;
                    end
                end
                RESPONSE_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= RESPONSE_WAIT;
                end
                RESPONSE_WAIT: if (transfer_done) begin
                    if (!transfer_rx[7]) begin response <= transfer_rx; state <= command_return; end
                    else if (response_count == 255) state <= FAILED;
                    else begin response_count <= response_count + 1'b1; state <= RESPONSE_SEND; end
                end
                CHECK_CMD0: begin
                    if (response == 8'h01) command(8, 32'h000001aa, 8'h87, CHECK_CMD8);
                    else command(0, 0, 8'h95, CHECK_CMD0);
                end
                CHECK_CMD8: begin
                    if (response == 1) begin
                        extra_count <= 0; extra_data <= 0;
                        extra_return <= CHECK_R7; state <= EXTRA_SEND;
                    end else if (response == 5) begin
                        sd_version2 <= 0; command(55, 0, 8'h01, CHECK_CMD55);
                    end else state <= FAILED;
                end
                EXTRA_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= EXTRA_WAIT;
                end
                EXTRA_WAIT: if (transfer_done) begin
                    extra_data <= {extra_data[23:0], transfer_rx};
                    if (extra_count == 3) state <= extra_return;
                    else begin extra_count <= extra_count + 1'b1; state <= EXTRA_SEND; end
                end
                CHECK_R7: begin
                    if (extra_data[11:0] == 12'h1aa) begin
                        sd_version2 <= 1; command(55, 0, 8'h01, CHECK_CMD55);
                    end else state <= FAILED;
                end
                CHECK_CMD55: begin
                    if (response == 0 || response == 1)
                        command(41, sd_version2 ? 32'h40000000 : 32'h0, 8'h01, CHECK_ACMD41);
                    else state <= FAILED;
                end
                CHECK_ACMD41: begin
                    if (response == 0) command(58, 0, 8'h01, CHECK_CMD58);
                    else if (response == 1) begin pause_count <= 0; state <= INIT_PAUSE; end
                    else state <= FAILED;
                end
                INIT_PAUSE: begin
                    if (pause_count == 19'd24575) command(55, 0, 8'h01, CHECK_CMD55);
                    else pause_count <= pause_count + 1'b1;
                end
                CHECK_CMD58: begin
                    if (response == 0) begin
                        extra_count <= 0; extra_data <= 0;
                        extra_return <= CHECK_OCR; state <= EXTRA_SEND;
                    end else state <= FAILED;
                end
                CHECK_OCR: begin
                    if (!extra_data[31] || !(|(extra_data & 32'h00ff8000))) state <= FAILED;
                    else begin
                        high_capacity <= sd_version2 && extra_data[30];
                        if (sd_version2 && extra_data[30]) begin
                            fast_clock <= 1; ready <= 1; busy <= 0; sd_cs_n <= 1; state <= IDLE;
                        end else command(16, 32'd512, 8'h01, CHECK_CMD16);
                    end
                end
                CHECK_CMD16: begin
                    if (response == 0) begin
                        fast_clock <= 1; ready <= 1; busy <= 0; sd_cs_n <= 1; state <= IDLE;
                    end else state <= FAILED;
                end
                IDLE: begin
                    sd_cs_n <= 1;
                    if (write_start) begin
                        busy <= 1;
                        command(24, high_capacity ? write_sector : (write_sector << 9), 8'h01, CHECK_WRITE);
                    end else if (read_start) begin
                        busy <= 1;
                        command(17, high_capacity ? sector_number : (sector_number << 9), 8'h01, CHECK_READ);
                    end
                end
                CHECK_READ: begin
                    if (response == 0) begin token_count <= 0; state <= TOKEN_SEND; end
                    else state <= FAILED;
                end
                TOKEN_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= TOKEN_WAIT;
                end
                TOKEN_WAIT: if (transfer_done) begin
                    if (transfer_rx == 8'hfe) begin data_count <= 0; state <= DATA_SEND; end
                    else if (transfer_rx != 8'hff || token_count == 20'd524287) state <= FAILED;
                    else begin token_count <= token_count + 1'b1; state <= TOKEN_SEND; end
                end
                DATA_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= DATA_WAIT;
                end
                DATA_WAIT: if (transfer_done) begin
                    byte_data <= transfer_rx; byte_index <= data_count; byte_valid <= 1;
                    if (data_count == 511) begin crc_count <= 0; state <= CRC_SEND; end
                    else begin data_count <= data_count + 1'b1; state <= DATA_SEND; end
                end
                // SPI 默认未启用 CRC 校验；仍接收并消耗卡返回的两字节 CRC。
                CRC_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= CRC_WAIT;
                end
                CRC_WAIT: if (transfer_done) begin
                    if (crc_count) begin sd_cs_n <= 1; state <= FINISH_SEND; end
                    else begin crc_count <= 1; state <= CRC_SEND; end
                end
                FINISH_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= FINISH_WAIT;
                end
                FINISH_WAIT: if (transfer_done) begin
                    read_done <= 1; busy <= 0; state <= IDLE;
                end
                CHECK_WRITE: begin
                    if (response == 0) state <= WRITE_TOKEN_SEND;
                    else state <= FAILED;
                end
                WRITE_TOKEN_SEND: begin
                    transfer_tx <= 8'hfe; transfer_start <= 1; state <= WRITE_TOKEN_WAIT;
                end
                WRITE_TOKEN_WAIT: if (transfer_done) begin
                    write_index <= 0; state <= WRITE_DATA_PREP;
                end
                // One full clock for a synchronous upstream 512-byte block RAM.
                WRITE_DATA_PREP: state <= WRITE_DATA_SEND;
                WRITE_DATA_SEND: begin
                    transfer_tx <= write_byte; transfer_start <= 1; state <= WRITE_DATA_WAIT;
                end
                WRITE_DATA_WAIT: if (transfer_done) begin
                    if (write_index == 511) begin crc_count <= 0; state <= WRITE_CRC_SEND; end
                    else begin write_index <= write_index + 1'b1; state <= WRITE_DATA_PREP; end
                end
                WRITE_CRC_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= WRITE_CRC_WAIT;
                end
                WRITE_CRC_WAIT: if (transfer_done) begin
                    if (crc_count) begin response_count <= 0; state <= WRITE_RESPONSE_SEND; end
                    else begin crc_count <= 1; state <= WRITE_CRC_SEND; end
                end
                WRITE_RESPONSE_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= WRITE_RESPONSE_WAIT;
                end
                WRITE_RESPONSE_WAIT: if (transfer_done) begin
                    if (transfer_rx == 8'hff && response_count < 8'd16) begin
                        response_count <= response_count + 1'b1;
                        state <= WRITE_RESPONSE_SEND;
                    end else if ((transfer_rx & 8'h1f) == 8'h05) state <= WRITE_BUSY_SEND;
                    else state <= FAILED;
                end
                WRITE_BUSY_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= WRITE_BUSY_WAIT;
                end
                WRITE_BUSY_WAIT: if (transfer_done) begin
                    if (transfer_rx == 8'hff) begin sd_cs_n <= 1; state <= WRITE_FINISH_SEND; end
                    else state <= WRITE_BUSY_SEND;
                end
                WRITE_FINISH_SEND: begin
                    transfer_tx <= 8'hff; transfer_start <= 1; state <= WRITE_FINISH_WAIT;
                end
                WRITE_FINISH_WAIT: if (transfer_done) begin
                    write_done <= 1; busy <= 0; state <= IDLE;
                end
                FAILED: begin ready <= 0; busy <= 0; error <= 1; sd_cs_n <= 1; end
                default: state <= FAILED;
            endcase

            // 卡不应答、卡被移除等情况在约两秒内退出，下一次按 S1 可重新初始化。
            if (state != IDLE && state != FAILED && watchdog == 26'd49151999) begin
                state <= FAILED; ready <= 0; busy <= 0; error <= 1; sd_cs_n <= 1;
            end
        end
    end
endmodule
