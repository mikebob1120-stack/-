// Stateless 480x272 start menu renderer. x/y are visible-area pixel positions.
// Fixed ASCII text avoids framebuffer or external font ROM dependencies.
module lcd_menu_pixels (
    input wire [9:0] x,
    input wire [8:0] y,
    input wire [2:0] mode,
    input wire [1:0] selection,
    input wire [2:0] song_selection,
    input wire [3:0] song_count,
    input wire [511:0] song_names,
    input wire catalog_ready, sd_busy, sd_playing,
    input wire [3:0] sd_error,
    input wire score_ready, score_done,
    input wire [7:0] volume,
    input wire fsr_active,
    input wire [7:0] fsr_bend,
    input wire [1:0] timbre_a,
    input wire [1:0] timbre_b,
    input wire [1:0] voice_mode,
    input wire [1:0] effect_mode,
    input wire metronome,
    input wire [8:0] beat_phase_ms,
    input wire [1:0] timing_hint,
    input wire [6:0] final_percent,
    input wire result_valid,
    input wire [7:0] latency_tenth_ms,
    input wire latency_valid,
    output reg [15:0] rgb
);
    function [7:0] character;
        input [4:0] line;
        input [4:0] n;
        begin
            character = " ";
            case (line)
                0: case (n) // START MENU
                    0:character="S"; 1:character="T"; 2:character="A";
                    3:character="R"; 4:character="T"; 6:character="M";
                    7:character="E"; 8:character="N"; 9:character="U";
                endcase
                1: case (n) // 1 PLAY LIVE
                    0:character="1"; 2:character="P"; 3:character="L";
                    4:character="A"; 5:character="Y"; 7:character="L";
                    8:character="I"; 9:character="V"; 10:character="E";
                endcase
                2: case (n) // 2 SD MUSIC
                    0:character="2"; 2:character="S"; 3:character="D";
                    5:character="M"; 6:character="U"; 7:character="S";
                    8:character="I"; 9:character="C";
                endcase
                3: case (n) // 3 FOLLOW PLAY
                    0:character="3"; 2:character="F"; 3:character="O";
                    4:character="L"; 5:character="L"; 6:character="O";
                    7:character="W"; 9:character="P"; 10:character="L";
                    11:character="A"; 12:character="Y";
                endcase
                4: case (n) // COMING SOON
                    0:character="C"; 1:character="O"; 2:character="M";
                    3:character="I"; 4:character="N"; 5:character="G";
                    7:character="S"; 8:character="O"; 9:character="O";
                    10:character="N";
                endcase
                5: case (n) // S1 DOUBLE BACK
                    0:character="S"; 1:character="1"; 3:character="D";
                    4:character="O"; 5:character="U"; 6:character="B";
                    7:character="L"; 8:character="E"; 10:character="B";
                    11:character="A"; 12:character="C"; 13:character="K";
                endcase
                6: case(n) // SD SONGS
                    0:character="S"; 1:character="D"; 3:character="S";
                    4:character="O"; 5:character="N"; 6:character="G";
                    7:character="S";
                endcase
                7: case(n) // FOLLOW SONGS
                    0:character="F"; 1:character="O"; 2:character="L";
                    3:character="L"; 4:character="O"; 5:character="W";
                    7:character="S"; 8:character="O"; 9:character="N";
                    10:character="G"; 11:character="S";
                endcase
                8: case(n) // READING SD
                    0:character="R"; 1:character="E"; 2:character="A";
                    3:character="D"; 4:character="I"; 5:character="N";
                    6:character="G"; 8:character="S"; 9:character="D";
                endcase
                9: case(n) // CARD ERROR
                    0:character="C"; 1:character="A"; 2:character="R";
                    3:character="D"; 5:character="E"; 6:character="R";
                    7:character="R"; 8:character="O"; 9:character="R";
                endcase
                10: case(n) // NO WAV FILE
                    0:character="N"; 1:character="O"; 3:character="W";
                    4:character="A"; 5:character="V"; 7:character="F";
                    8:character="I"; 9:character="L"; 10:character="E";
                endcase
                11: case(n) // PLAYING
                    0:character="P"; 1:character="L"; 2:character="A";
                    3:character="Y"; 4:character="I"; 5:character="N";
                    6:character="G";
                endcase
                12: case(n) // DONE
                    0:character="D"; 1:character="O";
                    2:character="N"; 3:character="E";
                endcase
                13: case(n) // LOADING
                    0:character="L"; 1:character="O"; 2:character="A";
                    3:character="D"; 4:character="I"; 5:character="N";
                    6:character="G";
                endcase
                14: case(n) // PRESS KEY
                    0:character="P"; 1:character="R"; 2:character="E";
                    3:character="S"; 4:character="S"; 6:character="K";
                    7:character="E"; 8:character="Y";
                endcase
                15: case(n) // FOLLOW
                    0:character="F"; 1:character="O"; 2:character="L";
                    3:character="L"; 4:character="O"; 5:character="W";
                endcase
                16: case(n) // NO SCORE
                    0:character="N"; 1:character="O"; 3:character="S";
                    4:character="C"; 5:character="O"; 6:character="R";
                    7:character="E";
                endcase
                17: case(n) // 4 WI-FI UPLOAD
                    0:character="4"; 2:character="W"; 3:character="I";
                    4:character="-"; 5:character="F"; 6:character="I";
                    8:character="U"; 9:character="P"; 10:character="L";
                    11:character="O"; 12:character="A"; 13:character="D";
                endcase
                18: case(n) // CONNECT FPGA-MUSIC
                    0:character="C"; 1:character="O"; 2:character="N";
                    3:character="N"; 4:character="E"; 5:character="C";
                    6:character="T"; 8:character="F"; 9:character="P";
                    10:character="G"; 11:character="A"; 12:character="-";
                    13:character="M"; 14:character="U"; 15:character="S";
                    16:character="I"; 17:character="C";
                endcase
                19: case(n) // OPEN 192.168.4.1
                    0:character="O"; 1:character="P"; 2:character="E";
                    3:character="N"; 5:character="1"; 6:character="9";
                    7:character="2"; 8:character="."; 9:character="1";
                    10:character="6"; 11:character="8"; 12:character=".";
                    13:character="4"; 14:character="."; 15:character="1";
                endcase
                20: case(n) // PRESS S1 TO START
                    0:character="P";
                    1:character="R";
                    2:character="E";
                    3:character="S";
                    4:character="S";
                    6:character="S";
                    7:character="1";
                    9:character="T";
                    10:character="O";
                    12:character="S";
                    13:character="T";
                    14:character="A";
                    15:character="R";
                    16:character="T";
                endcase
                21: case(n) // COVER.BMP ERROR
                    0:character="C";
                    1:character="O";
                    2:character="V";
                    3:character="E";
                    4:character="R";
                    5:character=".";
                    6:character="B";
                    7:character="M";
                    8:character="P";
                    10:character="E";
                    11:character="R";
                    12:character="R";
                    13:character="O";
                    14:character="R";
                endcase
                22: case(n) // READING COVER.BMP
                    0:character="R";
                    1:character="E";
                    2:character="A";
                    3:character="D";
                    4:character="I";
                    5:character="N";
                    6:character="G";
                    8:character="C";
                    9:character="O";
                    10:character="V";
                    11:character="E";
                    12:character="R";
                    13:character=".";
                    14:character="B";
                    15:character="M";
                    16:character="P";
                endcase
                23: case(n) // ERROR CODE
                    0:character="E";
                    1:character="R";
                    2:character="R";
                    3:character="O";
                    4:character="R";
                    6:character="C";
                    7:character="O";
                    8:character="D";
                    9:character="E";
                endcase
            endcase
        end
    endfunction

    // 5x7 uppercase pixel font, most-significant bit is leftmost.
    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] r;
        begin
            glyph_row=0;
            case(ch)
                "A":case(r) 0:glyph_row=5'b01110; 1,2:glyph_row=5'b10001; 3:glyph_row=5'b11111; 4,5,6:glyph_row=5'b10001; endcase
                "B":case(r) 0,3:glyph_row=5'b11110; 1,2,4,5:glyph_row=5'b10001; 6:glyph_row=5'b11110; endcase
                "C":case(r) 0,6:glyph_row=5'b01111; 1,2,3,4,5:glyph_row=5'b10000; endcase
                "D":case(r) 0,6:glyph_row=5'b11110; 1,2,3,4,5:glyph_row=5'b10001; endcase
                "E":case(r) 0,3,6:glyph_row=5'b11111; 1,2,4,5:glyph_row=5'b10000; endcase
                "F":case(r) 0:glyph_row=5'b11111; 1,2,4,5,6:glyph_row=5'b10000; 3:glyph_row=5'b11110; endcase
                "G":case(r) 0,6:glyph_row=5'b01111; 1,2:glyph_row=5'b10000; 3:glyph_row=5'b10111; 4,5:glyph_row=5'b10001; endcase
                "H":case(r) 0,1,2,4,5,6:glyph_row=5'b10001; 3:glyph_row=5'b11111; endcase
                "I":case(r) 0,6:glyph_row=5'b11111; 1,2,3,4,5:glyph_row=5'b00100; endcase
                "J":case(r) 0:glyph_row=5'b00111; 1,2,3,4:glyph_row=5'b00010; 5:glyph_row=5'b10010; 6:glyph_row=5'b01100; endcase
                "K":case(r) 0,6:glyph_row=5'b10001; 1,5:glyph_row=5'b10010; 2,4:glyph_row=5'b10100; 3:glyph_row=5'b11000; endcase
                "L":case(r) 0,1,2,3,4,5:glyph_row=5'b10000; 6:glyph_row=5'b11111; endcase
                "M":case(r) 0,5,6:glyph_row=5'b10001; 1:glyph_row=5'b11011; 2,3,4:glyph_row=5'b10101; endcase
                "N":case(r) 0,6:glyph_row=5'b10001; 1:glyph_row=5'b11001; 2:glyph_row=5'b10101; 3,4:glyph_row=5'b10011; 5:glyph_row=5'b10001; endcase
                "O":case(r) 0,6:glyph_row=5'b01110; 1,2,3,4,5:glyph_row=5'b10001; endcase
                "P":case(r) 0,3:glyph_row=5'b11110; 1,2:glyph_row=5'b10001; 4,5,6:glyph_row=5'b10000; endcase
                "Q":case(r) 0:glyph_row=5'b01110; 1,2,3:glyph_row=5'b10001; 4:glyph_row=5'b10101; 5:glyph_row=5'b10010; 6:glyph_row=5'b01101; endcase
                "R":case(r) 0,3:glyph_row=5'b11110; 1,2:glyph_row=5'b10001; 4:glyph_row=5'b10100; 5:glyph_row=5'b10010; 6:glyph_row=5'b10001; endcase
                "S":case(r) 0:glyph_row=5'b01111; 1,2:glyph_row=5'b10000; 3:glyph_row=5'b01110; 4,5:glyph_row=5'b00001; 6:glyph_row=5'b11110; endcase
                "T":case(r) 0:glyph_row=5'b11111; 1,2,3,4,5,6:glyph_row=5'b00100; endcase
                "U":case(r) 0,1,2,3,4,5:glyph_row=5'b10001; 6:glyph_row=5'b01110; endcase
                "V":case(r) 0,1,2,3:glyph_row=5'b10001; 4,5:glyph_row=5'b01010; 6:glyph_row=5'b00100; endcase
                "W":case(r) 0,1,2,6:glyph_row=5'b10001; 3,4,5:glyph_row=5'b10101; endcase
                "X":case(r) 0,6:glyph_row=5'b10001; 1,5:glyph_row=5'b01010; 2,3,4:glyph_row=5'b00100; endcase
                "Y":case(r) 0,1:glyph_row=5'b10001; 2:glyph_row=5'b01010; 3,4,5,6:glyph_row=5'b00100; endcase
                "Z":case(r) 0,6:glyph_row=5'b11111; 1:glyph_row=5'b00001; 2:glyph_row=5'b00010; 3:glyph_row=5'b00100; 4:glyph_row=5'b01000; 5:glyph_row=5'b10000; endcase
                "0":case(r) 0,6:glyph_row=5'b01110; 1,2,3,4,5:glyph_row=5'b10001; endcase
                "1":case(r) 0:glyph_row=5'b00100; 1:glyph_row=5'b01100; 2,3,4,5:glyph_row=5'b00100; 6:glyph_row=5'b01110; endcase
                "2":case(r) 0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b00001; 3:glyph_row=5'b00010; 4:glyph_row=5'b00100; 5:glyph_row=5'b01000; 6:glyph_row=5'b11111; endcase
                "3":case(r) 0:glyph_row=5'b11110; 1:glyph_row=5'b00001; 2:glyph_row=5'b00001; 3:glyph_row=5'b01110; 4,5:glyph_row=5'b00001; 6:glyph_row=5'b11110; endcase
                "4":case(r) 0:glyph_row=5'b00010; 1:glyph_row=5'b00110; 2:glyph_row=5'b01010; 3:glyph_row=5'b10010; 4:glyph_row=5'b11111; 5,6:glyph_row=5'b00010; endcase
                "5":case(r) 0:glyph_row=5'b11111; 1,2:glyph_row=5'b10000; 3:glyph_row=5'b11110; 4,5:glyph_row=5'b00001; 6:glyph_row=5'b11110; endcase
                "6":case(r) 0:glyph_row=5'b01111; 1,2:glyph_row=5'b10000; 3:glyph_row=5'b11110; 4,5:glyph_row=5'b10001; 6:glyph_row=5'b01110; endcase
                "7":case(r) 0:glyph_row=5'b11111; 1,2:glyph_row=5'b00001; 3:glyph_row=5'b00010; 4:glyph_row=5'b00100; 5,6:glyph_row=5'b01000; endcase
                "8":case(r) 0,3,6:glyph_row=5'b01110; 1,2,4,5:glyph_row=5'b10001; endcase
                "9":case(r) 0:glyph_row=5'b01110; 1,2:glyph_row=5'b10001; 3:glyph_row=5'b01111; 4,5:glyph_row=5'b00001; 6:glyph_row=5'b11110; endcase
                "_":case(r) 6:glyph_row=5'b11111; endcase
                "-":case(r) 3:glyph_row=5'b11111; endcase
                ".":case(r) 6:glyph_row=5'b00100; endcase
            endcase
        end
    endfunction

    reg [4:0] line;
    reg [9:0] text_x;
    reg [8:0] text_y;
    reg [4:0] char_index;
    reg [2:0] font_x;
    reg [2:0] font_y;
    reg [4:0] pixels;
    reg highlighted;
    reg text_valid;
    reg text_is_song;
    reg [1:0] row_local;
    reg [3:0] row_abs;
    reg [63:0] row_name;
    reg [7:0] text_character;
    wire [15:0] volume_product = volume * 8'd93;
    wire [7:0] volume_fill = volume_product[15:8];
    // Same visual pattern as VOL, scaled to the space between timbre and FX.
    wire [15:0] fsr_product = fsr_bend * 8'd57;
    wire [7:0] fsr_fill = fsr_product[15:8];
    reg [9:0] vol_x;
    reg [8:0] vol_y;
    reg [9:0] fsr_x;
    reg [8:0] fsr_y;
    reg [9:0] status_x;
    reg [8:0] status_y;
    reg [9:0] effect_x;
    reg [8:0] effect_y;
    reg [9:0] extra_x;
    reg [8:0] extra_y;
    reg [7:0] extra_char;
    wire [6:0] score_tens=final_percent/7'd10;
    wire [6:0] score_ones=final_percent%7'd10;
    wire [7:0] pipe_ms=latency_tenth_ms/8'd10;
    wire [7:0] pipe_dec=latency_tenth_ms%8'd10;
    always @* begin
        rgb=16'h0843; // background
        line=0; text_x=0; text_y=0; char_index=0;
        font_x=0; font_y=0; pixels=0; highlighted=0; text_valid=0;
        text_is_song=0; row_local=0; row_abs=0; row_name=0;
        text_character=" ";
        vol_x=0; vol_y=0; fsr_x=0; fsr_y=0;
        status_x=0; status_y=0;
        effect_x=0; effect_y=0;
        extra_x=0; extra_y=0; extra_char=" ";

        if (mode == 0) begin
            if (y>=9'd42 && y<9'd90 && x>=10'd26 && x<10'd454) begin
                highlighted=(selection==0);
                rgb=highlighted ? 16'h06B3 : 16'h1908;
                if (x<10'd29 || x>=10'd451 || y<9'd45 || y>=9'd87)
                    rgb=highlighted ? 16'h7FFF : 16'h5294;
            end else if (y>=9'd96 && y<9'd144 && x>=10'd26 && x<10'd454) begin
                highlighted=(selection==1);
                rgb=highlighted ? 16'h06B3 : 16'h1908;
                if (x<10'd29 || x>=10'd451 || y<9'd99 || y>=9'd141)
                    rgb=highlighted ? 16'h7FFF : 16'h5294;
            end else if (y>=9'd150 && y<9'd198 && x>=10'd26 && x<10'd454) begin
                highlighted=(selection==2);
                rgb=highlighted ? 16'h06B3 : 16'h1908;
                if (x<10'd29 || x>=10'd451 || y<9'd153 || y>=9'd195)
                    rgb=highlighted ? 16'h7FFF : 16'h5294;
            end else if (y>=9'd204 && y<9'd252 && x>=10'd26 && x<10'd454) begin
                highlighted=(selection==3);
                rgb=highlighted ? 16'h06B3 : 16'h1908;
                if (x<10'd29 || x>=10'd451 || y<9'd207 || y>=9'd249)
                    rgb=highlighted ? 16'h7FFF : 16'h5294;
            end
            if (x>=10'd44 && x<10'd364 && y>=9'd21 && y<9'd35) begin
                text_valid=1;
                line=0; text_x=x-10'd44; text_y=y-9'd21;
            end else if (x>=10'd56 && x<10'd376 && y>=9'd58 && y<9'd72) begin
                text_valid=1;
                line=1; text_x=x-10'd56; text_y=y-9'd58;
            end else if (x>=10'd56 && x<10'd376 && y>=9'd112 && y<9'd126) begin
                text_valid=1;
                line=2; text_x=x-10'd56; text_y=y-9'd112;
            end else if (x>=10'd56 && x<10'd376 && y>=9'd166 && y<9'd180) begin
                text_valid=1;
                line=3; text_x=x-10'd56; text_y=y-9'd166;
            end else if (x>=10'd56 && x<10'd376 && y>=9'd220 && y<9'd234) begin
                text_valid=1;
                line=17; text_x=x-10'd56; text_y=y-9'd220;
            end
        end else if (mode==7) begin
            // Always show a readable boot page until the SD image is complete.
            rgb=16'h0843;
            if (y>=9'd30 && y<9'd36 && x>=10'd40 && x<10'd440) rgb=16'h06B3;
            if (x>=10'd96 && x<10'd384 && y>=9'd106 && y<9'd120) begin
                text_valid=1; text_x=x-10'd96; text_y=y-9'd106;
                line=(sd_error!=0) ? 21 : 22;
            end else if (sd_error!=0 && x>=10'd96 && x<10'd384 && y>=9'd132 && y<9'd146) begin
                text_valid=1; text_x=x-10'd96; text_y=y-9'd132; line=23;
            end else if (x>=10'd96 && x<10'd384 && y>=9'd176 && y<9'd190) begin
                text_valid=1; text_x=x-10'd96; text_y=y-9'd176; line=20;
            end
        end else if (mode==2 || mode==3) begin
            if (x>=10'd35 && x<10'd445 && y>=9'd12 && y<9'd50)
                rgb=16'h1908;
            if (x>=10'd48 && x<10'd368 && y>=9'd23 && y<9'd37) begin
                text_valid=1;
                line=(mode==2) ? 6 : 7; text_x=x-10'd48; text_y=y-9'd23;
            end
            if (catalog_ready && song_count!=0) begin
                if (y>=9'd58 && y<9'd100) row_local=0;
                else if (y>=9'd108 && y<9'd150) row_local=1;
                else if (y>=9'd158 && y<9'd200) row_local=2;
                else if (y>=9'd208 && y<9'd250) row_local=3;
                row_abs={1'b0,song_selection[2],2'b00}+{2'b00,row_local};
                if (x>=10'd28 && x<10'd452 && row_abs<song_count &&
                    ((y>=9'd58 && y<9'd100) || (y>=9'd108 && y<9'd150) ||
                     (y>=9'd158 && y<9'd200) || (y>=9'd208 && y<9'd250))) begin
                    highlighted=(song_selection==row_abs[2:0]);
                    rgb=highlighted ? 16'h06B3 : 16'h1908;
                    if (x<10'd31 || x>=10'd449) rgb=highlighted ? 16'h7FFF : 16'h5294;
                    if (x>=10'd54 && x<10'd374) begin
                        text_valid=1; text_is_song=1;
                        text_x=x-10'd54;
                        case(row_local)
                            0:text_y=y-9'd71;
                            1:text_y=y-9'd121;
                            2:text_y=y-9'd171;
                            3:text_y=y-9'd221;
                        endcase
                        if (text_y>=9'd14) text_valid=0;
                    end
                end
            end else if (x>=10'd54 && x<10'd374 && y>=9'd122 && y<9'd136) begin
                text_valid=1; text_x=x-10'd54; text_y=y-9'd122;
                if (sd_error!=0) line=9;
                else if (sd_busy || !catalog_ready) line=8;
                else line=(mode==3) ? 16 : 10;
            end
        end else if (mode==4) begin
            if (x>=10'd34 && x<10'd446 && y>=9'd56 && y<9'd150)
                rgb=16'h1908;
            if (x>=10'd60 && x<10'd380 && y>=9'd75 && y<9'd89) begin
                text_valid=1; line=2; text_x=x-10'd60; text_y=y-9'd75;
            end else if (x>=10'd60 && x<10'd380 && y>=9'd118 && y<9'd132) begin
                text_valid=1; text_x=x-10'd60; text_y=y-9'd118;
                if (sd_error!=0) line=9;
                else if (sd_playing) line=11;
                else if (sd_busy) line=13;
                else line=12;
            end else if (x>=10'd70 && x<10'd390 && y>=9'd220 && y<9'd234) begin
                text_valid=1; line=5; text_x=x-10'd70; text_y=y-9'd220;
            end
        end else if (mode==6) begin
            if (x>=10'd30 && x<10'd450 && y>=9'd48 && y<9'd242) rgb=16'h1908;
            if (x>=10'd50 && x<10'd370 && y>=9'd80 && y<9'd94) begin
                text_valid=1; line=17; text_x=x-10'd50; text_y=y-9'd80;
            end else if (x>=10'd50 && x<10'd370 && y>=9'd135 && y<9'd149) begin
                text_valid=1; line=18; text_x=x-10'd50; text_y=y-9'd135;
            end else if (x>=10'd50 && x<10'd370 && y>=9'd190 && y<9'd204) begin
                text_valid=1; line=19; text_x=x-10'd50; text_y=y-9'd190;
            end
        end else if (mode==5) begin
            if (y<9'd21 || y>=9'd249) rgb=16'h1908;
            if (x>=10'd32 && x<10'd352 && y>=9'd2 && y<9'd16) begin
                text_valid=1; line=15; text_x=x-10'd32; text_y=y-9'd2;
            end else if (x>=10'd32 && x<10'd352 && y>=9'd253 && y<9'd267) begin
                text_valid=1; text_x=x-10'd32; text_y=y-9'd253;
                if (sd_error!=0) line=9;
                else if (score_done) line=12;
                else if (score_ready) line=14;
                else line=13;
            end
        end

        // A character cell is 16x14; 5x7 glyph pixels are doubled.
        char_index=text_x[8:4];
        font_x=text_x[3:1];
        font_y=text_y[3:1];
        if (text_is_song && row_abs<song_count) begin
            row_name=song_names[{row_abs[2:0],6'b0} +:64];
            if (char_index==0) text_character=8'd49+row_abs[2:0];
            else if (char_index>=2 && char_index<10)
                text_character=row_name[(char_index-2)*8 +:8];
        end else text_character=character(line,char_index);
        if (mode==7 && line==23 && char_index==11)
            text_character=8'd48+{4'b0,sd_error};
        pixels=glyph_row(text_character,font_y);
        if (text_valid && font_x<5 && pixels[4-font_x]) rgb=16'hFFFF;
        // 120 BPM trainer: 500 ms fill between beats. Hints reflect the
        // accepted note against its absolute beat, not acoustic output.
        if (mode==5 && y>=9'd142 && y<9'd147 && x>=10'd80 && x<10'd334) begin
            if (x>=10'd330) rgb=16'hFFFF;
            else rgb=(x-10'd80 < {2'b0,beat_phase_ms[8:1]}) ?
                16'h07E0 : 16'h3186;
        end
        if (mode==5 && y>=9'd126 && y<9'd140 && x>=10'd32 && x<10'd208) begin
            extra_x=x-10'd32; extra_y=y-9'd126;
            char_index=extra_x[7:4];
            case (timing_hint)
                1:case(char_index)
                    0:extra_char="E"; 1:extra_char="A"; 2:extra_char="R";
                    3:extra_char="L"; 4:extra_char="Y";
                endcase
                2:case(char_index)
                    0:extra_char="O"; 1:extra_char="N"; 3:extra_char="T";
                    4:extra_char="I"; 5:extra_char="M"; 6:extra_char="E";
                endcase
                3:case(char_index)
                    0:extra_char="L"; 1:extra_char="A";
                    2:extra_char="T"; 3:extra_char="E";
                endcase
                default:case(char_index)
                    0:extra_char="B"; 1:extra_char="E";
                    2:extra_char="A"; 3:extra_char="T";
                endcase
            endcase
            font_x=extra_x[3:1]; font_y=extra_y[3:1];
            pixels=glyph_row(extra_char,font_y);
            if (font_x<5 && pixels[4-font_x])
                rgb=timing_hint==2 ? 16'h07E0 :
                    (timing_hint==1 || timing_hint==3) ? 16'hFE20 : 16'hFFFF;
        end
        if (mode==5 && latency_valid && y>=9'd126 && y<9'd140 &&
            x>=10'd266 && x<10'd458) begin
            extra_x=x-10'd266; extra_y=y-9'd126;
            char_index=extra_x[7:4]; extra_char=" ";
            case(char_index)
                0:extra_char="P"; 1:extra_char="I";
                2:extra_char="P"; 3:extra_char="E";
                5:extra_char=8'd48+pipe_ms;
                6:extra_char=".";
                7:extra_char=8'd48+pipe_dec;
                8:extra_char="M"; 9:extra_char="S";
            endcase
            font_x=extra_x[3:1]; font_y=extra_y[3:1];
            pixels=glyph_row(extra_char,font_y);
            if (font_x<5 && pixels[4-font_x]) rgb=16'hBDF7;
        end
        // Persist result on the guided song list after automatic return.
        if (mode==3 && result_valid && y>=9'd38 && y<9'd52 &&
            x>=10'd266 && x<10'd458) begin
            extra_x=x-10'd266; extra_y=y-9'd38;
            char_index=extra_x[7:4]; extra_char=" ";
            case(char_index)
                0:extra_char="S"; 1:extra_char="C";
                2:extra_char="O"; 3:extra_char="R"; 4:extra_char="E";
                6:extra_char=final_percent==7'd100 ? "1" : "0";
                7:extra_char=8'd48+(final_percent==7'd100 ? 7'd0:score_tens);
                8:extra_char=8'd48+(final_percent==7'd100 ? 7'd0:score_ones);
            endcase
            font_x=extra_x[3:1]; font_y=extra_y[3:1];
            pixels=glyph_row(extra_char,font_y);
            if (font_x<5 && pixels[4-font_x]) rgb=16'h07E0;
        end
        // Common volume indicator on every page, including live and guided play.
        if (mode!=7 && y>=9'd5 && y<9'd19 && x>=10'd312 && x<10'd360) begin
            vol_x=x-10'd312; vol_y=y-9'd5;
            font_x=vol_x[3:1];
            font_y=vol_y[3:1];
            case (vol_x[5:4])
                0:text_character="V";
                1:text_character="O";
                default:text_character="L";
            endcase
            pixels=glyph_row(text_character,font_y);
            if (font_x<5 && pixels[4-font_x]) rgb=16'hFFFF;
        end
        if (mode!=7 && x>=10'd370 && x<10'd470 && y>=9'd5 && y<9'd22) begin
            rgb=16'hFFFF;
            if (x>=10'd374 && x<10'd466 && y>=9'd9 && y<9'd18)
                rgb=(x-10'd374 < volume_fill) ? 16'h07E0 : 16'h2104;
        end
        // FSR pitch bend 0..255: only live/playback/follow performance pages.
        // The two song-selection pages keep their original clean layout.
        if ((mode==1 || mode==4 || mode==5) &&
            x>=10'd174 && x<10'd294 && y>=9'd5 && y<9'd22) begin
            rgb=16'hFFFF;
            if (x>=10'd177 && x<10'd291 && y>=9'd8 && y<9'd19)
                rgb=16'h2104;
            if (x>=10'd232 && x<10'd288 && y>=9'd9 && y<9'd18)
                rgb=(x-10'd232 < fsr_fill) ? 16'h07E0 : 16'h2104;
            if (x>=10'd180 && x<10'd228 && y>=9'd6 && y<9'd20) begin
                fsr_x=x-10'd180; fsr_y=y-9'd6;
                char_index=fsr_x[5:4];
                font_x=fsr_x[3:1]; font_y=fsr_y[3:1];
                case (char_index)
                    0:text_character="F";
                    1:text_character="S";
                    default:text_character="R";
                endcase
                pixels=glyph_row(text_character,font_y);
                if (font_x<5 && pixels[4-font_x])
                    rgb=fsr_active ? 16'hFFFF : 16'hBDF7;
            end
        end
        // AT BP M0: triangle / pulse / single. S=sine, P=pulse;
        // M1=split H1..H4/H5..H8, M2=both timbres on each key.
        if (((mode==1 || mode==4) &&
             x>=10'd12 && x<10'd140 &&
             y>=9'd5 && y<9'd19) ||
            (mode==5 && x>=10'd350 && x<10'd478 &&
             y>=9'd253 && y<9'd267)) begin
            if (mode==5) begin
                status_x=x-10'd350; status_y=y-9'd253;
            end else begin
                status_x=x-10'd12; status_y=y-9'd5;
            end
            char_index=status_x[6:4];
            font_x=status_x[3:1]; font_y=status_y[3:1];
            case (char_index)
                0:text_character="A";
                1:case (timbre_a)
                    0:text_character="T"; 1:text_character="S";
                    default:text_character="P";
                endcase
                3:text_character="B";
                4:case (timbre_b)
                    0:text_character="T"; 1:text_character="S";
                    default:text_character="P";
                endcase
                6:text_character="M";
                7:text_character=8'd48+{6'd0,voice_mode};
                default:text_character=" ";
            endcase
            pixels=glyph_row(text_character,font_y);
            if (font_x<5 && pixels[4-font_x]) rgb=16'hFFFF;
        end
        // Compact top indicators: V = vibrato, D = 128 ms echo,
        // B = 120 BPM metronome enabled, only on performance pages.
        if ((mode==1 || mode==4 || mode==5) &&
            y>=9'd5 && y<9'd19) begin
            if (x>=10'd296 && x<10'd312) begin
                effect_x=x-10'd296; effect_y=y-9'd5;
                font_x=effect_x[3:1]; font_y=effect_y[3:1];
                case(effect_mode)
                    1:text_character="V";
                    2:text_character="D";
                    default:text_character="-";
                endcase
                pixels=glyph_row(text_character,font_y);
                if (font_x<5 && pixels[4-font_x]) rgb=16'hFFFF;
            end
            if (metronome && x>=10'd150 && x<10'd166) begin
                effect_x=x-10'd150; effect_y=y-9'd5;
                font_x=effect_x[3:1]; font_y=effect_y[3:1];
                pixels=glyph_row("B",font_y);
                if (font_x<5 && pixels[4-font_x]) rgb=16'h07E0;
            end
        end
    end
endmodule
