#-------------------------------------------------------------------------------
# File        : create_vivado_project.tcl
# Description : Creates a Vivado GUI project (.xpr) with RTL sources,
#               testbench, waveform configuration, and XDC constraints.
# Usage       : In Vivado Tcl Console: source create_vivado_project.tcl
#-------------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ".."]]
set vivado_dir [file join $script_dir "vivado_project"]

if {[info exists ::env(VIVADO_PART)] && $::env(VIVADO_PART) ne ""} {
    set fpga_part $::env(VIVADO_PART)
} else {
    set fpga_part "xc7a35tcpg236-1"
}

create_project sync_fifo_vivado $vivado_dir -part $fpga_part -force

# Add RTL design sources
add_files -fileset sources_1 [list \
    [file join $proj_root "rtl" "fifo_ctrl.v"] \
    [file join $proj_root "rtl" "fifo_wr_ptr.v"] \
    [file join $proj_root "rtl" "fifo_rd_ptr.v"] \
    [file join $proj_root "rtl" "fifo_status.v"] \
    [file join $proj_root "rtl" "fifo_memory.v"] \
    [file join $proj_root "rtl" "sync_fifo_top.v"] \
]
set_property top sync_fifo_top [get_filesets sources_1]

# Add simulation testbench and waveform configuration
add_files -fileset sim_1 [list \
    [file join $proj_root "testbench" "tb_sync_fifo.v"] \
    [file join $proj_root "simulation" "tb_sync_fifo_behav.wcfg"] \
]
set_property top tb_sync_fifo [get_filesets sim_1]

# Add timing constraints
add_files -fileset constrs_1 [file join $proj_root "constraints" "sync_fifo.xdc"]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: Vivado project created at $vivado_dir"

