// SD 音乐播放器。为避免模块分散，文件查找、WAV 解析、缓存和采样率转换放在一起。
// FAT16/FAT32 root: WAV catalog for SD playback, NTE score catalog for
// guided play. Legacy: 1..256 one-byte masks (500 ms per note).
// Timed NTE2: ASCII "NTE2" then 1..126 (mask,duration/10ms) pairs.
// 支持小端 PCM 8/16/24/32 位、单/双声道、8000~96000 Hz；双声道取平均。
// 支持 PCM 类型的 WAVE_FORMAT_EXTENSIBLE。浮点、ADPCM、MP3、exFAT 不支持。
// sample_tick 必须为每秒 32000 次的单周期脉冲。只读取 SD 卡，不修改卡上的文件。
module sd_wav_player (
    input wire clk24m, input wire reset, input wire scan_start, input wire start,
    input wire [2:0] selected_index, input wire guided, input wire scan_guided,
    input wire score_advance,
    input wire sample_tick,
    // One-shot boot image request; shares the existing FAT and SD reader.
    input wire cover_start,
    output reg cover_ready = 0,
    output reg cover_we = 0,
    output reg [16:0] cover_address = 0,
    output reg [3:0] cover_pixel = 0,
    output reg cover_palette_we = 0,
    output reg [3:0] cover_palette_address = 0,
    output reg [15:0] cover_palette_pixel = 0,
    output reg busy = 0, output reg playing = 0,
    output reg catalog_ready = 0, output reg [3:0] song_count = 0,
    output reg [511:0] song_names = 0,
    output reg score_ready = 0, output reg score_done = 0,
    output wire [7:0] score_mask,
    output wire [7:0] score_step_10ms,
    output reg signed [15:0] pcm_sample = 0,
    output reg [3:0] error_code = 0,
    output reg underrun = 0,
    output wire sd_cs_n, output wire sd_sck, output wire sd_mosi,
    input wire sd_miso
);
    // ============================================================
    // 一、底层读卡接口和一个扇区的工作缓存。
    // 工作缓存同时供目录、FAT 表、文件数据使用；标记 LBA 防止误用旧数据。
    // ============================================================
    reg card_restart = 0, read_start = 0;
    reg [31:0] read_sector = 0;
    wire card_ready, card_busy, card_error, card_byte_valid, card_done;
    wire [8:0] card_byte_index;
    wire [7:0] card_byte_data;
    sd_spi_reader card (
        .clk24m(clk24m), .reset(reset || card_restart),
        .read_start(read_start), .sector_number(read_sector),
        .write_start(1'b0), .write_sector(32'd0), .write_byte(8'hff),
        .write_index(), .write_done(),
        .ready(card_ready), .busy(card_busy), .error(card_error),
        .byte_valid(card_byte_valid), .byte_index(card_byte_index),
        .byte_data(card_byte_data), .read_done(card_done),
        .sd_cs_n(sd_cs_n), .sd_sck(sd_sck), .sd_mosi(sd_mosi), .sd_miso(sd_miso)
    );

    reg [7:0] sector_ram [0:511];
    reg [7:0] fat_ram [0:511]; // 独立保留最近一页 FAT，减少跨簇时反复读卡
    reg [8:0] ram_address = 0;
    reg [7:0] ram_data = 0, fat_ram_data = 0;
    reg capture_fat = 0, fat_cache_valid = 0, word_from_fat = 0;
    reg [31:0] fat_cache_sector = 0;
    always @(posedge clk24m) begin
        if (card_byte_valid) sector_ram[card_byte_index] <= card_byte_data;
        if (card_byte_valid && capture_fat) fat_ram[card_byte_index] <= card_byte_data;
        ram_data <= sector_ram[ram_address];
        fat_ram_data <= fat_ram[ram_address];
    end
    reg cache_valid = 0;
    reg [31:0] cache_sector = 0;

    // ============================================================
    // 二、音频 FIFO。4096 个 16 位单声道采样，总计 8 KB。
    // 读卡按块进行，声音按固定节奏输出，FIFO 用来隔开这两种节奏。
    // 同步读写形式便于综合成 FPGA 内部块 RAM，不使用外部 SDRAM。
    // ============================================================
    reg signed [15:0] sample_fifo [0:4095];
    reg [11:0] write_pointer = 0, read_pointer = 0;
    reg [12:0] fifo_count = 0;
    reg fifo_push = 0, fifo_pop = 0, flush = 0;
    reg signed [15:0] fifo_input = 0, fifo_output = 0;
    wire fifo_write = fifo_push && fifo_count < 4096;
    wire fifo_read = fifo_pop && fifo_count != 0;
    always @(posedge clk24m) begin
        if (reset || flush || error_code != 0) begin
            write_pointer <= 0; read_pointer <= 0; fifo_count <= 0;
            fifo_output <= 0;
        end else begin
            if (fifo_write) begin
                sample_fifo[write_pointer] <= fifo_input;
                write_pointer <= write_pointer + 1'b1;
            end
            if (fifo_read) begin
                fifo_output <= sample_fifo[read_pointer];
                read_pointer <= read_pointer + 1'b1;
            end
            case ({fifo_write, fifo_read})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: ;
            endcase
        end
    end

    // ============================================================
    // 三、文件系统和 WAV 读取状态机。
    // 下方的小任务只用于复用动作，不会额外拆出硬件模块。
    // ============================================================
    localparam WAIT_START=0, INIT_DELAY=1, WAIT_CARD=2,
        DISK_REQUEST=3, DISK_WAIT=4,
        WORD_ADDRESS=5, WORD_DELAY=6, WORD_TAKE=7,
        BOOT_SIGNATURE=8, BOOT_PROBE=9, MBR_TYPE=10, MBR_LBA=11,
        VOLUME_SIGNATURE=12, BPB_REQUEST=13, BPB_SAVE=14, GEOMETRY=15,
        DIR_LOAD=16, DIR_FIRST=17, DIR_NAME=18, DIR_NEXT=19,
        DIR_LOW_CLUSTER=20, DIR_HIGH_CLUSTER=21, DIR_FILE_SIZE=22,
        DIR_AFTER_CLUSTER=23, CLUSTER_READ=24, CLUSTER_VALUE=25,
        FILE_BYTE=26, FILE_DELAY=27, FILE_TAKE=28, CLUSTER_DECODE=29,
        RIFF_BYTE=30, RIFF_SAVE=31, RIFF_CHECK=32,
        CHUNK_BYTE=33, CHUNK_SAVE=34, CHUNK_CHECK=35,
        FMT_BYTE=36, FMT_SAVE=37, FMT_CHECK=38,
        SKIP_BYTE=39, SKIP_SAVE=40, PAD_BYTE=41, FILE_NEXT_CLUSTER=42,
        DATA_CHECK=43, PCM_BEGIN=44, PCM_BYTE=45, PCM_SAVE=46,
        PCM_CHANNEL=47, PCM_EMIT=48, DRAIN=49, FAILED=50, PAD_CONSUMED=51,
        DIR_NAME_LOW=52, DIR_NAME_HIGH=53, DIR_EXTENSION=54,
        SCORE_BEGIN=55, SCORE_SAVE=56, SCORE_FINISH=57,
        CATALOG_SCORE_SIZE=58,
        BMP_BEGIN=59, BMP_HEADER=60, BMP_HEADER_SAVE=61, BMP_CHECK=62,
        BMP_SKIP=63, BMP_SKIP_SAVE=64, BMP_PIXEL=65, BMP_PIXEL_SAVE=66,
        BMP_PIXEL_LOW=67, BMP_PALETTE=68, BMP_PALETTE_SAVE=69;
    reg [6:0] state = WAIT_START;
    reg [6:0] disk_return = 0, word_return = 0, cluster_return = 0, byte_return = 0;
    reg [3:0] reset_delay = 0, bpb_step = 0;
    reg [8:0] word_address = 0;
    reg [2:0] word_length = 0, word_index = 0;
    reg [31:0] word_value = 0;
    reg [1:0] partition_index = 0;

    reg [31:0] volume_lba = 0;
    reg [15:0] bytes_per_sector = 0, reserved_sectors = 0, root_entries = 0;
    reg [7:0] sectors_per_cluster = 0, fat_count = 0;
    reg [15:0] total16 = 0, fat_size16 = 0, extended_flags = 0;
    reg [31:0] total32 = 0, fat_size32 = 0, root_cluster = 0;
    reg fat32 = 0;
    reg [2:0] cluster_shift = 0;
    reg [31:0] fat_begin = 0, data_begin = 0, max_cluster = 0;
    reg [31:0] directory_cluster = 0, directory_base = 0, root_sectors_left = 0;
    reg [7:0] directory_sector = 0;
    reg [3:0] directory_entry = 0;
    reg [12:0] directory_budget = 0;
    reg [31:0] walk_cluster = 0, next_cluster = 0;
    reg cluster_eof = 0;
    reg [31:0] file_cluster = 0, file_left = 0, file_size = 0;
    reg [7:0] file_sector = 0;
    reg [8:0] file_offset = 0;
    reg [7:0] file_byte = 0;
    reg [15:0] first_cluster_low = 0;
    reg scan_only = 0, search_score = 0, score_file = 0;
    reg catalog_guided = 0;
    reg cover_file = 0;
    reg [431:0] bmp_header = 0;
    reg [31:0] bmp_skip_left = 0;
    reg bmp_topdown = 0, bmp_palette_done = 0;
    reg [8:0] bmp_x = 0, bmp_y = 0;
    reg [1:0] bmp_phase = 0;
    reg [3:0] bmp_palette_index = 0;
    reg [7:0] bmp_blue = 0, bmp_green = 0, bmp_red = 0;
    wire [8:0] bmp_ram_y = bmp_topdown ? bmp_y : 9'd271-bmp_y;
    wire [16:0] bmp_ram_address = {8'b0,bmp_ram_y} * 17'd480 + {8'b0,bmp_x};
    reg [2:0] candidate_index = 0;
    reg [31:0] entry_first4 = 0, entry_last4 = 0;
    wire [63:0] entry_name = {entry_last4,entry_first4};
    reg [63:0] wanted_name = 0;
    reg [7:0] score_ram [0:255];
    reg [8:0] score_length = 0, score_write = 0, score_position = 0;
    reg score_v2 = 0;
    reg [31:0] score_magic=0;
    wire [7:0] score_mask_address={score_position[6:0],1'b0}+8'd4;
    wire [7:0] score_duration_address=score_mask_address+8'd1;
    assign score_mask = (score_ready && !score_done && score_position<score_length)
        ? score_ram[score_v2 ? score_mask_address : score_position[7:0]] : 8'h00;
    assign score_step_10ms = (score_ready && !score_done && score_v2)
        ? score_ram[score_duration_address] : 8'd50;
    always @(posedge clk24m) begin
        if (reset || scan_start || start) begin
            score_position <= 0; score_done <= 0;
        end else if (score_ready && !score_done && score_advance) begin
            if (score_position + 9'd1 >= score_length) score_done <= 1;
            else score_position <= score_position + 1'b1;
        end
    end

    // 使用扩展位宽做几何计算，避免目录扇区数加法在 16 位处溢出。
    wire [31:0] fat_size = (fat_size16 != 0) ? {16'b0,fat_size16} : fat_size32;
    wire [31:0] root_sector_count = ({16'b0,root_entries} + 32'd15) >> 4;
    wire [31:0] overhead_sectors = {16'b0,reserved_sectors} + fat_count * fat_size + root_sector_count;
    wire [31:0] volume_sectors = total16 != 0 ? {16'b0,total16} : total32;
    wire [31:0] cluster_count = (volume_sectors - overhead_sectors) >> cluster_shift;
    wire [31:0] wanted_file_sector = data_begin + ((file_cluster - 2) << cluster_shift) + file_sector;
    wire [31:0] wanted_directory_sector = fat32
        ? data_begin + ((directory_cluster - 2) << cluster_shift) + directory_sector
        : directory_base + directory_sector;

    reg [95:0] riff_header = 0;
    reg [63:0] chunk_header = 0;
    reg [5:0] header_index = 0;
    reg [31:0] riff_left = 0, chunk_left = 0, chunk_size = 0, format_index = 0;
    reg chunk_pad = 0, format_seen = 0, producer_done = 0, format_ready = 0;
    reg [15:0] format_tag = 0, channels = 0, block_align = 0, bits_per_sample = 0;
    reg [15:0] extension_size = 0, valid_bits = 0;
    reg [127:0] subtype_guid = 0;
    reg [31:0] source_rate = 0, data_left = 0;
    reg [2:0] bytes_per_sample = 0, sample_byte_index = 0;
    reg channel_index = 0;
    reg [31:0] sample_word = 0;
    reg signed [15:0] left_sample = 0, decoded_sample = 0;
    wire signed [15:0] normalized_sample = bits_per_sample == 8
        ? $signed({sample_word[31:24] ^ 8'h80,8'h00}) : $signed(sample_word[31:16]);
    wire signed [16:0] stereo_sum = $signed({left_sample[15],left_sample})
                                          + $signed({normalized_sample[15],normalized_sample});
    wire [32:0] padded_chunk_length = {1'b0,chunk_header[63:32]} + chunk_header[32];
    // CHUNK_CHECK verifies the subtraction does not underflow. The 33rd bit
    // is only needed for checking the padded length, not for RIFF's 32-bit size.
    wire [32:0] riff_after_chunk = {1'b0,riff_left} - 33'd8 - padded_chunk_length;

    function [7:0] uppercase;
        input [7:0] c;
        begin uppercase = (c >= 8'h61 && c <= 8'h7a) ? c - 8'd32 : c; end
    endfunction
    function [2:0] power_shift;
        input [7:0] value;
        begin
            case(value)
                1: power_shift=0; 2: power_shift=1; 4: power_shift=2; 8: power_shift=3;
                16: power_shift=4; 32: power_shift=5; 64: power_shift=6; default: power_shift=7;
            endcase
        end
    endfunction
    task read_disk;
        input [31:0] lba; input [6:0] return_to;
        begin read_sector <= lba; disk_return <= return_to; state <= DISK_REQUEST; end
    endtask
    task read_word;
        input [8:0] address; input [2:0] length; input [6:0] return_to;
        begin
            word_address <= address; word_length <= length; word_index <= 0;
            word_value <= 0; word_from_fat <= 0; word_return <= return_to; state <= WORD_ADDRESS;
        end
    endtask
    task get_file_byte;
        input [6:0] return_to;
        begin byte_return <= return_to; state <= FILE_BYTE; end
    endtask
    task follow_cluster;
        input [31:0] cluster; input [6:0] return_to;
        begin walk_cluster <= cluster; cluster_return <= return_to; state <= CLUSTER_READ; end
    endtask
    task fail;
        input [3:0] reason;
        begin error_code <= reason; busy <= 0; state <= FAILED; end
    endtask

    reg playback_finished = 0;
    always @(posedge clk24m) begin
        read_start <= 0; card_restart <= 0; fifo_push <= 0; flush <= 0; cover_we <= 0; cover_palette_we <= 0;
        if (reset) begin
            state <= WAIT_START; busy <= 0; error_code <= 0; cover_ready <= 0;
            score_ready <= 0;
            cache_valid <= 0; format_ready <= 0; producer_done <= 0;
            fat_cache_valid <= 0; capture_fat <= 0;
            read_start <= 0; card_restart <= 0; fifo_push <= 0; flush <= 1;
        end else begin
            case(state)
                WAIT_START, FAILED: if (start || scan_start || cover_start) begin
                    busy <= 1; error_code <= 0; card_restart <= 1; flush <= 1;
                    score_ready <= 0;
                    cache_valid <= 0; format_ready <= 0; producer_done <= 0;
                    fat_cache_valid <= 0; capture_fat <= 0;
                    format_seen <= 0; reset_delay <= 0; volume_lba <= 0;
                    partition_index <= 0; directory_budget <= 0;
                    scan_only <= scan_start && !cover_start;
                    cover_file <= cover_start;
                    if (cover_start) cover_ready <= 0;
                    catalog_guided <= scan_guided;
                    search_score <= start && guided; score_file <= 0;
                    if (start && guided)
                        wanted_name <= song_names[{selected_index,6'b0} +: 64];
                    candidate_index <= 0; score_write <= 0;
                    if (scan_start) begin
                        catalog_ready <= 0; song_count <= 0; song_names <= 0;
                    end
                    state <= INIT_DELAY;
                end
                INIT_DELAY: begin
                    if (reset_delay == 7) state <= WAIT_CARD;
                    else reset_delay <= reset_delay + 1'b1;
                end
                WAIT_CARD: begin
                    if (card_error) fail(1);
                    else if (card_ready) read_disk(0, BOOT_SIGNATURE);
                end

                DISK_REQUEST: begin
                    if (card_error) fail(1);
                    else if (card_ready && !card_busy) begin
                        read_start <= 1; cache_valid <= 0; state <= DISK_WAIT;
                    end
                end
                DISK_WAIT: begin
                    if (card_error) fail(1);
                    else if (card_done) begin
                        cache_sector <= read_sector; cache_valid <= 1; state <= disk_return;
                        if (capture_fat) begin
                            fat_cache_sector <= read_sector; fat_cache_valid <= 1; capture_fat <= 0;
                        end
                    end
                end
                // 小端整数读取：先读到的字节放在最低八位。
                WORD_ADDRESS: begin ram_address <= word_address + word_index; state <= WORD_DELAY; end
                WORD_DELAY: state <= WORD_TAKE;
                WORD_TAKE: begin
                    word_value[word_index*8 +: 8] <= word_from_fat ? fat_ram_data : ram_data;
                    if (word_index + 1 == word_length) state <= word_return;
                    else begin word_index <= word_index + 1'b1; state <= WORD_ADDRESS; end
                end

                BOOT_SIGNATURE: read_word(510, 2, BOOT_PROBE);
                BOOT_PROBE: begin
                    if (word_value[15:0] != 16'haa55) fail(2);
                    else read_word(11, 2, MBR_TYPE);
                end
                MBR_TYPE: begin
                    if (word_value == 512) begin bpb_step <= 0; state <= BPB_REQUEST; end
                    else read_word(9'd450 + {partition_index,4'b0}, 1, MBR_LBA);
                end
                MBR_LBA: begin
                    if (word_value == 4 || word_value == 6 || word_value == 14 || word_value == 11 || word_value == 12)
                        read_word(9'd454 + {partition_index,4'b0}, 4, VOLUME_SIGNATURE);
                    else if (partition_index == 3) fail(2);
                    else begin
                        partition_index <= partition_index + 1'b1;
                        // 不再重复探测 BPB，直接读取下一个分区类型。
                        read_word(9'd466 + {partition_index,4'b0}, 1, MBR_LBA);
                    end
                end
                VOLUME_SIGNATURE: begin
                    if (word_value == 0) fail(2);
                    else begin
                        volume_lba <= word_value; bpb_step <= 0;
                        read_disk(word_value, BPB_REQUEST);
                    end
                end
                BPB_REQUEST: begin
                    case (bpb_step)
                        0: read_word(11,2,BPB_SAVE); 1: read_word(13,1,BPB_SAVE);
                        2: read_word(14,2,BPB_SAVE); 3: read_word(16,1,BPB_SAVE);
                        4: read_word(17,2,BPB_SAVE); 5: read_word(19,2,BPB_SAVE);
                        6: read_word(22,2,BPB_SAVE); 7: read_word(32,4,BPB_SAVE);
                        8: read_word(36,4,BPB_SAVE); 9: read_word(44,4,BPB_SAVE);
                        10: read_word(40,2,BPB_SAVE); default: read_word(510,2,BPB_SAVE);
                    endcase
                end
                BPB_SAVE: begin
                    case (bpb_step)
                        0: bytes_per_sector <= word_value[15:0];
                        1: begin sectors_per_cluster <= word_value[7:0]; cluster_shift <= power_shift(word_value[7:0]); end
                        2: reserved_sectors <= word_value[15:0];
                        3: fat_count <= word_value[7:0];
                        4: root_entries <= word_value[15:0];
                        5: total16 <= word_value[15:0];
                        6: fat_size16 <= word_value[15:0];
                        7: total32 <= word_value;
                        8: fat_size32 <= word_value;
                        9: root_cluster <= word_value & 32'h0fffffff;
                        10: extended_flags <= word_value[15:0];
                        default: ;
                    endcase
                    if (bpb_step == 11) begin
                        if (word_value[15:0] != 16'haa55) fail(2);
                        else state <= GEOMETRY;
                    end else begin bpb_step <= bpb_step + 1'b1; state <= BPB_REQUEST; end
                end
                GEOMETRY: begin
                    if (bytes_per_sector != 512 || sectors_per_cluster == 0 || sectors_per_cluster > 128 ||
                        ((sectors_per_cluster & (sectors_per_cluster-1)) != 0) ||
                        reserved_sectors == 0 || fat_count == 0 || fat_count > 4 || fat_size == 0 ||
                        volume_sectors <= overhead_sectors || cluster_count < 4085 ||
                        (fat_size16 != 0 && (cluster_count >= 65525 || root_entries == 0)) ||
                        (fat_size16 == 0 && (cluster_count < 65525 || root_entries != 0 || root_cluster < 2 ||
                         root_cluster > cluster_count+1 || (extended_flags[7] && extended_flags[3:0] >= fat_count)))) begin
                        fail(2);
                    end else begin
                        fat32 <= (fat_size16 == 0);
                        fat_begin <= volume_lba + reserved_sectors +
                            ((fat_size16 == 0 && extended_flags[7]) ? extended_flags[3:0]*fat_size : 32'd0);
                        data_begin <= volume_lba + overhead_sectors;
                        max_cluster <= cluster_count + 1;
                        directory_cluster <= root_cluster;
                        directory_base <= volume_lba + reserved_sectors + fat_count*fat_size;
                        root_sectors_left <= root_sector_count;
                        directory_sector <= 0; directory_entry <= 0; state <= DIR_LOAD;
                    end
                end

                DIR_LOAD: begin
                    if (directory_budget == 4096) fail(3);
                    else begin
                        directory_budget <= directory_budget + 1'b1;
                        read_disk(wanted_directory_sector, DIR_FIRST);
                    end
                end
                DIR_FIRST: read_word({directory_entry,5'b0},1,DIR_NAME);
                DIR_NAME: begin
                    if (word_value[7:0] == 0) begin
                        if (scan_only && (song_count != 0 || catalog_guided)) begin
                            busy <= 0; catalog_ready <= 1; state <= WAIT_START;
                        end else fail(search_score ? 7 : 3);
                    end
                    else if (word_value[7:0] == 8'he5) state <= DIR_NEXT;
                    else read_word({directory_entry,5'b0},4,DIR_NAME_LOW);
                end
                DIR_NAME_LOW: begin
                    entry_first4 <= word_value;
                    read_word({directory_entry,5'b0}+9'd4,4,DIR_NAME_HIGH);
                end
                DIR_NAME_HIGH: begin
                    entry_last4 <= word_value;
                    read_word({directory_entry,5'b0}+9'd8,4,DIR_EXTENSION);
                end
                DIR_EXTENSION: begin
                    // Ignore volume labels, LFN, hidden/system files and directories.
                    if ((word_value[31:24] & 8'h1e) != 0) state <= DIR_NEXT;
                    else if (cover_file) begin
                        // Exact 8.3 name: COVER.BMP. LFN entries are ignored above.
                        if (entry_name == 64'h2020205245564f43 &&
                            uppercase(word_value[7:0]) == "B" &&
                            uppercase(word_value[15:8]) == "M" &&
                            uppercase(word_value[23:16]) == "P")
                            read_word({directory_entry,5'b0}+9'd26,2,DIR_HIGH_CLUSTER);
                        else state <= DIR_NEXT;
                    end else if (search_score) begin
                        if (uppercase(word_value[7:0]) == "N" &&
                            uppercase(word_value[15:8]) == "T" &&
                            uppercase(word_value[23:16]) == "E" &&
                            entry_name == wanted_name) begin
                            score_file <= 1;
                            read_word({directory_entry,5'b0}+9'd26,2,DIR_HIGH_CLUSTER);
                        end else state <= DIR_NEXT;
                    end else if (scan_only && catalog_guided &&
                                 uppercase(word_value[7:0]) == "N" &&
                                 uppercase(word_value[15:8]) == "T" &&
                                 uppercase(word_value[23:16]) == "E") begin
                        read_word({directory_entry,5'b0}+9'd26,2,DIR_HIGH_CLUSTER);
                    end else if (uppercase(word_value[7:0]) == "W" &&
                                 uppercase(word_value[15:8]) == "A" &&
                                 uppercase(word_value[23:16]) == "V") begin
                        if (scan_only && !catalog_guided) begin
                            if (song_count<8) begin
                                song_names[song_count*64 +: 64] <= entry_name;
                                song_count <= song_count + 1'b1;
                            end
                            state <= DIR_NEXT;
                        end else if (!scan_only && !guided &&
                                     candidate_index == selected_index) begin
                            score_file <= 0;
                            read_word({directory_entry,5'b0}+9'd26,2,DIR_HIGH_CLUSTER);
                        end else if (!scan_only && !guided) begin
                            candidate_index <= candidate_index + 1'b1;
                            state <= DIR_NEXT;
                        end else state <= DIR_NEXT;
                    end else state <= DIR_NEXT;
                end
                DIR_HIGH_CLUSTER: begin
                    first_cluster_low <= word_value[15:0];
                    read_word({directory_entry,5'b0}+9'd20,2,DIR_FILE_SIZE);
                end
                DIR_FILE_SIZE: begin
                    file_cluster <= fat32 ? {4'b0,word_value[11:0],first_cluster_low} : {16'b0,first_cluster_low};
                    read_word({directory_entry,5'b0}+9'd28,4,
                              (scan_only && catalog_guided) ? CATALOG_SCORE_SIZE :
                              (cover_file ? BMP_BEGIN : (score_file ? SCORE_BEGIN : RIFF_BYTE)));
                    file_sector <= 0; file_offset <= 0;
                    riff_header <= 0; header_index <= 0;
                end
                CATALOG_SCORE_SIZE: begin
                    // Directory metadata filters empty/oversize/invalid-cluster
                    // score files. Content is checked by SCORE_SAVE on selection.
                    if (word_value>=1 && word_value<=256 &&
                        file_cluster>=2 && file_cluster<=max_cluster &&
                        song_count<8) begin
                        song_names[song_count*64 +: 64] <= entry_name;
                        song_count <= song_count + 1'b1;
                    end
                    state <= DIR_NEXT;
                end
                DIR_NEXT: begin
                    if (directory_entry != 15) begin directory_entry <= directory_entry + 1'b1; state <= DIR_FIRST; end
                    else begin
                        directory_entry <= 0;
                        if (!fat32) begin
                            if (root_sectors_left <= 1) begin
                                if (scan_only && (song_count != 0 || catalog_guided)) begin
                                    busy <= 0; catalog_ready <= 1; state <= WAIT_START;
                                end else fail(search_score ? 7 : 3);
                            end
                            else begin
                                root_sectors_left <= root_sectors_left - 1'b1;
                                directory_base <= directory_base + 1'b1; state <= DIR_LOAD;
                            end
                        end else if (directory_sector + 1 < sectors_per_cluster) begin
                            directory_sector <= directory_sector + 1'b1; state <= DIR_LOAD;
                        end else follow_cluster(directory_cluster, DIR_AFTER_CLUSTER);
                    end
                end
                DIR_AFTER_CLUSTER: begin
                    if (cluster_eof) begin
                        if (scan_only && (song_count != 0 || catalog_guided)) begin
                            busy <= 0; catalog_ready <= 1; state <= WAIT_START;
                        end else fail(search_score ? 7 : 3);
                    end
                    else begin directory_cluster <= next_cluster; directory_sector <= 0; state <= DIR_LOAD; end
                end

                SCORE_BEGIN: begin
                    file_left <= word_value; file_size <= word_value;
                    score_length <= word_value[8:0]; score_write <= 0;
                    score_magic <= 0;
                    if (word_value == 0 || word_value > 256) fail(7);
                    else get_file_byte(SCORE_SAVE);
                end
                SCORE_SAVE: begin
                    score_ram[score_write[7:0]] <= file_byte;
                    if (score_write<4)
                        score_magic[{score_write[1:0],3'b000} +: 8]<=file_byte;
                    if (file_byte == 0) fail(7);
                    else if (score_write + 9'd1 >= score_length) state <= SCORE_FINISH;
                    else begin
                        score_write <= score_write + 1'b1;
                        get_file_byte(SCORE_SAVE);
                    end
                end
                SCORE_FINISH: begin
                    // Legacy bytes remain untouched. NTE2 uses the same 256
                    // byte RAM, so timed scores require no extra block RAM.
                    if (score_magic==32'h3245544e && (file_size<6 || file_size[0]))
                        fail(7);
                    else begin
                        if (score_magic==32'h3245544e) begin
                            score_v2<=1;
                            score_length<=(file_size[8:0]-9'd4)>>1;
                        end else score_v2<=0;
                        score_ready <= 1; busy <= 0; state <= WAIT_START;
                    end
                end

                // 480x272, 4-bit indexed Windows BMP. Each byte is two
                // pixels, high nibble first. Read all 16 BGR0 palette entries
                // before pixels; output native-resolution indices into RAM.
                // Both top-down and bottom-up files have exactly 240 B/row.
                BMP_BEGIN: begin
                    file_left <= word_value; file_size <= word_value;
                    bmp_header <= 0; header_index <= 0;
                    bmp_x <= 0; bmp_y <= 0; bmp_phase <= 0;
                    bmp_palette_index <= 0; bmp_palette_done <= 0;
                    if (word_value < 118) fail(8);
                    else state <= BMP_HEADER;
                end
                BMP_HEADER: get_file_byte(BMP_HEADER_SAVE);
                BMP_HEADER_SAVE: begin
                    bmp_header <= {file_byte,bmp_header[431:8]};
                    if (header_index == 53) state <= BMP_CHECK;
                    else begin header_index <= header_index + 1'b1; state <= BMP_HEADER; end
                end
                BMP_CHECK: begin
                    if (bmp_header[15:0] != 16'h4d42 ||
                        bmp_header[143:112] < 32'd40 || bmp_header[143:112] > 32'd4000 ||
                        bmp_header[239:224] != 16'd4 ||
                        bmp_header[223:208] != 16'd1 ||
                        bmp_header[271:240] != 0 ||
                        bmp_header[111:80] < bmp_header[143:112]+32'd78 ||
                        bmp_header[111:80] > 32'd4096 ||
                        bmp_header[175:144] != 32'd480 ||
                        (bmp_header[207:176] != 32'd272 && bmp_header[207:176] != 32'hfffffef0) ||
                        (bmp_header[399:368] != 0 && bmp_header[399:368] != 16)) fail(8);
                    else if (file_size < bmp_header[111:80]+32'd65280) fail(8);
                    else begin
                        bmp_topdown <= bmp_header[207];
                        // Base header consumed 54 B. Extended DIB bytes come
                        // before the 16-entry color table, not before pixels.
                        bmp_skip_left <= bmp_header[143:112]-32'd40;
                        state <= BMP_SKIP;
                    end
                end
                BMP_SKIP: begin
                    if (bmp_skip_left == 0)
                        state <= bmp_palette_done ? BMP_PIXEL : BMP_PALETTE;
                    else get_file_byte(BMP_SKIP_SAVE);
                end
                BMP_SKIP_SAVE: begin bmp_skip_left <= bmp_skip_left-1'b1; state <= BMP_SKIP; end
                BMP_PALETTE: get_file_byte(BMP_PALETTE_SAVE);
                BMP_PALETTE_SAVE: begin
                    state <= BMP_PALETTE;
                    case (bmp_phase)
                        0: begin bmp_blue <= file_byte; bmp_phase <= 1; end
                        1: begin bmp_green <= file_byte; bmp_phase <= 2; end
                        2: begin bmp_red <= file_byte; bmp_phase <= 3; end
                        3: begin
                            // Fourth byte is reserved, not alpha.
                            cover_palette_we <= 1;
                            cover_palette_address <= bmp_palette_index;
                            cover_palette_pixel <= {bmp_red[7:3],bmp_green[7:2],bmp_blue[7:3]};
                            bmp_phase <= 0;
                            if (bmp_palette_index == 15) begin
                                bmp_palette_done <= 1;
                                bmp_skip_left <= bmp_header[111:80]-bmp_header[143:112]-32'd78;
                                state <= BMP_SKIP;
                            end else bmp_palette_index <= bmp_palette_index+1'b1;
                        end
                    endcase
                end
                BMP_PIXEL: get_file_byte(BMP_PIXEL_SAVE);
                BMP_PIXEL_SAVE: begin
                    cover_we <= 1;
                    cover_address <= bmp_ram_address;
                    cover_pixel <= file_byte[7:4];
                    state <= BMP_PIXEL_LOW;
                end
                BMP_PIXEL_LOW: begin
                    cover_we <= 1;
                    cover_address <= bmp_ram_address+17'd1;
                    cover_pixel <= file_byte[3:0];
                    if (bmp_x == 9'd478) begin
                        bmp_x <= 0;
                        if (bmp_y == 9'd271) begin
                            cover_ready <= 1; busy <= 0; state <= WAIT_START;
                        end else begin bmp_y <= bmp_y+1'b1; state <= BMP_PIXEL; end
                    end else begin bmp_x <= bmp_x+9'd2; state <= BMP_PIXEL; end
                end

                // FAT 表查询支持非连续簇，因此文件不要求连续存放。
                CLUSTER_READ: begin
                    if (walk_cluster < 2 || walk_cluster > max_cluster) fail(4);
                    else if (fat_cache_valid && fat_cache_sector == fat_begin + (walk_cluster >> (fat32 ? 7 : 8))) begin
                        read_word(fat32 ? {walk_cluster[6:0],2'b0} : {walk_cluster[7:0],1'b0},
                                  fat32 ? 3'd4 : 3'd2, CLUSTER_DECODE);
                        word_from_fat <= 1;
                    end else begin
                        capture_fat <= 1;
                        read_disk(fat_begin + (walk_cluster >> (fat32 ? 7 : 8)), CLUSTER_VALUE);
                    end
                end
                CLUSTER_VALUE: begin
                    read_word(fat32 ? {walk_cluster[6:0],2'b0} : {walk_cluster[7:0],1'b0},
                              fat32 ? 3'd4 : 3'd2, CLUSTER_DECODE);
                    word_from_fat <= 1;
                end
                CLUSTER_DECODE: begin
                    next_cluster <= fat32 ? (word_value & 32'h0fffffff) : (word_value & 32'h0000ffff);
                    cluster_eof <= fat32 ? ((word_value & 32'h0fffffff) >= 32'h0ffffff8)
                                        : (word_value[15:0] >= 16'hfff8);
                    if ((fat32 ? ((word_value & 32'h0fffffff) >= 32'h0ffffff8) : (word_value[15:0] >= 16'hfff8)))
                        state <= cluster_return;
                    else if ((fat32 ? (word_value & 32'h0fffffff) : (word_value & 32'hffff)) < 2 ||
                             (fat32 ? (word_value & 32'h0fffffff) : (word_value & 32'hffff)) > max_cluster) fail(4);
                    else state <= cluster_return;
                end
                FILE_BYTE: begin
                    if (file_left == 0 || file_cluster < 2 || file_cluster > max_cluster) fail(4);
                    else if (file_sector == sectors_per_cluster) follow_cluster(file_cluster, FILE_NEXT_CLUSTER);
                    else if (!cache_valid || cache_sector != wanted_file_sector) read_disk(wanted_file_sector, FILE_BYTE);
                    else begin ram_address <= file_offset; state <= FILE_DELAY; end
                end
                FILE_DELAY: state <= FILE_TAKE;
                FILE_TAKE: begin
                    file_byte <= ram_data; file_left <= file_left - 1'b1;
                    if (file_offset == 511) begin file_offset <= 0; file_sector <= file_sector + 1'b1; end
                    else file_offset <= file_offset + 1'b1;
                    state <= byte_return;
                end
                FILE_NEXT_CLUSTER: begin
                    if (cluster_eof) fail(4);
                    else begin file_cluster <= next_cluster; file_sector <= 0; state <= FILE_BYTE; end
                end

                // 初次进入 RIFF_BYTE 时 word_value 是目录记录中的文件长度。
                RIFF_BYTE: begin
                    if (header_index == 0) begin
                        file_left <= word_value; file_size <= word_value;
                        if (word_value < 12) fail(5);
                        else get_file_byte(RIFF_SAVE);
                    end else get_file_byte(RIFF_SAVE);
                end
                RIFF_SAVE: begin
                    riff_header <= {file_byte,riff_header[95:8]};
                    if (header_index == 11) state <= RIFF_CHECK;
                    else begin header_index <= header_index + 1'b1; state <= RIFF_BYTE; end
                end
                RIFF_CHECK: begin
                    if (riff_header[31:0] != 32'h46464952 || riff_header[95:64] != 32'h45564157 ||
                        riff_header[63:32] < 4 || riff_header[63:32] > file_size-8) fail(5);
                    else begin
                        riff_left <= riff_header[63:32]-4;
                        header_index <= 0; chunk_header <= 0; state <= CHUNK_BYTE;
                    end
                end
                CHUNK_BYTE: begin
                    if (riff_left < 8 || file_left < 8-header_index) fail(5);
                    else get_file_byte(CHUNK_SAVE);
                end
                CHUNK_SAVE: begin
                    chunk_header <= {file_byte,chunk_header[63:8]};
                    if (header_index == 7) state <= CHUNK_CHECK;
                    else begin header_index <= header_index + 1'b1; state <= CHUNK_BYTE; end
                end
                CHUNK_CHECK: begin
                    if (padded_chunk_length > {1'b0,riff_left}-8 || padded_chunk_length > {1'b0,file_left}) fail(5);
                    else begin
                        riff_left <= riff_after_chunk[31:0];
                        chunk_left <= chunk_header[63:32]; chunk_size <= chunk_header[63:32];
                        chunk_pad <= chunk_header[32];
                        if (chunk_header[31:0] == 32'h20746d66) begin
                            format_index <= 0; format_tag <= 0; channels <= 0;
                            source_rate <= 0; block_align <= 0; bits_per_sample <= 0;
                            subtype_guid <= 0; extension_size <= 0; valid_bits <= 0;
                            if (chunk_header[63:32] < 16) fail(5); else state <= FMT_BYTE;
                        end else if (chunk_header[31:0] == 32'h61746164) state <= DATA_CHECK;
                        else state <= SKIP_BYTE;
                    end
                end
                FMT_BYTE: begin
                    if (chunk_left == 0) state <= FMT_CHECK;
                    else get_file_byte(FMT_SAVE);
                end
                FMT_SAVE: begin
                    case (format_index)
                        0: format_tag[7:0]<=file_byte; 1: format_tag[15:8]<=file_byte;
                        2: channels[7:0]<=file_byte; 3: channels[15:8]<=file_byte;
                        4: source_rate[7:0]<=file_byte; 5: source_rate[15:8]<=file_byte;
                        6: source_rate[23:16]<=file_byte; 7: source_rate[31:24]<=file_byte;
                        12: block_align[7:0]<=file_byte; 13: block_align[15:8]<=file_byte;
                        14: bits_per_sample[7:0]<=file_byte; 15: bits_per_sample[15:8]<=file_byte;
                        16: extension_size[7:0]<=file_byte; 17: extension_size[15:8]<=file_byte;
                        18: valid_bits[7:0]<=file_byte; 19: valid_bits[15:8]<=file_byte;
                        default: if (format_index >= 24 && format_index < 40)
                            subtype_guid <= {file_byte,subtype_guid[127:8]};
                    endcase
                    format_index <= format_index + 1'b1; chunk_left <= chunk_left - 1'b1;
                    state <= FMT_BYTE;
                end
                FMT_CHECK: begin
                    if ((format_tag != 1 && !(format_tag == 16'hfffe && chunk_size >= 40 && extension_size >= 22 &&
                         subtype_guid == 128'h719b3800aa0000800010000000000001 && valid_bits != 0 && valid_bits <= bits_per_sample)) ||
                        (channels != 1 && channels != 2) || source_rate < 8000 || source_rate > 96000 ||
                        (bits_per_sample != 8 && bits_per_sample != 16 && bits_per_sample != 24 && bits_per_sample != 32) ||
                        block_align != ((bits_per_sample >> 3) * channels)) fail(6);
                    else begin
                        // Only 8/16/24/32-bit PCM reaches here: 1/2/3/4 bytes.
                        bytes_per_sample <= bits_per_sample[5:3];
                        format_seen <= 1; state <= PAD_BYTE;
                    end
                end
                SKIP_BYTE: begin
                    if (chunk_left == 0) state <= PAD_BYTE;
                    else get_file_byte(SKIP_SAVE);
                end
                SKIP_SAVE: begin chunk_left <= chunk_left - 1'b1; state <= SKIP_BYTE; end
                PAD_BYTE: begin
                    if (chunk_pad) begin chunk_pad <= 0; get_file_byte(PAD_CONSUMED); end
                    else begin header_index <= 0; chunk_header <= 0; state <= CHUNK_BYTE; end
                end
                PAD_CONSUMED: begin header_index <= 0; chunk_header <= 0; state <= CHUNK_BYTE; end
                DATA_CHECK: begin
                    if (!format_seen || chunk_left == 0) fail(5);
                    else begin data_left <= chunk_left; format_ready <= 1; state <= PCM_BEGIN; end
                end
                PCM_BEGIN: begin
                    if (data_left == 0) begin producer_done <= 1; state <= DRAIN; end
                    else if (data_left < block_align) fail(5); // 拒绝末尾不完整的采样帧
                    else begin sample_byte_index <= 0; channel_index <= 0; state <= PCM_BYTE; end
                end
                PCM_BYTE: get_file_byte(PCM_SAVE);
                PCM_SAVE: begin
                    sample_word <= {file_byte,sample_word[31:8]};
                    data_left <= data_left - 1'b1;
                    if (sample_byte_index + 1 == bytes_per_sample) state <= PCM_CHANNEL;
                    else begin sample_byte_index <= sample_byte_index + 1'b1; state <= PCM_BYTE; end
                end
                PCM_CHANNEL: begin
                    if (channels == 1) begin decoded_sample <= normalized_sample; state <= PCM_EMIT; end
                    else if (!channel_index) begin
                        left_sample <= normalized_sample; channel_index <= 1;
                        sample_byte_index <= 0; state <= PCM_BYTE;
                    end else begin decoded_sample <= stereo_sum >>> 1; state <= PCM_EMIT; end
                end
                PCM_EMIT: if (fifo_count < 4096) begin
                    fifo_input <= decoded_sample; fifo_push <= 1; state <= PCM_BEGIN;
                end
                DRAIN: if (playback_finished) begin busy <= 0; state <= WAIT_START; end
                default: fail(5);
            endcase
        end
    end

    // ============================================================
    // 四、32 kHz 输出和线性插值。
    // 两个相邻源采样记为 current_sample / next_sample。
    // fraction 表示它们之间的位置，分母固定为 32000。
    // 每输出一次就向前移动 source_rate/32000 个源采样，播放速度不变。
    // 这是基本线性插值，不是专业抗混叠重采样滤波器。
    // ============================================================
    localparam C_PREFILL=0, C_FIRST_WAIT=1, C_FIRST_SAVE=2, C_NEXT=3,
        C_NEXT_WAIT=4, C_NEXT_SAVE=5, C_IDLE=6, C_MULTIPLY=7,
        C_ADD=8, C_DIV_INIT=9, C_ADVANCE=10, C_READ_WAIT=11, C_READ_SAVE=12,
        C_DIV_STEP=13, C_DIV_DONE=14;
    reg [3:0] consumer = C_PREFILL;
    reg signed [15:0] current_sample = 0, next_sample = 0;
    reg current_valid = 0, next_valid = 0;
    reg [16:0] fraction = 0;
    reg [2:0] advance_left = 0;
    reg signed [33:0] product_a = 0, product_b = 0, interpolation_sum = 0;
    reg [31:0] dividend = 0;
    reg [15:0] quotient = 0, remainder = 0;
    reg [5:0] divide_count = 0;
    reg negative_result = 0;
    wire [16:0] trial_remainder = {remainder,dividend[31]};
    wire [17:0] next_fraction = {1'b0,fraction} + {1'b0,source_rate[16:0]};
    wire signed [33:0] abs_interpolation = interpolation_sum[33]
        ? -interpolation_sum : interpolation_sum;
    wire [16:0] remainder_after_subtract = trial_remainder - 17'd32000;
    wire signed [16:0] magnitude_sample = $signed({1'b0,quotient});
    wire signed [16:0] restored_sample = negative_result
        ? -magnitude_sample : magnitude_sample;
    wire [17:0] fraction_after_3 = next_fraction - 18'd96000;
    wire [17:0] fraction_after_2 = next_fraction - 18'd64000;
    wire [17:0] fraction_after_1 = next_fraction - 18'd32000;

    always @(posedge clk24m) begin
        fifo_pop <= 0; playback_finished <= 0;
        if (reset || flush || error_code != 0) begin
            consumer <= C_PREFILL; playing <= 0; pcm_sample <= 0;
            current_sample <= 0; next_sample <= 0;
            current_valid <= 0; next_valid <= 0;
            fraction <= 0; advance_left <= 0; underrun <= 0;
            dividend <= 0; quotient <= 0; remainder <= 0;
            divide_count <= 0; negative_result <= 0;
        end else begin
            // 欠载时保持最后一个有效采样，等待读卡追上，并点亮提示灯。
            if (sample_tick && playing && consumer != C_IDLE) underrun <= 1;
            case (consumer)
                C_PREFILL: if (format_ready && (fifo_count >= 1024 || (producer_done && fifo_count != 0))) begin
                    fifo_pop <= 1; consumer <= C_FIRST_WAIT;
                end
                C_FIRST_WAIT: consumer <= C_FIRST_SAVE;
                C_FIRST_SAVE: begin current_sample <= fifo_output; current_valid <= 1; consumer <= C_NEXT; end
                C_NEXT: begin
                    if (fifo_count != 0) begin fifo_pop <= 1; consumer <= C_NEXT_WAIT; end
                    else if (producer_done) begin next_sample <= 0; next_valid <= 0; playing <= 1; consumer <= C_IDLE; end
                end
                C_NEXT_WAIT: consumer <= C_NEXT_SAVE;
                C_NEXT_SAVE: begin next_sample <= fifo_output; next_valid <= 1; playing <= 1; consumer <= C_IDLE; end
                C_IDLE: if (sample_tick) begin
                    if (!current_valid) begin
                        playing <= 0; pcm_sample <= 0; playback_finished <= 1; consumer <= C_PREFILL;
                    end else consumer <= C_MULTIPLY;
                end
                C_MULTIPLY: begin
                    product_a <= current_sample * $signed(18'd32000 - {1'b0,fraction});
                    product_b <= next_sample * $signed({1'b0,fraction});
                    consumer <= C_ADD;
                end
                C_ADD: begin interpolation_sum <= product_a + product_b; consumer <= C_DIV_INIT; end
                // 串行长除法：每周期算一位，共 32 周期，约 1.3 us。
                // 相比一大块组合除法器，节省资源，也容易满足 24.576 MHz 时序。
                // 先对绝对值除以 32000，再恢复符号，与有符号除法的截断规则一致。
                C_DIV_INIT: begin
                    // |PCM| * 32000 <= 1,048,576,000, so 32 bits suffice.
                    dividend <= abs_interpolation[31:0];
                    negative_result <= interpolation_sum[33];
                    quotient <= 0; remainder <= 0; divide_count <= 0;
                    consumer <= C_DIV_STEP;
                end
                C_DIV_STEP: begin
                    dividend <= {dividend[30:0],1'b0};
                    if (trial_remainder >= 17'd32000) begin
                        // After subtraction the restoring-division remainder is <32000.
                        remainder <= remainder_after_subtract[15:0];
                        quotient <= {quotient[14:0],1'b1};
                    end else begin
                        remainder <= trial_remainder[15:0];
                        quotient <= {quotient[14:0],1'b0};
                    end
                    if (divide_count == 31) consumer <= C_DIV_DONE;
                    else divide_count <= divide_count + 1'b1;
                end
                C_DIV_DONE: begin
                    // Source samples are signed 16-bit; the 17th bit is sign
                    // extension, including -32768 (0x18000 in 17-bit form).
                    pcm_sample <= restored_sample[15:0];
                    // 最高支持 96 kHz，一次最多前进三个源采样，不需要再做除法。
                    if (next_fraction >= 18'd96000) begin
                        advance_left <= 3; fraction <= fraction_after_3[16:0];
                    end else if (next_fraction >= 18'd64000) begin
                        advance_left <= 2; fraction <= fraction_after_2[16:0];
                    end else if (next_fraction >= 18'd32000) begin
                        advance_left <= 1; fraction <= fraction_after_1[16:0];
                    end else begin advance_left <= 0; fraction <= next_fraction[16:0]; end
                    consumer <= C_ADVANCE;
                end
                C_ADVANCE: begin
                    if (advance_left == 0) consumer <= C_IDLE;
                    else if (fifo_count != 0) begin
                        current_sample <= next_sample; current_valid <= next_valid;
                        fifo_pop <= 1; consumer <= C_READ_WAIT;
                    end else if (producer_done) begin
                        current_sample <= next_sample; current_valid <= next_valid;
                        next_sample <= 0; next_valid <= 0;
                        advance_left <= advance_left - 1'b1;
                    end
                end
                C_READ_WAIT: consumer <= C_READ_SAVE;
                C_READ_SAVE: begin
                    next_sample <= fifo_output; next_valid <= 1;
                    advance_left <= advance_left - 1'b1; consumer <= C_ADVANCE;
                end
                default: consumer <= C_PREFILL;
            endcase
        end
    end
endmodule
