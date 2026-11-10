@echo off
setlocal

echo ============================================================================
echo  Vivado XSIM RTL Simulation - Synchronous FIFO (8-bit x 16)
echo ============================================================================

xvlog ^
    ../rtl/fifo_ctrl.v ^
    ../rtl/fifo_wr_ptr.v ^
    ../rtl/fifo_rd_ptr.v ^
    ../rtl/fifo_status.v ^
    ../rtl/fifo_memory.v ^
    ../rtl/sync_fifo_top.v ^
    ../testbench/tb_sync_fifo.v
if errorlevel 1 (
    echo [ERROR] xvlog compilation failed.
    exit /b %errorlevel%
)

xelab -debug typical tb_sync_fifo -s tb_sync_fifo_sim
if errorlevel 1 (
    echo [ERROR] xelab elaboration failed.
    exit /b %errorlevel%
)

xsim tb_sync_fifo_sim -tclbatch run_xsim.tcl -log xsim_simulation.log
if errorlevel 1 (
    echo [ERROR] xsim execution failed.
    exit /b %errorlevel%
)

echo ============================================================================
echo  Simulation completed. Review xsim_simulation.log and tb_sync_fifo_sim.wdb
echo  Open waveform in GUI: xsim --gui tb_sync_fifo_sim.wdb -view tb_sync_fifo_behav.wcfg
echo ============================================================================
endlocal

