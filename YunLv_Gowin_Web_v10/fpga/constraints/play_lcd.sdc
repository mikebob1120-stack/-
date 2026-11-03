# MS5351 CLK1, already enabled from speaker/keyboard tests: O1=24576K.
create_clock -name clk24m -period 40.690 [get_ports {clk24m}]
# MS5351 CLK0, enable separately from BL616: O0=9M.
create_clock -name clk9m -period 111.111 [get_ports {clk9m}]
set_clock_groups -asynchronous -group [get_clocks {clk24m}] -group [get_clocks {clk9m}]
