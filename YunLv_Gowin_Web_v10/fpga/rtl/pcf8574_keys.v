// Read eight active-high HTTM outputs from PCF8574A at 7-bit address 0x38.
// SCL is about 99 kHz from a 24.576 MHz clock. Open-drain outputs need the
// existing pull-ups on the FPGA side of TCA9802. No clock stretching.
module pcf8574_keys #(parameter LED_EXPANDER_PRESENT=0, ADC_PRESENT=0) (
    input wire clk24m,
    input wire reset,
    input wire [7:0] guide_leds,
    output reg led_ack = 0,
    output reg scl_low = 1'b0,
    output reg sda_low = 1'b0,
    input wire sda_in,
    output reg [7:0] keys = 8'h00,
    output reg seen = 1'b0,
    output reg sample_valid = 1'b0,
    output reg write_address_ack = 1'b0,
    output reg write_data_ack = 1'b0,
    output reg read_address_ack = 1'b0,
    output reg [7:0] volume_level = 8'd255,
    output reg fsr_pressed = 1'b0,
    output reg [7:0] fsr_bend = 8'd0
);
    localparam IDLE=0, START0=1, START1=2, START2=3,
        TX_SETUP=4, TX_RISE=5, TX_HOLD=6, TX_FALL=7,
        ACK_SETUP=8, ACK_RISE=9, ACK_HOLD=10, ACK_FALL=11,
        RX_SETUP=12, RX_RISE=13, RX_HOLD=14, RX_FALL=15,
        NACK_SETUP=16, NACK_RISE=17, NACK_HOLD=18, NACK_FALL=19,
        STOP0=20, STOP1=21, STOP2=22,
        START1_HOLD=23, STOP1_HOLD=24;

    reg [4:0] state = IDLE;
    reg [6:0] divider = 0;
    reg [15:0] pause_count = 0;
    reg [3:0] stage = 0;  // 0..4: keys/LEDs; 5..12: ADS1115
    reg initialized = 0;
    reg [7:0] tx_byte = 0, rx_byte = 0;
    reg [2:0] bit_index = 7;
    reg ack_error = 0;
    reg write_led_next = 0;
    reg [7:0] last_led_data = 8'hff;
    // Alternate ADS1115 AIN1 (volume pot) and AIN0 (FSR + 10k pulldown).
    // +/-4.096 V PGA: 8000 codes/V. 0.5 V press, 0.25 V release.
    // Three consecutive conversions must agree; a noisy idle voltage cannot
    // alter the DDS increment until a real press crosses the high threshold.
    localparam [15:0] FSR_PRESS_CODE = 16'd4000;
    localparam [15:0] FSR_RELEASE_CODE = 16'd2000;
    reg adc_channel = 0; // 0=AIN1 volume, 1=AIN0 FSR
    reg [1:0] fsr_count = 0;
    reg [1:0] adc_phase = 0; // 0=config, 2=wait, 3=read pointer set
    reg [15:0] adc_wait = 0;
    reg [7:0] adc_high = 0;
    reg adc_turn = 0;
    wire [15:0] adc_raw = {adc_high,rx_byte};
    // 0.5 V is the quiet dead band. The remaining ~2.04 V spans 0..255.
    // A non-pressed FSR must not change any DDS increment.
    wire [15:0] fsr_above_zero = adc_raw > FSR_PRESS_CODE ?
        adc_raw - FSR_PRESS_CODE : 16'd0;
    wire [7:0] fsr_target = adc_raw[15] || adc_raw<=FSR_PRESS_CODE ? 8'd0 :
        fsr_above_zero>=16'd16320 ? 8'd255 : fsr_above_zero[13:6];
    // ADS1115 PGA +/-4.096 V: 3.3 V input is about 26400 counts.
    wire [18:0] adc_scaled = {3'b0,adc_raw} * 3'd5;
    wire [9:0] adc_10 = adc_scaled[18:9];
    wire [7:0] adc_level = adc_raw[15] || adc_10>10'd255 ? 8'hff : adc_10[7:0];
    wire [7:0] desired_led_data = ~guide_leds; // PCF8574 outputs sink LED current.

    always @(posedge clk24m) begin
        sample_valid <= 0;
        if (adc_wait!=0) adc_wait<=adc_wait-1'b1;
        if (reset) begin
            divider <= 0;
            pause_count <= 0;
            state <= IDLE;
            stage <= 0;
            initialized <= 0;
            scl_low <= 0;
            sda_low <= 0;
            keys <= 0;
            seen <= 0;
            sample_valid <= 0;
            ack_error <= 0;
            write_address_ack <= 0;
            write_data_ack <= 0;
            read_address_ack <= 0;
            led_ack <= 0;
            write_led_next <= 0;
            last_led_data <= 8'hff;
            volume_level<=8'd255;
            fsr_pressed<=0; fsr_bend<=0; fsr_count<=0; adc_channel<=0;
            adc_phase<=0; adc_wait<=0; adc_high<=0;
            adc_turn<=0;
        end else if (state == IDLE) begin
            scl_low <= 0;
            sda_low <= 0;
            divider <= 0;
            if (LED_EXPANDER_PRESENT && initialized && write_led_next &&
                desired_led_data != last_led_data) begin
                write_led_next <= 0;
                pause_count <= 0;
                stage <= 3; tx_byte <= 8'h72; bit_index <= 7;
                ack_error <= 0; state <= START0;
            end else if (!initialized || (pause_count>=16'd24576 &&
                         (!ADC_PRESENT || adc_phase!=0 || !adc_turn))) begin
                pause_count<=0;
                write_led_next<=0;
                stage<=initialized ? 2 : 0;
                tx_byte<=initialized ? 8'h71 : 8'h70;
                bit_index<=7;
                ack_error<=0; state<=START0;
            end else if (ADC_PRESENT && initialized && adc_phase==0 && adc_turn) begin
                pause_count<=0;
                stage<=5; tx_byte<=8'h90; bit_index<=7;
                ack_error<=0; state<=START0;
            end else if (initialized && adc_phase==2 && adc_wait==0) begin
                stage<=9; tx_byte<=8'h90; bit_index<=7;
                ack_error<=0; state<=START0;
            end else if (initialized && adc_phase==3) begin
                stage<=11; tx_byte<=8'h91; bit_index<=7;
                ack_error<=0; state<=START0;
            end else pause_count <= pause_count + 1'b1;
        end else if (divider == 7'd61) begin
            divider <= 0;
            case (state)
                START0: begin scl_low<=0; sda_low<=0; state<=START1; end
                START1: begin sda_low<=1; state<=START1_HOLD; end
                START1_HOLD: state<=START2;
                START2: begin scl_low<=1; state<=TX_SETUP; end
                TX_SETUP: begin scl_low<=1; sda_low<=~tx_byte[bit_index]; state<=TX_RISE; end
                TX_RISE: begin scl_low<=0; state<=TX_HOLD; end
                TX_HOLD: state<=TX_FALL;
                TX_FALL: begin
                    scl_low<=1;
                    if (bit_index==0) state<=ACK_SETUP;
                    else begin bit_index<=bit_index-1'b1; state<=TX_SETUP; end
                end
                ACK_SETUP: begin scl_low<=1; sda_low<=0; state<=ACK_RISE; end
                ACK_RISE: begin scl_low<=0; state<=ACK_HOLD; end
                ACK_HOLD: begin
                    ack_error<=sda_in;
                    if (!sda_in) begin
                        if (stage==0) write_address_ack<=1;
                        else if (stage==1) write_data_ack<=1;
                        else if (stage==2) read_address_ack<=1;
                    end
                    state<=ACK_FALL;
                end
                ACK_FALL: begin
                    scl_low<=1;
                    if (ack_error) state<=STOP0;
                    else if (stage==0) begin
                        stage<=1; tx_byte<=8'hff; bit_index<=7; state<=TX_SETUP;
                    end else if (stage==3) begin
                        stage<=4; tx_byte<=desired_led_data; bit_index<=7; state<=TX_SETUP;
                    end else if (stage==5) begin
                        stage<=6; tx_byte<=8'h01; bit_index<=7; state<=TX_SETUP;
                    end else if (stage==6) begin
                        stage<=7; tx_byte<=adc_channel ? 8'hc3 : 8'hd3;
                        // OS=1, AIN0 or AIN1 single-ended, PGA=+/-4.096 V.
                        bit_index<=7; state<=TX_SETUP;
                    end else if (stage==7) begin
                        stage<=8; tx_byte<=8'he3; bit_index<=7; state<=TX_SETUP;
                    end else if (stage==9) begin
                        stage<=10; tx_byte<=8'h00; bit_index<=7; state<=TX_SETUP;
                    end else if (stage==1 || stage==4 || stage==8 || stage==10) state<=STOP0;
                    else begin bit_index<=7; rx_byte<=0; state<=RX_SETUP; end
                end
                RX_SETUP: begin scl_low<=1; sda_low<=0; state<=RX_RISE; end
                RX_RISE: begin scl_low<=0; state<=RX_HOLD; end
                RX_HOLD: begin rx_byte[bit_index]<=sda_in; state<=RX_FALL; end
                RX_FALL: begin
                    scl_low<=1;
                    if (bit_index==0) state<=NACK_SETUP;
                    else begin bit_index<=bit_index-1'b1; state<=RX_SETUP; end
                end
                NACK_SETUP: begin scl_low<=1; sda_low<=(stage==11); state<=NACK_RISE; end
                NACK_RISE: begin scl_low<=0; state<=NACK_HOLD; end
                NACK_HOLD: state<=NACK_FALL;
                NACK_FALL: begin
                    scl_low<=1; sda_low<=0;
                    if (stage==11) begin
                        adc_high<=rx_byte; stage<=12; bit_index<=7;
                        rx_byte<=0; state<=RX_SETUP;
                    end else state<=STOP0;
                end
                STOP0: begin scl_low<=1; sda_low<=1; state<=STOP1; end
                STOP1: begin scl_low<=0; state<=STOP1_HOLD; end
                STOP1_HOLD: state<=STOP2;
                STOP2: begin
                    sda_low<=0;
                    if (!ack_error) begin
                        if (stage==1) initialized<=1;
                        if (stage==2) begin
                            keys<=rx_byte; seen<=1; sample_valid<=1;
                            write_led_next<=1;
                            if (ADC_PRESENT) adc_turn<=1;
                        end
                        if (stage==4) begin last_led_data<=tx_byte; led_ack<=1; end
                        if (stage==8) begin adc_phase<=2; adc_wait<=16'd49152; end
                        if (stage==10) adc_phase<=3;
                        if (stage==12) begin
                            if (adc_channel==0) volume_level<=adc_level;
                            else if (!adc_raw[15]) begin
                                if (!fsr_pressed) begin
                                    fsr_bend<=0;
                                    if (adc_raw>=FSR_PRESS_CODE) begin
                                        if (fsr_count==2) begin
                                            fsr_pressed<=1;
                                            fsr_bend<=fsr_target;
                                            fsr_count<=0;
                                        end else fsr_count<=fsr_count+1'b1;
                                    end else fsr_count<=0;
                                end else if (adc_raw<=FSR_RELEASE_CODE) begin
                                    if (fsr_count==2) begin
                                        fsr_pressed<=0;
                                            fsr_bend<=0;
                                        fsr_count<=0;
                                    end else fsr_count<=fsr_count+1'b1;
                                    // An unpressed/relaxed input returns exactly
                                    // to the original pitch, even during hysteresis.
                                    fsr_bend<=0;
                                end else begin
                                    fsr_count<=0;
                                    if (fsr_target==0) fsr_bend<=0;
                                    else if (fsr_bend<fsr_target)
                                        fsr_bend<=fsr_bend+((fsr_target-fsr_bend)>>2)+8'd1;
                                    else if (fsr_bend>fsr_target)
                                        fsr_bend<=fsr_bend-((fsr_bend-fsr_target)>>2)-8'd1;
                                end
                            end else begin fsr_bend<=0; fsr_pressed<=0; fsr_count<=0; end
                            adc_channel<=~adc_channel;
                            adc_phase<=0;
                            adc_turn<=0;
                        end
                    end else if (stage>=5) begin adc_phase<=0; adc_turn<=0; end
                    state<=IDLE;
                end
                default: state<=IDLE;
            endcase
        end else divider <= divider + 1'b1;
    end
endmodule
