// Sipeed Tang Nano 20K 4.3-inch 480x272 RGB LCD, DE mode.
// CLK0 of the on-board MS5351 supplies 9 MHz on FPGA pin 10.
// No framebuffer: menu and live notes are drawn directly from scan coordinates.
module lcd_notes_480x272 (
    input wire clk9m,
    input wire snapshot_request,
    output reg snapshot_ack=0,
    output reg [767:0] snapshot_data=0,
    input wire [16:0] phone_cover_address,
    output wire [3:0] phone_cover_index,
    input wire [3:0] phone_palette_address,
    output wire [15:0] phone_palette_color,
    input wire cover_clk, cover_we,
    input wire [16:0] cover_address,
    input wire [3:0] cover_pixel,
    input wire cover_palette_we,
    input wire [3:0] cover_palette_address,
    input wire [15:0] cover_palette_pixel,
    input wire cover_ready_async,
    input wire [7:0] keys_async,
    input wire [7:0] volume_async,
    input wire phone_volume_owner_async,
    input wire fsr_async,
    input wire [7:0] fsr_bend_async,
    input wire [1:0] timbre_a_async,
    input wire [1:0] timbre_b_async,
    input wire [1:0] voice_mode_async,
    input wire [1:0] effect_mode_async,
    input wire metronome_async,
    input wire [1:0] vibrato_depth_async,
    input wire [2:0] ui_mode_async,
    input wire [1:0] selection_async,
    input wire [2:0] song_selection_async,
    input wire [3:0] song_count_async,
    input wire [511:0] song_names_async,
    input wire catalog_ready_async, sd_busy_async, sd_playing_async,
    input wire [3:0] sd_error_async,
    input wire [7:0] score_mask_async,
    input wire score_ready_async, score_done_async,
    input wire [8:0] beat_phase_async,
    input wire [1:0] timing_hint_async,
    input wire [6:0] final_percent_async,
    input wire result_valid_async,
    input wire [7:0] latency_tenth_async,
    input wire latency_valid_async,
    output wire lcd_clk,
    output wire lcd_de,
    output wire lcd_bl,
    output wire [4:0] lcd_r,
    output wire [5:0] lcd_g,
    output wire [4:0] lcd_b
);
    localparam H_TOTAL = 560, V_TOTAL = 297;
    localparam [9:0] H_START = 10'd30;
    localparam [8:0] V_START = 9'd5;
    reg [9:0] x = 0;
    reg [8:0] y = 0;

    // Two FFs cross the 24.576 MHz key state into the 9 MHz pixel domain.
    // Frame latch prevents a note card changing halfway down the screen.
    reg [7:0] keys_sync1 = 0, keys_sync2 = 0, frame_keys = 0;
    reg [7:0] vol_sync1=8'd255, vol_sync2=8'd255, frame_vol=8'd255;
    reg owner_sync1=0, owner_sync2=0, frame_owner=0;
    reg fsr_sync1=0, fsr_sync2=0, frame_fsr=0;
    reg [7:0] bend_sync1=0,bend_sync2=0,frame_bend=0;
    reg [1:0] a_sync1=0, a_sync2=0, frame_a=0;
    reg [1:0] b_sync1=2, b_sync2=2, frame_b=2;
    reg [1:0] voice_sync1=0, voice_sync2=0, frame_voice=0;
    reg [1:0] effect_sync1=0, effect_sync2=0, frame_effect=0;
    reg beat_sync1=0, beat_sync2=0, frame_beat=0;
    reg [1:0] depth_sync1=2,depth_sync2=2,frame_depth=2;
    reg [2:0] mode_sync1 = 7, mode_sync2 = 7, frame_mode = 7;
    reg [1:0] sel_sync1 = 0, sel_sync2 = 0, frame_sel = 0;
    reg [2:0] song_sel_sync1=0, song_sel_sync2=0, frame_song_sel=0;
    reg [3:0] count_sync1=0, count_sync2=0, frame_song_count=0;
    reg catalog_sync1=0, catalog_sync2=0, frame_catalog=0;
    reg busy_sync1=0, busy_sync2=0, frame_busy=0;
    reg playing_sync1=0, playing_sync2=0, frame_playing=0;
    reg [3:0] err_sync1=0, err_sync2=0, frame_error=0;
    reg [7:0] score_sync1=0, score_sync2=0, frame_score=0;
    reg score_valid_sync1=0, score_valid_sync2=0, frame_score_valid=0;
    reg score_done_sync1=0, score_done_sync2=0, frame_score_done=0;
    reg [8:0] phase_sync1=0, phase_sync2=0, frame_phase=0;
    reg [1:0] hint_sync1=0, hint_sync2=0, frame_hint=0;
    reg [6:0] percent_sync1=0, percent_sync2=0, frame_percent=0;
    reg result_sync1=0, result_sync2=0, frame_result=0;
    reg [7:0] latency_sync1=0, latency_sync2=0, frame_latency=0;
    reg latency_valid_sync1=0, latency_valid_sync2=0, frame_latency_valid=0;
    reg cover_sync1=0, cover_sync2=0, frame_cover=0;
    reg [511:0] frame_song_names=0; // Stable before catalog_ready rises.
    always @(posedge clk9m) begin
        cover_sync1<=cover_ready_async; cover_sync2<=cover_sync1;
        keys_sync1 <= keys_async;
        keys_sync2 <= keys_sync1;
        vol_sync1<=volume_async; vol_sync2<=vol_sync1;
        owner_sync1<=phone_volume_owner_async; owner_sync2<=owner_sync1;
        fsr_sync1<=fsr_async; fsr_sync2<=fsr_sync1;
        bend_sync1<=fsr_bend_async; bend_sync2<=bend_sync1;
        a_sync1<=timbre_a_async; a_sync2<=a_sync1;
        b_sync1<=timbre_b_async; b_sync2<=b_sync1;
        voice_sync1<=voice_mode_async; voice_sync2<=voice_sync1;
        effect_sync1<=effect_mode_async; effect_sync2<=effect_sync1;
        beat_sync1<=metronome_async; beat_sync2<=beat_sync1;
        depth_sync1<=vibrato_depth_async; depth_sync2<=depth_sync1;
        mode_sync1 <= ui_mode_async;
        mode_sync2 <= mode_sync1;
        sel_sync1 <= selection_async;
        sel_sync2 <= sel_sync1;
        song_sel_sync1<=song_selection_async; song_sel_sync2<=song_sel_sync1;
        count_sync1<=song_count_async; count_sync2<=count_sync1;
        catalog_sync1<=catalog_ready_async; catalog_sync2<=catalog_sync1;
        busy_sync1<=sd_busy_async; busy_sync2<=busy_sync1;
        playing_sync1<=sd_playing_async; playing_sync2<=playing_sync1;
        err_sync1<=sd_error_async; err_sync2<=err_sync1;
        score_sync1<=score_mask_async; score_sync2<=score_sync1;
        score_valid_sync1<=score_ready_async; score_valid_sync2<=score_valid_sync1;
        score_done_sync1<=score_done_async; score_done_sync2<=score_done_sync1;
        phase_sync1<=beat_phase_async; phase_sync2<=phase_sync1;
        hint_sync1<=timing_hint_async; hint_sync2<=hint_sync1;
        percent_sync1<=final_percent_async; percent_sync2<=percent_sync1;
        result_sync1<=result_valid_async; result_sync2<=result_sync1;
        latency_sync1<=latency_tenth_async; latency_sync2<=latency_sync1;
        latency_valid_sync1<=latency_valid_async;
        latency_valid_sync2<=latency_valid_sync1;
        if (x == H_TOTAL-1) begin
            x <= 0;
            if (y == V_TOTAL-1) begin
                y <= 0;
                frame_cover <= cover_sync2;
                frame_keys <= keys_sync2;
                frame_vol <= vol_sync2;
                frame_owner<=owner_sync2;
                frame_fsr <= fsr_sync2;
                frame_bend<=bend_sync2;
                frame_a<=a_sync2; frame_b<=b_sync2;
                frame_voice<=voice_sync2;
                frame_effect<=effect_sync2; frame_beat<=beat_sync2;
                frame_depth<=depth_sync2;
                frame_mode <= mode_sync2;
                frame_sel <= sel_sync2;
                frame_song_sel<=song_sel_sync2;
                frame_song_count<=count_sync2;
                frame_catalog<=catalog_sync2;
                frame_busy<=busy_sync2;
                frame_playing<=playing_sync2;
                frame_error<=err_sync2;
                frame_score<=score_sync2;
                frame_score_valid<=score_valid_sync2;
                frame_score_done<=score_done_sync2;
                frame_phase<=phase_sync2;
                frame_hint<=hint_sync2;
                frame_percent<=percent_sync2;
                frame_result<=result_sync2;
                frame_latency<=latency_sync2;
                frame_latency_valid<=latency_valid_sync2;
                if (catalog_sync2) frame_song_names<=song_names_async;
            end else y <= y + 1'b1;
        end else x <= x + 1'b1;
    end

    reg request_meta=0, request_sync=0;
    always @(posedge clk9m) begin
        request_meta<=snapshot_request; request_sync<=request_meta;
        if (request_sync!=snapshot_ack) begin
            snapshot_data<=0;
            snapshot_data[0 +: 8]<=8'h59;
            snapshot_data[8 +: 8]<=8'h4c;
            snapshot_data[16 +: 8]<=8'd2;
            snapshot_data[24 +: 8]<={5'd0,frame_mode};
            snapshot_data[32 +: 8]<={6'd0,frame_sel};
            snapshot_data[40 +: 8]<={5'd0,frame_song_sel};
            snapshot_data[48 +: 8]<={4'd0,frame_song_count};
            snapshot_data[56 +: 8]<={1'b0,frame_cover,frame_result,frame_score_done,frame_score_valid,frame_playing,frame_busy,frame_catalog};
            snapshot_data[64 +: 8]<=frame_keys;
            snapshot_data[72 +: 8]<=frame_score;
            snapshot_data[80 +: 8]<=frame_vol;
            snapshot_data[88 +: 8]<=frame_bend;
            snapshot_data[96 +: 8]<={6'd0,frame_a};
            snapshot_data[104 +: 8]<={6'd0,frame_b};
            snapshot_data[112 +: 8]<={6'd0,frame_voice};
            snapshot_data[120 +: 8]<={6'd0,frame_effect};
            snapshot_data[128 +: 8]<={7'd0,frame_beat};
            snapshot_data[136 +: 8]<={6'd0,frame_hint};
            snapshot_data[144 +: 8]<={1'd0,frame_percent};
            snapshot_data[152 +: 8]<=frame_latency;
            snapshot_data[160 +: 8]<={7'd0,frame_latency_valid};
            snapshot_data[168 +: 8]<=frame_phase[7:0];
            snapshot_data[176 +: 8]<={7'd0,frame_phase[8]};
            snapshot_data[184 +: 8]<={4'd0,frame_error};
            snapshot_data[192 +: 512]<=frame_song_names;
            snapshot_data[704 +: 8]<={6'd0,frame_depth}; // status byte 88
            snapshot_data[712 +: 8]<={7'd0,frame_owner}; // status byte 89
            snapshot_ack<=request_sync;
        end
    end

    wire visible = (x >= H_START && x < 10'd510 &&
                    y >= V_START && y < 9'd277);
    wire [9:0] ax = x - H_START;
    wire [8:0] ay = y - V_START;
    wire [15:0] menu_rgb;
    lcd_menu_pixels start_menu (
        .x(ax), .y(ay), .mode(frame_mode), .selection(frame_sel),
        .song_selection(frame_song_sel), .song_count(frame_song_count),
        .song_names(frame_song_names), .catalog_ready(frame_catalog),
        .sd_busy(frame_busy), .sd_playing(frame_playing),
        .sd_error(frame_error), .score_ready(frame_score_valid),
        .volume(frame_vol),
        .fsr_active(frame_fsr),
        .fsr_bend(frame_bend),
        .timbre_a(frame_a), .timbre_b(frame_b), .voice_mode(frame_voice),
        .effect_mode(frame_effect), .metronome(frame_beat),
        .beat_phase_ms(frame_phase), .timing_hint(frame_hint),
        .final_percent(frame_percent), .result_valid(frame_result),
        .latency_tenth_ms(frame_latency), .latency_valid(frame_latency_valid),
        .score_done(frame_score_done), .rgb(menu_rgb)
    );
    // Wider intermediate differences make the intentional 7-bit card-local
    // coordinates explicit; card bounds below guarantee values at most 103.
    wire [9:0] dx0 = ax - 10'd16, dx1 = ax - 10'd132;
    wire [9:0] dx2 = ax - 10'd248, dx3 = ax - 10'd364;
    wire [8:0] dy0 = ay - 9'd24, dy1 = ay - 9'd148;
    // Color and DE change on the rising edge of clk9m. The LCD sees the
    // next rising edge of the inverted pixel clock, half a cycle later.
    assign lcd_clk = ~clk9m;
    assign lcd_de = visible;
    assign lcd_bl = 1'b1;

    // Font rows are MSB-first; glyph 0..6 = C D E F G A B,
    // glyph 7/8 = 4/5. The remaining glyphs spell solfege labels.
    function [4:0] font_row;
        input [3:0] glyph;
        input [2:0] row;
        begin
            font_row = 5'b00000;
            case (glyph)
                0: case (row) // C
                    0: font_row=5'b01111; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b10000;
                    4: font_row=5'b10000; 5: font_row=5'b10000;
                    6: font_row=5'b01111;
                endcase
                1: case (row) // D
                    0: font_row=5'b11110; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b10001;
                    4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b11110;
                endcase
                2: case (row) // E
                    0: font_row=5'b11111; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b11110;
                    4: font_row=5'b10000; 5: font_row=5'b10000;
                    6: font_row=5'b11111;
                endcase
                3: case (row) // F
                    0: font_row=5'b11111; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b11110;
                    4: font_row=5'b10000; 5: font_row=5'b10000;
                    6: font_row=5'b10000;
                endcase
                4: case (row) // G
                    0: font_row=5'b01111; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b10111;
                    4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b01111;
                endcase
                5: case (row) // A
                    0: font_row=5'b01110; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b11111;
                    4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b10001;
                endcase
                6: case (row) // B
                    0: font_row=5'b11110; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b11110;
                    4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b11110;
                endcase
                7: case (row) // 4
                    0: font_row=5'b00010; 1: font_row=5'b00110;
                    2: font_row=5'b01010; 3: font_row=5'b10010;
                    4: font_row=5'b11111; 5: font_row=5'b00010;
                    6: font_row=5'b00010;
                endcase
                8: case (row) // 5
                    0: font_row=5'b11111; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b11110;
                    4: font_row=5'b00001; 5: font_row=5'b00001;
                    6: font_row=5'b11110;
                endcase
                9: case (row) // H
                    0,1,2,4,5,6: font_row=5'b10001;
                    3: font_row=5'b11111;
                endcase
                10: case (row) // I
                    0,6: font_row=5'b11111;
                    1,2,3,4,5: font_row=5'b00100;
                endcase
                11: case (row) // L
                    0,1,2,3,4,5: font_row=5'b10000;
                    6: font_row=5'b11111;
                endcase
                12: case (row) // M
                    0,5,6: font_row=5'b10001;
                    1: font_row=5'b11011;
                    2,3,4: font_row=5'b10101;
                endcase
                13: case (row) // O
                    0,6: font_row=5'b01110;
                    1,2,3,4,5: font_row=5'b10001;
                endcase
                14: case (row) // R
                    0,3: font_row=5'b11110;
                    1,2: font_row=5'b10001;
                    4: font_row=5'b10100;
                    5: font_row=5'b10010;
                    6: font_row=5'b10001;
                endcase
                15: case (row) // S
                    0: font_row=5'b01111;
                    1,2: font_row=5'b10000;
                    3: font_row=5'b01110;
                    4,5: font_row=5'b00001;
                    6: font_row=5'b11110;
                endcase
                default: font_row=5'b00000;
            endcase
        end
    endfunction

    // Live page card order: SOL LA SI HIGHDO / DO RE MI FA.
    // Only display positions change; PCF8574 key bits keep their original notes.
    function [3:0] live_glyph;
        input [2:0] card;
        input [2:0] ch;
        begin
            live_glyph=4'd0;
            case (card)
                0: case (ch) 0:live_glyph=15; 1:live_glyph=13; 2:live_glyph=11; endcase // SOL
                1: case (ch) 0:live_glyph=11; 1:live_glyph=5; endcase // LA
                2: case (ch) 0:live_glyph=15; 1:live_glyph=10; endcase // SI
                3: case (ch) // HIGHDO
                    0:live_glyph=9; 1:live_glyph=10; 2:live_glyph=4;
                    3:live_glyph=9; 4:live_glyph=1; 5:live_glyph=13;
                endcase
                4: case (ch) 0:live_glyph=1; 1:live_glyph=13; endcase // DO
                5: case (ch) 0:live_glyph=14; 1:live_glyph=2; endcase // RE
                6: case (ch) 0:live_glyph=12; 1:live_glyph=10; endcase // MI
                7: case (ch) 0:live_glyph=3; 1:live_glyph=5; endcase // FA
            endcase
        end
    endfunction

    reg in_card;
    reg [1:0] card_col;
    reg card_row;
    reg [6:0] local_x, local_y, glyph_x;
    reg [6:0] text_y;
    reg [2:0] live_key_bit, live_char;
    reg [6:0] char_x;
    reg live_active, guide_active;
    reg [4:0] glyph_bits;
    reg [15:0] rgb565;
    reg [3:0] card_id;
    always @* begin
        card_col=0; card_row=0; in_card=0;
        local_x=0; local_y=0; glyph_x=0; text_y=0;
        glyph_bits=0; card_id=0;
        live_key_bit=0; live_char=0; char_x=0; live_active=0; guide_active=0;
        rgb565=16'h0843; // navy background

        if (ax>=16 && ax<120) begin
            card_col=0; local_x=dx0[6:0]; in_card=1;
        end else if (ax>=132 && ax<236) begin
            card_col=1; local_x=dx1[6:0]; in_card=1;
        end else if (ax>=248 && ax<352) begin
            card_col=2; local_x=dx2[6:0]; in_card=1;
        end else if (ax>=364 && ax<468) begin
            card_col=3; local_x=dx3[6:0]; in_card=1;
        end
        if (ay>=24 && ay<124) begin
            card_row=0; local_y=dy0[6:0];
        end else if (ay>=148 && ay<248) begin
            card_row=1; local_y=dy1[6:0];
        end else in_card=0;

        card_id={1'b0,card_row,card_col};
        case (card_id)
            0: live_key_bit=3'd4; // SOL = G4, H5
            1: live_key_bit=3'd5; // LA = A4, H6
            2: live_key_bit=3'd6; // SI = B4, H7
            3: live_key_bit=3'd7; // HIGHDO = C5, H8
            4: live_key_bit=3'd0; // DO = C4, H1
            5: live_key_bit=3'd1; // RE = D4, H2
            6: live_key_bit=3'd2; // MI = E4, H3
            7: live_key_bit=3'd3; // FA = F4, H4
        endcase
        live_active=frame_keys[live_key_bit];
        guide_active=frame_score[live_key_bit];
        if (visible && in_card && (frame_mode==3'd1 || frame_mode==3'd5)) begin
            // Both performance pages keep all eight cards in the same order.
            // Follow status still uses the original score and HTTM bit masks.
            if (frame_mode==3'd5) begin
                if (guide_active && live_active) rgb565=16'h03E0;
                else if (guide_active) rgb565=16'hFE20;
                else if (live_active) rgb565=16'hA800;
                else rgb565=16'h1908;
            end else rgb565=live_active ? 16'h0192 : 16'h1908;
            if (local_x<3 || local_x>=101 || local_y<3 || local_y>=97)
                rgb565=(live_active || (frame_mode==3'd5 && guide_active)) ?
                    16'h6FFF : 16'h5294;

            // 4x font for short names; 2x for six-letter HIGHDO.
                if (card_id==3 && local_y>=43 && local_y<57 &&
                    local_x>=16 && local_x<88) begin
                    glyph_x=local_x-7'd16;
                    if (glyph_x<12) begin live_char=0; char_x=glyph_x; end
                    else if (glyph_x<24) begin live_char=1; char_x=glyph_x-7'd12; end
                    else if (glyph_x<36) begin live_char=2; char_x=glyph_x-7'd24; end
                    else if (glyph_x<48) begin live_char=3; char_x=glyph_x-7'd36; end
                    else if (glyph_x<60) begin live_char=4; char_x=glyph_x-7'd48; end
                    else begin live_char=5; char_x=glyph_x-7'd60; end
                    text_y=local_y-7'd43;
                    glyph_bits=font_row(live_glyph(card_id[2:0],live_char),text_y[3:1]);
                    if (char_x[3:1]<5 && glyph_bits[4-char_x[3:1]])
                        rgb565=(live_active || (frame_mode==3'd5 && guide_active)) ?
                            16'hFFFF : 16'hBDF7;
                end else if (card_id!=3 && local_y>=36 && local_y<64 &&
                    local_x>=((card_id==0) ? 7'd16 : 7'd28) &&
                    local_x<((card_id==0) ? 7'd88 : 7'd76)) begin
                    // SOL has three letters. SI is two letters as are the
                    // remaining labels; all are centered within 104 pixels.
                    glyph_x=local_x-((card_id==0) ? 7'd16 : 7'd28);
                    if (glyph_x<24) begin live_char=0; char_x=glyph_x; end
                    else if (glyph_x<48) begin live_char=1; char_x=glyph_x-7'd24; end
                    else begin live_char=2; char_x=glyph_x-7'd48; end
                    text_y=local_y-7'd36;
                    glyph_bits=font_row(live_glyph(card_id[2:0],live_char),text_y[4:2]);
                    if (char_x[4:2]<5 && glyph_bits[4-char_x[4:2]])
                        rgb565=(live_active || (frame_mode==3'd5 && guide_active)) ?
                            16'hFFFF : 16'hBDF7;
                end
        end
        if (frame_mode != 3'd1 && frame_mode != 3'd5) rgb565=menu_rgb;
        if (frame_mode == 3'd5 &&
            (ay<9'd22 || (ay>=9'd126 && ay<9'd148) || ay>=9'd250))
            rgb565=menu_rgb;
        if ((frame_mode==3'd1 || frame_mode==3'd5) &&
            ((ax>=10'd174 && ax<10'd312) ||
             (ax>=10'd308 && ax<10'd471)) &&
            ay>=9'd3 && ay<9'd23)
            rgb565=menu_rgb;
        if (frame_mode==3'd1 && ax<10'd174 && ay<9'd23)
            rgb565=menu_rgb;
        if (!visible) rgb565=16'h0000;
    end
    // Synchronous RAM needs one clock of read latency. Prefetch the next
    // raster coordinate instead of delaying the LCD's established DE timing.
    wire [9:0] next_x=(x==H_TOTAL-1) ? 10'd0 : x+10'd1;
    wire [8:0] next_y=(x==H_TOTAL-1) ?
        ((y==V_TOTAL-1) ? 9'd0 : y+9'd1) : y;
    wire next_visible=(next_x>=H_START && next_x<10'd510 &&
                       next_y>=V_START && next_y<9'd277);
    wire [9:0] next_ax=next_x-H_START;
    wire [8:0] next_ay=next_y-V_START;
    wire [16:0] cover_read_address=next_visible ?
        ({8'b0,next_ay}*17'd480 + {7'b0,next_ax}) : 17'd0;
    wire [15:0] cover_rgb;
    lcd_cover_ram cover_memory (
        .phone_address(phone_cover_address), .phone_index(phone_cover_index),
        .phone_palette_address(phone_palette_address), .phone_palette_color(phone_palette_color),
        .write_clk(cover_clk), .write_enable(cover_we),
        .write_address(cover_address), .write_pixel(cover_pixel),
        .palette_write_enable(cover_palette_we),
        .palette_write_address(cover_palette_address), .palette_write_pixel(cover_palette_pixel),
        .read_clk(clk9m), .read_address(cover_read_address), .read_pixel(cover_rgb)
    );
    // cover_ready crosses through two FFs and is latched at frame start.
    // Do not expose uninitialized frame RAM while loading or after an error.
    wire show_cover=visible && frame_mode==3'd7 && frame_cover;
    assign {lcd_r,lcd_g,lcd_b}=show_cover ? cover_rgb : rgb565;
endmodule
