// U4=0x38, U5=0x39 as confirmed by the actual board wiring.
module play_lcd_top #(parameter ENABLE_GUIDE_LEDS=1) (
    input wire clk24m,
    input wire clk9m,
    input wire btn_s1,
    input wire btn_s2,
    input wire uart_rx,
    output wire uart_tx,
    output wire sd_cs_n,
    output wire sd_sck,
    output wire sd_mosi,
    input wire sd_miso,
    inout wire i2c_scl,
    inout wire i2c_sda,
    output wire led_bus_n,
    output wire led_key_n,
    output wire pa_en,
    output wire i2s_bclk,
    output wire i2s_lrclk,
    output wire i2s_din,
    output wire lcd_clk,
    output wire lcd_de,
    output wire lcd_bl,
    output wire [4:0] lcd_r,
    output wire [5:0] lcd_g,
    output wire [4:0] lcd_b
);
    wire scl_low, sda_low, scl_in, sda_in;
    wire [7:0] notes;
    wire [2:0] ui_mode, song_selection;
    wire [1:0] menu_selection;
    wire scan_start,song_start,player_abort;
    wire [3:0] song_count,sd_error;
    wire [511:0] song_names;
    wire catalog_ready,sd_busy,sd_playing,score_ready,score_done;
    wire [7:0] score_mask;
    wire [7:0] score_step_10ms;
    wire signed [15:0] song_pcm;
    wire sample_tick,sd_underrun,led_ack;
    wire [7:0] volume_level;
    wire fsr_up;
    wire [7:0] fsr_bend_display;
    wire [1:0] timbre_a, timbre_b, voice_mode;
    wire [1:0] effect_mode;
    wire [1:0] vibrato_depth;
    wire metronome;
    wire [8:0] beat_phase_ms;
    wire [1:0] timing_hint;
    wire [6:0] final_percent;
    wire result_valid;
    wire [7:0] latency_tenth_ms;
    wire latency_valid;
    reg score_advance=0, score_released=0;
    reg [18:0] power_on=0;
    always @(posedge clk24m) if (!power_on[18]) power_on<=power_on+1'b1;
    wire cover_ready, cover_we, cover_palette_we;
    wire [16:0] cover_address;
    wire [3:0] cover_pixel, cover_palette_address;
    wire [15:0] cover_palette_pixel;
    reg boot_started=0, cover_start=0;
    always @(posedge clk24m) begin
        cover_start<=0;
        if (power_on[18] && !boot_started) begin
            boot_started<=1;
            if (ui_mode==3'd7 && !player_abort) cover_start<=1;
        end
    end
    wire upload_mode = ui_mode==3'd6;
    wire card_reset = !power_on[18] || player_abort || upload_mode;
    wire play_sd_cs, play_sd_clk, play_sd_mosi;
    wire upload_sd_cs, upload_sd_clk, upload_sd_mosi;
    wire upload_locked;
    wire phone_valid;
    wire [3:0] phone_action;
    wire [2:0] phone_value;
    wire [7:0] phone_keys, phone_volume, phone_bend;
    wire [1:0] phone_settings;
    wire knob_takeover;
    wire snapshot_request, snapshot_ack;
    wire [767:0] snapshot_data;
    wire [16:0] phone_cover_address;
    wire [3:0] phone_cover_index, phone_palette_address;
    wire [15:0] phone_palette_color;
    assign sd_cs_n = upload_mode ? upload_sd_cs : play_sd_cs;
    assign sd_sck = upload_mode ? upload_sd_clk : play_sd_clk;
    assign sd_mosi = upload_mode ? upload_sd_mosi : play_sd_mosi;
    phone_control_bridge phone (
        .clk24m(clk24m), .reset(!power_on[18]), .upload_mode(upload_mode),
        .knob_takeover(knob_takeover),
        .ui_mode(ui_mode), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .session_locked(upload_locked),
        .timbre_a(timbre_a), .timbre_b(timbre_b), .voice_mode(voice_mode),
        .effect_mode(effect_mode), .metronome(metronome),
        .vibrato_depth(vibrato_depth),
        .remote_valid(phone_valid), .remote_action(phone_action), .remote_value(phone_value),
        .remote_keys(phone_keys), .remote_settings(phone_settings),
        .remote_volume(phone_volume), .remote_bend(phone_bend),
        .snapshot_request(snapshot_request), .snapshot_ack(snapshot_ack), .snapshot_data(snapshot_data),
        .cover_ready(cover_ready), .cover_address(phone_cover_address), .cover_index(phone_cover_index),
        .palette_address(phone_palette_address), .palette_color(phone_palette_color),
        .sd_cs_n(upload_sd_cs), .sd_sck(upload_sd_clk),
        .sd_mosi(upload_sd_mosi), .sd_miso(sd_miso)
    );
    lcd_menu_keys controls (
        .remote_valid(phone_valid), .remote_action(phone_action), .remote_value(phone_value),
        .clk24m(clk24m), .btn_s1(btn_s1), .btn_s2(btn_s2),
        .song_count(song_count), .catalog_ready(catalog_ready),
        .sd_busy(sd_busy), .score_done(score_done), .upload_locked(upload_locked),
        .key_state(notes),
        .ui_mode(ui_mode), .menu_selection(menu_selection),
        .song_selection(song_selection),
        .scan_start(scan_start), .song_start(song_start),
        .player_reset(player_abort)
    );
    sd_wav_player music (
        .clk24m(clk24m), .reset(card_reset),
        .scan_start(scan_start), .start(song_start),
        .cover_start(cover_start), .cover_ready(cover_ready),
        .cover_we(cover_we), .cover_address(cover_address), .cover_pixel(cover_pixel),
        .cover_palette_we(cover_palette_we),
        .cover_palette_address(cover_palette_address), .cover_palette_pixel(cover_palette_pixel),
        .selected_index(song_selection), .guided(ui_mode==3'd5),
        .scan_guided(ui_mode==3'd3),
        .score_advance(score_advance), .sample_tick(sample_tick),
        .busy(sd_busy), .playing(sd_playing), .pcm_sample(song_pcm),
        .catalog_ready(catalog_ready), .song_count(song_count),
        .song_names(song_names), .score_ready(score_ready),
        .score_done(score_done), .score_mask(score_mask),
        .score_step_10ms(score_step_10ms),
        .error_code(sd_error), .underrun(sd_underrun),
        .sd_cs_n(play_sd_cs), .sd_sck(play_sd_clk),
        .sd_mosi(play_sd_mosi), .sd_miso(sd_miso)
    );
    always @(posedge clk24m) begin
        score_advance<=0;
        if (ui_mode!=3'd5 || !score_ready) score_released<=0;
        else if (notes==0) score_released<=1;
        else if (score_released && !score_done && score_mask!=0 && notes==score_mask) begin
            score_advance<=1;
            score_released<=0;
        end
    end
    follow_rhythm_score rhythm (
        .clk24m(clk24m), .sample_tick(sample_tick),
        .guided_mode(ui_mode==3'd5), .song_start(song_start),
        .score_ready(score_ready), .score_done(score_done),
        .score_advance(score_advance), .keys(notes),
        .score_step_10ms(score_step_10ms),
        .beat_phase_ms(beat_phase_ms), .timing_hint(timing_hint),
        .final_percent(final_percent), .result_valid(result_valid)
    );
    IOBUF scl_pad (.I(1'b0), .OEN(~scl_low), .IO(i2c_scl), .O(scl_in));
    IOBUF sda_pad (.I(1'b0), .OEN(~sda_low), .IO(i2c_sda), .O(sda_in));

    play_core #(.AUDIO_SELFTEST(0), .LED_EXPANDER_PRESENT(ENABLE_GUIDE_LEDS),
        .ADC_PRESENT(1), .REMOTE_CONTROL(1)) instrument (
        .clk24m(clk24m),
        .remote_keys(phone_keys), .remote_settings(phone_settings),
        .remote_volume(phone_volume), .remote_bend(phone_bend),
        .play_enable(ui_mode == 3'd1 || ui_mode == 3'd4 || ui_mode == 3'd5),
        .pcm_sample(song_pcm), .pcm_active(ui_mode==3'd4 && sd_playing),
        .timbre_a(timbre_a), .timbre_b(timbre_b), .voice_mode(voice_mode),
        .effect_mode(effect_mode), .metronome(metronome),
        .vibrato_depth(vibrato_depth),
        .guide_leds((ui_mode==3'd5 && score_ready && !score_done) ? score_mask : 8'h00),
        .sample_tick(sample_tick), .led_ack(led_ack),
        .scl_low(scl_low), .sda_low(sda_low), .sda_in(sda_in),
        .key_state(notes),
        .volume_display(volume_level),
        .knob_takeover(knob_takeover),
        .fsr_active(fsr_up),
        .fsr_bend_display(fsr_bend_display),
        .latency_tenth_ms(latency_tenth_ms), .latency_valid(latency_valid),
        .led_bus_n(led_bus_n), .led_key_n(led_key_n),
        .pa_en(pa_en),
        .i2s_bclk(i2s_bclk), .i2s_lrclk(i2s_lrclk), .i2s_din(i2s_din)
    );

    lcd_notes_480x272 display (
        .snapshot_request(snapshot_request), .snapshot_ack(snapshot_ack), .snapshot_data(snapshot_data),
        .phone_cover_address(phone_cover_address), .phone_cover_index(phone_cover_index),
        .phone_palette_address(phone_palette_address), .phone_palette_color(phone_palette_color),
        .clk9m(clk9m), .keys_async(notes),
        .cover_clk(clk24m), .cover_we(cover_we),
        .cover_address(cover_address), .cover_pixel(cover_pixel),
        .cover_palette_we(cover_palette_we),
        .cover_palette_address(cover_palette_address), .cover_palette_pixel(cover_palette_pixel),
        .cover_ready_async(cover_ready),
        .volume_async(volume_level),
        .phone_volume_owner_async(phone_settings[0]),
        .fsr_async(fsr_up),
        .fsr_bend_async(fsr_bend_display),
        .timbre_a_async(timbre_a), .timbre_b_async(timbre_b),
        .voice_mode_async(voice_mode),
        .effect_mode_async(effect_mode), .metronome_async(metronome),
        .vibrato_depth_async(vibrato_depth),
        .ui_mode_async(ui_mode), .selection_async(menu_selection),
        .song_selection_async(song_selection), .song_count_async(song_count),
        .song_names_async(song_names), .catalog_ready_async(catalog_ready),
        .sd_busy_async(sd_busy), .sd_playing_async(sd_playing),
        .sd_error_async(sd_error), .score_mask_async(score_mask),
        .score_ready_async(score_ready), .score_done_async(score_done),
        .beat_phase_async(beat_phase_ms), .timing_hint_async(timing_hint),
        .final_percent_async(final_percent), .result_valid_async(result_valid),
        .latency_tenth_async(latency_tenth_ms), .latency_valid_async(latency_valid),
        .lcd_clk(lcd_clk), .lcd_de(lcd_de), .lcd_bl(lcd_bl),
        .lcd_r(lcd_r), .lcd_g(lcd_g), .lcd_b(lcd_b)
    );
endmodule
