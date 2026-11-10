#-------------------------------------------------------------------------------
# File        : run_xsim.tcl
# Description : Vivado XSIM Tcl batch script to capture full hierarchy waveforms
#               (.wdb) and execute tb_sync_fifo to completion.
#-------------------------------------------------------------------------------
log_wave -recursive *
run all
quit

