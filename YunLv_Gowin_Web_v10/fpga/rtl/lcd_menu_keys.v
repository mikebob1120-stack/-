// 0=root, 1=live keys, 2=SD song list, 3=guided song list,
// 4=SD WAV playback, 5=guided score playback, 6=Wi-Fi upload, 7=SD boot cover.
module lcd_menu_keys #(
    parameter integer CLK_HZ=24576000,
    parameter integer DEBOUNCE_MS=15,
    parameter integer DOUBLE_MS=350
) (
    input wire clk24m, input wire btn_s1, input wire btn_s2,
    input wire remote_valid,
    input wire [3:0] remote_action,
    input wire [2:0] remote_value,
    input wire [3:0] song_count, input wire catalog_ready,
    input wire sd_busy, input wire score_done, input wire upload_locked,
    input wire [7:0] key_state,
    output reg [2:0] ui_mode=7,
    output reg [1:0] menu_selection=0,
    output reg [2:0] song_selection=0,
    output reg scan_start=0,
    output reg song_start=0,
    output reg player_reset=0
);
    localparam integer DEBOUNCE_CYCLES=CLK_HZ/1000*DEBOUNCE_MS;
    localparam integer DOUBLE_CYCLES=CLK_HZ/1000*DOUBLE_MS;
    localparam integer FINISH_HOLD_CYCLES=CLK_HZ/4; // At most 250 ms for last note.
    wire s1_pressed,s2_pressed;
    button_press #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) s1
        (.clk(clk24m),.raw(btn_s1),.pressed(s1_pressed));
    button_press #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) s2
        (.clk(clk24m),.raw(btn_s2),.pressed(s2_pressed));
    reg pending=0;
    reg [31:0] click_age=0;
    reg [1:0] main_at_click=0;
    reg [2:0] song_at_click=0;
    reg [2:0] rescan_delay=0;
    reg [31:0] finish_age=0;
    always @(posedge clk24m) begin
        scan_start<=0;
        song_start<=0;
        player_reset<=0;
        if (rescan_delay!=0) begin
            rescan_delay<=rescan_delay-1'b1;
            if (rescan_delay==1) scan_start<=1;
        end
        if (s1_pressed) begin
            click_age<=0;
            if (ui_mode==7) begin
                ui_mode<=0; menu_selection<=0;
                pending<=0; player_reset<=1; rescan_delay<=0;
            end else if (pending) begin
                pending<=0;
                case(ui_mode)
                    4: begin ui_mode<=2; player_reset<=1; rescan_delay<=3; end
                    5: begin ui_mode<=3; player_reset<=1; rescan_delay<=3; end
                    6: if (!upload_locked) begin ui_mode<=0; player_reset<=1; end
                    2,3: begin ui_mode<=0; player_reset<=1; rescan_delay<=0; end
                    default: ui_mode<=0;
                endcase
            end else begin
                pending<=1;
                main_at_click<=menu_selection;
                song_at_click<=song_selection;
            end
        end else if (pending) begin
            if (click_age>=DOUBLE_CYCLES-1) begin
                pending<=0; click_age<=0;
                case(ui_mode)
                    0: case(main_at_click)
                        0: ui_mode<=1;
                        1: begin ui_mode<=2; song_selection<=0; scan_start<=1; end
                        2: begin ui_mode<=3; song_selection<=0; scan_start<=1; end
                        3: begin ui_mode<=6; player_reset<=1; end
                        default: ui_mode<=0;
                    endcase
                    2,3: if (catalog_ready && song_at_click<song_count) begin
                        ui_mode <= (ui_mode==2) ? 4 : 5;
                        song_start <= 1;
                    end else if (!sd_busy) scan_start<=1; // Retry card scan.
                    4: if (!sd_busy) song_start<=1; // Replay after WAV finishes.
                    default: ;
                endcase
            end else click_age<=click_age+1'b1;
        end
        if (s2_pressed) begin
            if (ui_mode==0) begin
                if (menu_selection==3) menu_selection<=0;
                else menu_selection<=menu_selection+1'b1;
            end else if ((ui_mode==2 || ui_mode==3) && catalog_ready && song_count!=0) begin
                if ({1'b0,song_selection}+4'd1>=song_count) song_selection<=0;
                else song_selection<=song_selection+1'b1;
            end
        end
        // Once the final score step is accepted, let the final note sound
        // until it is released (or 250 ms), then reuse the current NTE list.
        // Give this transition priority over an unfinished S1 click.
        if (ui_mode==5 && score_done) begin
            if (key_state==0 || finish_age>=FINISH_HOLD_CYCLES-1) begin
                ui_mode<=3;
                player_reset<=1;
                rescan_delay<=0;
                scan_start<=0;
                pending<=0;
                click_age<=0;
                finish_age<=0;
            end else finish_age<=finish_age+1'b1;
        end else finish_age<=0;
        if (remote_valid && !upload_locked) begin
            pending<=0; click_age<=0; rescan_delay<=0; finish_age<=0;
            case(remote_action)
                1: case(ui_mode) // Confirm, without a double-click wait.
                    7: begin ui_mode<=0; menu_selection<=0; player_reset<=1; end
                    0: case(menu_selection)
                        0: ui_mode<=1;
                        1: begin ui_mode<=2; song_selection<=0; scan_start<=1; end
                        2: begin ui_mode<=3; song_selection<=0; scan_start<=1; end
                        3: begin ui_mode<=6; player_reset<=1; end
                    endcase
                    2,3: if(catalog_ready && {1'b0,song_selection}<song_count) begin
                        ui_mode<=(ui_mode==2)?4:5; song_start<=1;
                    end else if(!sd_busy) scan_start<=1;
                    4: if(!sd_busy) song_start<=1;
                    default: ;
                endcase
                2: if(ui_mode==0) menu_selection<=menu_selection+1'b1;
                   else if((ui_mode==2 || ui_mode==3) && catalog_ready && song_count!=0)
                       song_selection<=({1'b0,song_selection}+4'd1>=song_count)?3'd0:song_selection+1'b1;
                3: begin // Back, equivalent to S1 double click.
                    player_reset<=1;
                    case(ui_mode)
                        4: begin ui_mode<=2; rescan_delay<=3; end
                        5: begin ui_mode<=3; rescan_delay<=3; end
                        default: ui_mode<=0;
                    endcase
                end
                4: begin ui_mode<=1; menu_selection<=0; player_reset<=1; end
                5: begin // Enter one of the original four functions directly.
                    player_reset<=1; menu_selection<=remote_value[1:0];
                    song_selection<=0;
                    case(remote_value[1:0])
                        0: ui_mode<=1;
                        1: begin ui_mode<=2; rescan_delay<=3; end
                        2: begin ui_mode<=3; rescan_delay<=3; end
                        3: ui_mode<=6;
                    endcase
                end
                6: if((ui_mode==2 || ui_mode==3) && catalog_ready && {1'b0,remote_value}<song_count)
                    song_selection<=remote_value;
                7: begin ui_mode<=0; player_reset<=1; end
                default: ;
            endcase
        end
    end
endmodule

module button_press #(parameter integer DEBOUNCE_CYCLES=368640) (
    input wire clk,input wire raw,output reg pressed=0
);
    reg sync1=0,sync2=0,stable=0;
    reg [31:0] count=0;
    always @(posedge clk) begin
        sync1<=raw; sync2<=sync1; pressed<=0;
        if (sync2==stable) count<=0;
        else if (count>=DEBOUNCE_CYCLES-1) begin
            stable<=sync2; count<=0;
            if (sync2) pressed<=1;
        end else count<=count+1'b1;
    end
endmodule
