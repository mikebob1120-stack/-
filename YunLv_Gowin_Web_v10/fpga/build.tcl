# Optional command-line build: gw_sh build.tcl
set project_dir [file dirname [file normalize [info script]]]
cd $project_dir
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
add_file -type verilog rtl/pcf8574_keys.v
add_file -type verilog rtl/play_core.v
add_file -type verilog rtl/follow_rhythm_score.v
add_file -type verilog rtl/instrument_ctrl_uart.v
add_file -type verilog rtl/upload_uart.v
add_file -type verilog rtl/phone_control_bridge.v
add_file -type verilog rtl/upload_sd_bridge.v
add_file -type verilog rtl/lcd_menu_keys.v
add_file -type verilog rtl/lcd_menu_pixels.v
add_file -type verilog rtl/lcd_cover_ram.v
add_file -type verilog rtl/lcd_notes_480x272.v
add_file -type verilog rtl/sd_spi_reader.v
add_file -type verilog rtl/sd_wav_player.v
add_file -type verilog rtl/play_lcd_top.v
add_file -type cst constraints/play_lcd.cst
add_file -type sdc constraints/play_lcd.sdc
set_option -synthesis_tool gowinsynthesis
set_option -top_module play_lcd_top
set_option -output_base_name httm_sd_follow
set_option -verilog_std v2001
set_option -use_sspi_as_gpio 1
set_option -use_mode_as_gpio 1
run all
