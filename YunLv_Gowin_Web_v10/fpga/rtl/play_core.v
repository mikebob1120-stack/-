// Tang Nano 20K, MS5351 CLK1=24.576 MHz, 8 keys, mono I2S at 32 kHz.
module play_core #(parameter AUDIO_SELFTEST = 0, parameter LED_EXPANDER_PRESENT=0,
    parameter ADC_PRESENT=0, parameter REMOTE_CONTROL=0) (
    input wire clk24m,
    input wire play_enable,
    input wire [7:0] remote_keys,
    input wire [1:0] remote_settings,
    input wire [7:0] remote_volume, remote_bend,
    input wire signed [15:0] pcm_sample,
    input wire pcm_active,
    input wire [1:0] timbre_a,
    input wire [1:0] timbre_b,
    input wire [1:0] voice_mode,
    input wire [1:0] effect_mode,
    input wire [1:0] vibrato_depth,
    input wire metronome,
    input wire [7:0] guide_leds,
    output wire led_ack,
    output wire sample_tick,
    output wire scl_low,
    output wire sda_low,
    input wire sda_in,
    output wire [7:0] key_state,
    output wire [7:0] volume_display,
    output reg knob_takeover=0,
    output wire fsr_active,
    output wire [7:0] fsr_bend_display,
    output reg [7:0] latency_tenth_ms=0,
    output reg latency_valid=0,
    output wire led_bus_n,
    output wire led_key_n,
    output wire pa_en,
    output reg i2s_bclk = 0,
    output reg i2s_lrclk = 1,
    output reg i2s_din = 0
);
    reg [18:0] power_on = 0;
    always @(posedge clk24m) if (!power_on[18]) power_on <= power_on + 1'b1;
    wire reset = !power_on[18]; // ~10.7 ms after FPGA configuration

    wire [7:0] keys_raw;
    wire [7:0] volume_level, adc_volume;
    wire fsr_pressed;
    wire [7:0] fsr_bend, adc_bend;
    // The web volume takes over when it changes. A deliberate turn of the
    // physical knob takes it back without requiring a browser button click.
    // 8/255 hysteresis rejects a small ADC wobble; 10 ms rejects spikes.
    reg [7:0] volume_pickup_base=8'd255;
    reg [7:0] last_remote_volume=8'd255;
    reg remote_volume_was_enabled=0;
    reg knob_has_priority=0;
    reg [17:0] knob_move_cycles=0;
    wire [7:0] knob_distance=(adc_volume>=volume_pickup_base) ?
        adc_volume-volume_pickup_base : volume_pickup_base-adc_volume;
    always @(posedge clk24m) begin
        knob_takeover<=0;
        if (reset) begin
            volume_pickup_base<=8'd255;
            last_remote_volume<=8'd255;
            remote_volume_was_enabled<=0;
            knob_has_priority<=0;
            knob_move_cycles<=0;
        end else begin
            remote_volume_was_enabled<=REMOTE_CONTROL && remote_settings[0];
            last_remote_volume<=remote_volume;
            if (!REMOTE_CONTROL || !remote_settings[0]) begin
                volume_pickup_base<=adc_volume;
                knob_has_priority<=0;
                knob_move_cycles<=0;
            end else if (!remote_volume_was_enabled || remote_volume!=last_remote_volume) begin
                volume_pickup_base<=adc_volume;
                knob_has_priority<=0;
                knob_move_cycles<=0;
            end else if (!knob_has_priority) begin
                if (knob_distance>=8'd8) begin
                    if (knob_move_cycles==18'd245759) begin
                        knob_has_priority<=1;
                        knob_takeover<=1;
                        knob_move_cycles<=0;
                    end else knob_move_cycles<=knob_move_cycles+1'b1;
                end else knob_move_cycles<=0;
            end
        end
    end
    assign volume_level=(REMOTE_CONTROL && remote_settings[0] && !knob_has_priority) ?
        remote_volume : adc_volume;
    assign fsr_bend=(REMOTE_CONTROL && remote_settings[1]) ? remote_bend : adc_bend;
    assign volume_display = volume_level;
    assign fsr_active = (fsr_bend!=8'd0);
    assign fsr_bend_display = fsr_bend;
    wire sample_valid;
    pcf8574_keys #(.LED_EXPANDER_PRESENT(LED_EXPANDER_PRESENT),
        .ADC_PRESENT(ADC_PRESENT)) key_reader (
        .clk24m(clk24m), .reset(reset),
        .guide_leds(guide_leds), .led_ack(led_ack),
        .scl_low(scl_low), .sda_low(sda_low), .sda_in(sda_in),
        .keys(keys_raw), .seen(), .sample_valid(sample_valid),
        .volume_level(adc_volume),
        .fsr_pressed(fsr_pressed), .fsr_bend(adc_bend),
        .write_address_ack(), .write_data_ack(), .read_address_ack()
    );

    // Two matching PCF8574A snapshots remove isolated glitches. The old
    // four-poll wait could push touch-to-audio beyond the latency goal.
    reg [7:0] last_raw = 0, keys = 0;
    assign key_state = keys | (REMOTE_CONTROL ? remote_keys : 8'h00);
    reg [1:0] stable_count = 0;
    reg [21:0] no_read_cycles = 0;
    reg bus_live = 0;
    always @(posedge clk24m) begin
        if (reset) begin no_read_cycles<=0; bus_live<=0; end
        else if (sample_valid) begin no_read_cycles<=0; bus_live<=1; end
        else if (no_read_cycles==22'd2457600) bus_live<=0;
        else no_read_cycles<=no_read_cycles+1'b1;
    end
    always @(posedge clk24m) begin
        if (reset || !bus_live) begin last_raw<=0; keys<=0; stable_count<=0; end
        else if (sample_valid && keys_raw != last_raw) begin
            last_raw <= keys_raw;
            stable_count <= 0;
        end else if (sample_valid && stable_count != 1) begin
            stable_count <= stable_count + 1'b1;
            if (stable_count == 0) keys <= last_raw;
        end
    end
    reg [23:0] heartbeat = 0;
    always @(posedge clk24m) heartbeat <= heartbeat + 1'b1;
    // LED0 blinks if the clock works but no recent I2C read, stays on when
    // samples arrive within 100 ms. Self-test always blinks.
    assign led_bus_n = AUDIO_SELFTEST ? heartbeat[23] : (bus_live ? 1'b0 : heartbeat[23]);
    assign led_key_n = AUDIO_SELFTEST ? 1'b0 : ~(|key_state);
    assign pa_en = 1'b1;           // MAX98357A SD_MODE high: enable
    wire [7:0] play_keys = AUDIO_SELFTEST ? 8'h20 : (play_enable ? key_state : 8'h00); // A4 self-test

    // Fs = 24.576 MHz / (12 * 64) = 32000 Hz. 24-bit DDS increments for
    // C4, D4, E4, F4, G4, A4, B4, C5 respectively.
    function [23:0] increment;
        input integer n;
        begin
            case (n)
                0: increment=24'd137167;
                1: increment=24'd153965;
                2: increment=24'd172820;
                3: increment=24'd183096;
                4: increment=24'd205519;
                5: increment=24'd230687;
                6: increment=24'd258937;
                7: increment=24'd274334;
                default: increment=0;
            endcase
        end
    endfunction

    // Full pressure is one whole tone (+2 semitones); zero pressure is exact
    // original pitch. Intermediate pressures interpolate the DDS increment.
    function [23:0] raised_increment;
        input integer n;
        begin
            case (n)
                0: raised_increment=24'd153965; // D4
                1: raised_increment=24'd172820; // E4
                2: raised_increment=24'd193984; // F#4
                3: raised_increment=24'd205519; // G4
                4: raised_increment=24'd230687; // A4
                5: raised_increment=24'd258937; // B4
                6: raised_increment=24'd290647; // C#5
                7: raised_increment=24'd307930; // D5
                default: raised_increment=0;
            endcase
        end
    endfunction

    // 32-point signed sine table. Phase and envelope remain common to the
    // existing eight notes; changing timbre never resets a sounding note.
    function signed [8:0] sine_sample;
        input [4:0] index;
        begin
            case (index)
                0,16: sine_sample=9'sd0;
                1,15: sine_sample=9'sd25;
                2,14: sine_sample=9'sd49;
                3,13: sine_sample=9'sd71;
                4,12: sine_sample=9'sd90;
                5,11: sine_sample=9'sd106;
                6,10: sine_sample=9'sd117;
                7,9: sine_sample=9'sd125;
                8: sine_sample=9'sd127;
                17,31: sine_sample=-9'sd25;
                18,30: sine_sample=-9'sd49;
                19,29: sine_sample=-9'sd71;
                20,28: sine_sample=-9'sd90;
                21,27: sine_sample=-9'sd106;
                22,26: sine_sample=-9'sd117;
                23,25: sine_sample=-9'sd125;
                24: sine_sample=-9'sd127;
                default: sine_sample=9'sd0;
            endcase
        end
    endfunction

    function signed [8:0] waveform;
        input [1:0] timbre;
        input [23:0] wave_phase;
        reg signed [8:0] original_triangle;
        begin
            // This expression is identical to the verified triangle voice.
            original_triangle =
                $signed({1'b0, wave_phase[23] ? ~wave_phase[22:15] : wave_phase[22:15]}) - 9'sd128;
            case (timbre)
                2'd1: waveform=sine_sample(wave_phase[23:19]);
                2'd2: waveform=wave_phase[23] ? -9'sd80 : 9'sd80;
                default: waveform=original_triangle;
            endcase
        end
    endfunction

    reg [23:0] phase [0:7];
    reg [4:0] envelope [0:7];
    // A ~8 ms, D ~16 ms, S 27/31, R ~20 ms from sustain.
    // A short release also prevents successive notes from masking each other.
    localparam [2:0] ENV_IDLE=0, ENV_ATTACK=1, ENV_DECAY=2,
                     ENV_SUSTAIN=3, ENV_RELEASE=4;
    reg [2:0] env_state [0:7];
    reg [6:0] env_timer [0:7];
    // 32 kHz / 8192 = 3.906 Hz triangle LFO, approximately +/-0.8% pitch.
    reg [12:0] vibrato_phase=0;
    wire [5:0] vibrato_triangle = vibrato_phase[12] ?
        ~vibrato_phase[11:6] : vibrato_phase[11:6];
    wire signed [7:0] vibrato_value =
        $signed({2'b00,vibrato_triangle}) - 8'sd32;
    reg [23:0] base_increment;
    reg [31:0] bend_product;
    reg signed [20:0] vibrato_delta;
    reg signed [24:0] depth_delta;
    reg signed [24:0] adjusted_increment;
    // 4096 samples at 32 kHz = 128 ms. Separate read/write addresses
    // avoid read-during-write ambiguity in inferred FPGA block RAM.
    reg signed [15:0] delay_line [0:4095];
    reg [11:0] delay_head=0;
    wire [11:0] delay_next=delay_head+12'd1;
    reg signed [15:0] delay_tap=0;
    reg delay_valid=0, delay_read_valid=0;
    reg [13:0] beat_counter=0;
    reg [6:0] click_left=0;
    reg [2:0] bclk_div = 0;
    reg [5:0] slot = 0;
    reg signed [19:0] sum;
    reg signed [19:0] scaled_mix;
    reg [7:0] sum_envelopes;
    reg [10:0] gain_target;
    reg [10:0] gain_q=11'd1024; // Q8: x4, glides over ~4 ms
    reg signed [31:0] gain_product;
    reg signed [31:0] gain_output;
    reg signed [9:0] selected_wave;
    reg signed [18:0] voice;
    reg signed [15:0] audio_sample = 0;
    reg signed [16:0] mixed_with_pcm;
    reg signed [15:0] selected_mix;
    reg signed [16:0] echo_sum, beat_sum;
    reg signed [15:0] effect_sample, final_sample;
    reg signed [24:0] volume_product;
    reg [7:0] latency_frames=0, latency_keys_previous=0;
    reg latency_wait=0;
    wire [10:0] latency_tenths = (({3'b0,latency_frames} * 11'd5) + 11'd8) >> 4;
    integer i, j;
    assign sample_tick = !reset && bclk_div==5 && i2s_bclk && slot==0;

    // Produce a new sample at the start of each stereo I2S frame.
    // Each key has its own phase and full four-stage envelope.
    always @* begin
        sum = 0;
        sum_envelopes = 0;
        selected_wave = 0;
        voice = 0;
        for (j=0; j<8; j=j+1) begin
            if (voice_mode==2'd2)
                selected_wave = ($signed(waveform(timbre_a,phase[j])) +
                                 $signed(waveform(timbre_b,phase[j]))) >>> 1;
            else if (voice_mode==2'd1 && j>=4)
                selected_wave = waveform(timbre_b,phase[j]);
            else selected_wave = waveform(timbre_a,phase[j]);
            voice = selected_wave * $signed({1'b0,envelope[j]});
            sum = sum + voice;
            sum_envelopes = sum_envelopes + {3'd0,envelope[j]};
        end
        // Releasing notes have fractional weight instead of counting as a
        // full extra key. Smooth gain before changing polyphony headroom.
        if (sum_envelopes <= 8'd31) gain_target=11'd1024;
        else if (sum_envelopes <= 8'd50) gain_target=11'd768;
        else if (sum_envelopes <= 8'd70) gain_target=11'd512;
        else if (sum_envelopes <= 8'd100) gain_target=11'd384;
        else gain_target=11'd256;
        gain_product = sum * $signed({1'b0,gain_q});
        gain_output = gain_product >>> 8;
        if (gain_output > 32'sd32767) scaled_mix=20'sd32767;
        else if (gain_output < -32'sd32768) scaled_mix=-20'sd32768;
        else scaled_mix=gain_output[19:0];
        mixed_with_pcm = ($signed({pcm_sample[15],pcm_sample}) +
                          $signed({scaled_mix[15],scaled_mix[15:0]})) >>> 1;
        selected_mix = pcm_active ? mixed_with_pcm[15:0] : scaled_mix[15:0];
        // Reserve headroom for the echo: 7/8 dry + 1/8 delayed feedback.
        // Simply adding the delayed signal used to clip on repeated notes.
        echo_sum = $signed({selected_mix[15],selected_mix});
        if (effect_mode==2'd2 && play_enable) begin
            echo_sum = echo_sum - (echo_sum >>> 3);
            if (delay_read_valid)
                echo_sum = echo_sum + ($signed({delay_tap[15],delay_tap}) >>> 3);
        end
        if (echo_sum>17'sd32767) effect_sample=16'sh7fff;
        else if (echo_sum< -17'sd32768) effect_sample=16'sh8000;
        else effect_sample=echo_sum[15:0];
        beat_sum = $signed({effect_sample[15],effect_sample});
        if (metronome && play_enable && click_left!=0)
            beat_sum=beat_sum + (click_left[4] ? 17'sd2048 : -17'sd2048);
        if (beat_sum>17'sd32767) final_sample=16'sh7fff;
        else if (beat_sum< -17'sd32768) final_sample=16'sh8000;
        else final_sample=beat_sum[15:0];
        volume_product = final_sample * $signed({1'b0,volume_level});
    end

    always @(posedge clk24m) begin
        if (reset) begin
            bclk_div<=0;
            slot<=0;
            i2s_bclk<=0;
            i2s_lrclk<=1;
            i2s_din<=0;
            audio_sample<=0;
            gain_q<=11'd1024;
            latency_frames<=0; latency_keys_previous<=0;
            latency_wait<=0; latency_valid<=0; latency_tenth_ms<=0;
            vibrato_phase<=0;
            delay_head<=0; delay_tap<=0;
            delay_valid<=0; delay_read_valid<=0;
            beat_counter<=0; click_left<=0;
            for (i=0;i<8;i=i+1) begin
                phase[i]<=0; envelope[i]<=0;
                env_state[i]<=ENV_IDLE; env_timer[i]<=0;
            end
        end else if (bclk_div==5) begin
            bclk_div<=0;
            i2s_bclk<=~i2s_bclk;
            if (i2s_bclk) begin // falling edge: change data before next rising edge
                slot <= slot + 1'b1;
                if (slot==0) begin
                    i2s_lrclk <= 0;
                    // A signed 16-bit sample times 0..255, divided by 256,
                    // still fits 16 bits. Explicit slice avoids width truncation.
                    audio_sample <= volume_product[23:8];
                    if (latency_wait && latency_frames!=8'hff)
                        latency_frames<=latency_frames+1'b1;
                    if (gain_q < gain_target)
                        gain_q <= gain_q + ((gain_target-gain_q) >> 7) + 11'd1;
                    else if (gain_q > gain_target)
                        gain_q <= gain_q - ((gain_q-gain_target) >> 7) - 11'd1;
                    if (effect_mode==2'd1 && play_enable)
                        vibrato_phase<=vibrato_phase+1'b1;
                    else vibrato_phase<=0;
                    if (effect_mode==2'd2 && play_enable) begin
                        delay_line[delay_head]<=effect_sample;
                        delay_tap<=delay_line[delay_next];
                        delay_read_valid<=delay_valid;
                        delay_head<=delay_next;
                        if (delay_head==12'd4095) delay_valid<=1;
                    end else begin
                        delay_head<=0; delay_tap<=0;
                        delay_valid<=0; delay_read_valid<=0;
                    end
                    if (metronome && play_enable) begin
                        if (beat_counter==14'd15999) begin
                            beat_counter<=0; click_left<=7'd127;
                        end else begin
                            beat_counter<=beat_counter+1'b1;
                            if (click_left!=0) click_left<=click_left-1'b1;
                        end
                    end else begin beat_counter<=0; click_left<=0; end
                    for (i=0;i<8;i=i+1) begin
                        bend_product=(raised_increment(i)-increment(i))*fsr_bend;
                        base_increment=(fsr_bend==8'd255) ? raised_increment(i) :
                                       increment(i)+bend_product[31:8];
                        vibrato_delta=$signed({1'b0,base_increment[23:12]}) *
                                       $signed(vibrato_value);
                        // Four easily distinguishable levels: off, original
                        // +/-0.8%, 2x and 4x. Shifts consume no extra DSP.
                        case(vibrato_depth)
                            2'd0: depth_delta=0;
                            2'd1: depth_delta=$signed(vibrato_delta);
                            2'd2: depth_delta=$signed(vibrato_delta) <<< 1;
                            default: depth_delta=$signed(vibrato_delta) <<< 2;
                        endcase
                        adjusted_increment=$signed({1'b0,base_increment}) + depth_delta;
                        phase[i]<=phase[i] +
                                  ((effect_mode==2'd1) ?
                                   adjusted_increment[23:0] : base_increment);
                        if (play_keys[i]) begin
                            case (env_state[i])
                                ENV_IDLE,ENV_RELEASE: begin
                                    env_state[i]<=ENV_ATTACK; env_timer[i]<=0;
                                end
                                ENV_ATTACK: if (env_timer[i]==7'd7) begin
                                    env_timer[i]<=0;
                                    envelope[i]<=envelope[i]+1'b1;
                                    if (envelope[i]==5'd30) env_state[i]<=ENV_DECAY;
                                end else env_timer[i]<=env_timer[i]+1'b1;
                                ENV_DECAY: if (env_timer[i]==7'd127) begin
                                    env_timer[i]<=0;
                                    envelope[i]<=envelope[i]-1'b1;
                                    if (envelope[i]==5'd28) env_state[i]<=ENV_SUSTAIN;
                                end else env_timer[i]<=env_timer[i]+1'b1;
                                ENV_SUSTAIN: begin
                                    envelope[i]<=5'd27; env_timer[i]<=0;
                                end
                                default: begin
                                    env_state[i]<=ENV_ATTACK; env_timer[i]<=0;
                                end
                            endcase
                        end else if (env_state[i]!=ENV_IDLE) begin
                            if (env_state[i]!=ENV_RELEASE) begin
                                env_state[i]<=ENV_RELEASE; env_timer[i]<=0;
                            end else if (env_timer[i]==7'd23) begin
                                env_timer[i]<=0;
                                if (envelope[i]<=5'd1) begin
                                    envelope[i]<=0; env_state[i]<=ENV_IDLE;
                                end else envelope[i]<=envelope[i]-1'b1;
                            end else env_timer[i]<=env_timer[i]+1'b1;
                        end
                    end
                end
                if (slot==32) i2s_lrclk <= 1;
                // First nonzero I2S word for an isolated key. The timing
                // starts after I2C polling/debouncing; it is a *digital
                // pipeline* measurement, not physical touch latency.
                if (slot==1 && latency_wait && audio_sample!=0) begin
                    latency_tenth_ms<=latency_tenths[7:0];
                    latency_valid<=1;
                    latency_wait<=0;
                end
                if (slot>=1 && slot<=16) i2s_din <= audio_sample[16-slot];
                else if (slot>=33 && slot<=48) i2s_din <= audio_sample[48-slot];
                else i2s_din <= 0;
            end
        end else bclk_div<=bclk_div+1'b1;
        if (!reset) begin
            latency_keys_previous<=key_state;
            if (play_enable && !pcm_active && !metronome &&
                effect_mode!=2'd2 && volume_level!=0 && !latency_wait &&
                latency_keys_previous==0 && key_state!=0 && sum_envelopes==0) begin
                latency_wait<=1;
                latency_frames<=0;
            end
            if (!play_enable || latency_frames==8'hff) latency_wait<=0;
        end
    end
endmodule
