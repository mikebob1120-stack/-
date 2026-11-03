// Legacy NTE uses 500 ms/step; NTE2 supplies each note's target interval.
module follow_rhythm_score (
    input wire clk24m,
    input wire sample_tick,
    input wire guided_mode,
    input wire song_start,
    input wire score_ready,
    input wire score_done,
    input wire score_advance,
    input wire [7:0] score_step_10ms,
    input wire [7:0] keys,
    output reg [8:0] beat_phase_ms=0,
    output reg [1:0] timing_hint=0, // 0 waiting, 1 early, 2 on time, 3 late
    output reg [6:0] final_percent=0,
    output reg result_valid=0
);
    reg [4:0] sample_div=0;
    reg [19:0] elapsed_ms=0;
    reg [19:0] due_ms=20'd500;
    reg [19:0] step_start_ms=0;
    reg [11:0] step_duration_ms=12'd500;
    reg advance_pending=0;
    wire [11:0] supplied_duration_ms=
        ({4'd0,score_step_10ms} << 3)+({4'd0,score_step_10ms} << 1);
    wire [19:0] elapsed_step = elapsed_ms>step_start_ms ?
        elapsed_ms-step_start_ms : 20'd0;
    reg [15:0] total_points=0;
    reg [8:0] accepted=0, wrong_releases=0;
    reg [7:0] previous_keys=0;
    reg matched_this_press=0;
    reg ready_prev=0, done_prev=0;
    reg [15:0] remainder=0;
    reg [8:0] divisor=0;
    reg dividing=0;
    wire [19:0] delta_ms = elapsed_ms>=due_ms ?
        elapsed_ms-due_ms : due_ms-elapsed_ms;
    wire [7:0] event_points = delta_ms<=20'd50 ? 8'd100 :
        delta_ms<=20'd100 ? 8'd80 :
        delta_ms<=20'd200 ? 8'd50 : 8'd20;
    wire [12:0] penalty = ({4'b0,wrong_releases}<<3) +
                           ({4'b0,wrong_releases}<<1);
    wire [15:0] adjusted_points = total_points>penalty ?
        total_points-penalty : 16'd0;
    always @(posedge clk24m) begin
        ready_prev<=score_ready;
        done_prev<=score_done;
        if (song_start) begin
            sample_div<=0; elapsed_ms<=0; beat_phase_ms<=0;
            due_ms<=20'd500; timing_hint<=0;
            step_start_ms<=0;step_duration_ms<=12'd500;advance_pending<=0;
            total_points<=0; accepted<=0; wrong_releases<=0;
            previous_keys<=0; matched_this_press<=0;
            final_percent<=0; result_valid<=0; dividing<=0;
            remainder<=0; divisor<=0;
        end else begin
            if (guided_mode && score_ready && !ready_prev) begin
                sample_div<=0; elapsed_ms<=0; beat_phase_ms<=0;
                due_ms<=supplied_duration_ms; timing_hint<=0;
                step_start_ms<=0;step_duration_ms<=supplied_duration_ms;
                advance_pending<=0;
                previous_keys<=0; matched_this_press<=0;
            end
            if (guided_mode && score_ready && !score_done) begin
                // SD updates its step index at score_advance; one FPGA clock
                // later the next duration is available from the same RAM.
                if (score_advance) advance_pending<=1;
                else if (advance_pending) begin
                    advance_pending<=0;
                    step_start_ms<=due_ms;
                    step_duration_ms<=supplied_duration_ms;
                    due_ms<=due_ms+{8'd0,supplied_duration_ms};
                    beat_phase_ms<=0;
                end
                previous_keys<=keys;
                if (score_advance) matched_this_press<=1;
                if (previous_keys!=0 && keys==0) begin
                    if (!matched_this_press && wrong_releases!=9'd511)
                        wrong_releases<=wrong_releases+1'b1;
                    matched_this_press<=0;
                end
                if (sample_tick) begin
                    if (sample_div==5'd31) begin
                        sample_div<=0;
                        if (elapsed_ms!=20'hfffff) elapsed_ms<=elapsed_ms+1'b1;
                        // Four quarters of the current NTE2 interval.
                        // Existing 500-ms LCD/phone bar needs no new pixels.
                        if (elapsed_step>=step_duration_ms)
                            beat_phase_ms<=9'd499;
                        else if (elapsed_step>=step_duration_ms-(step_duration_ms>>2))
                            beat_phase_ms<=9'd375;
                        else if (elapsed_step>=(step_duration_ms>>1))
                            beat_phase_ms<=9'd250;
                        else if (elapsed_step>=(step_duration_ms>>2))
                            beat_phase_ms<=9'd125;
                        else beat_phase_ms<=0;
                    end else sample_div<=sample_div+1'b1;
                end
                if (score_advance) begin
                    if (elapsed_ms+20'd50<due_ms) timing_hint<=2'd1;
                    else if (elapsed_ms>due_ms+20'd50) timing_hint<=2'd3;
                    else timing_hint<=2'd2;
                    total_points<=total_points+{8'b0,event_points};
                    accepted<=accepted+1'b1;
                end
            end
            // Divide by repeated subtraction only once at finish: <=100
            // cycles at 24.576 MHz. No fabric-wide hardware divider.
            if (guided_mode && score_done && !done_prev && accepted!=0) begin
                remainder<=adjusted_points;
                divisor<=accepted;
                final_percent<=0;
                result_valid<=0;
                dividing<=1;
            end else if (dividing) begin
                if (remainder>=divisor && final_percent<7'd100) begin
                    remainder<=remainder-divisor;
                    final_percent<=final_percent+1'b1;
                end else begin dividing<=0; result_valid<=1; end
            end
        end
    end
endmodule
