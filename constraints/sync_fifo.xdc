#-------------------------------------------------------------------------------
# File        : sync_fifo.xdc
# Description : Xilinx Vivado timing constraints for Synchronous FIFO (8-bit x 16)
# Target      : Generic Artix-7 (e.g., xc7a35tcpg236-1)
#-------------------------------------------------------------------------------

# Primary system clock: 100 MHz (10.000 ns period, 50% duty cycle)
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# Clock uncertainty margin for synthesis timing analysis
set_clock_uncertainty 0.200 [get_clocks sys_clk]

# Input delay constraints relative to sys_clk (example 2.0 ns max / 0.5 ns min)
set_input_delay -clock sys_clk -max 2.000 [get_ports {rst wr_en rd_en wr_data[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {rst wr_en rd_en wr_data[*]}]

# Output delay constraints relative to sys_clk (example 2.0 ns max / 0.5 ns min)
set_output_delay -clock sys_clk -max 2.000 [get_ports {rd_data[*] full empty}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {rd_data[*] full empty}]

#-------------------------------------------------------------------------------
# Optional Board Pin Mapping (Uncomment and adapt for target FPGA board)
#-------------------------------------------------------------------------------
# set_property IOSTANDARD LVCMOS33 [get_ports {clk rst wr_en rd_en full empty}]
# set_property IOSTANDARD LVCMOS33 [get_ports {wr_data[*] rd_data[*]}]

