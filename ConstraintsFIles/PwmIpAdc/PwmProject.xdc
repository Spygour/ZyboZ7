# Pin assignments
set_property PACKAGE_PIN V15 [get_ports Pwm_OutPort_0[0]]
set_property IOSTANDARD LVCMOS33 [get_ports Pwm_OutPort_0[0]]
set_property SLEW FAST [get_ports Pwm_OutPort_0[0]]
set_property DRIVE 8 [get_ports Pwm_OutPort_0[0]]

set_property PACKAGE_PIN W15 [get_ports Pwm_OutPort_0[1]]
set_property IOSTANDARD LVCMOS33 [get_ports Pwm_OutPort_0[1]]
set_property SLEW FAST [get_ports Pwm_OutPort_0[1]]
set_property DRIVE 8 [get_ports Pwm_OutPort_0[1]]

set_property PACKAGE_PIN T11 [get_ports Pwm_OutPort_0[2]]
set_property IOSTANDARD LVCMOS33 [get_ports Pwm_OutPort_0[2]]
set_property SLEW FAST [get_ports Pwm_OutPort_0[2]]
set_property DRIVE 8 [get_ports Pwm_OutPort_0[2]]

set_property PACKAGE_PIN T14 [get_ports Pwm_OutPort_LSS_0[0]]
set_property IOSTANDARD LVCMOS33 [get_ports Pwm_OutPort_LSS_0[0]]
set_property SLEW FAST [get_ports Pwm_OutPort_LSS_0[0]]
set_property DRIVE 8 [get_ports Pwm_OutPort_LSS_0[0]]

set_property PACKAGE_PIN T15 [get_ports Pwm_OutPort_LSS_0[1]]
set_property IOSTANDARD LVCMOS33 [get_ports Pwm_OutPort_LSS_0[1]]
set_property SLEW FAST [get_ports Pwm_OutPort_LSS_0[1]]
set_property DRIVE 8 [get_ports Pwm_OutPort_LSS_0[1]]

set_property PACKAGE_PIN P14 [get_ports Pwm_OutPort_LSS_0[2]]
set_property IOSTANDARD LVCMOS33 [get_ports Pwm_OutPort_LSS_0[2]]
set_property SLEW FAST [get_ports Pwm_OutPort_LSS_0[2]]
set_property DRIVE 8 [get_ports Pwm_OutPort_LSS_0[2]]

set_property PACKAGE_PIN N15 [get_ports vp_in_0]

set_property PACKAGE_PIN N16 [get_ports vn_in_0]

# output delays
set_output_delay -clock [get_clocks clk_fpga_0] 0.100 [get_ports {Pwm_OutPort_0[0]}]
set_output_delay -clock [get_clocks clk_fpga_0] 0.100 [get_ports {Pwm_OutPort_0[1]}]
set_output_delay -clock [get_clocks clk_fpga_0] 0.100 [get_ports {Pwm_OutPort_0[2]}]
set_output_delay -clock [get_clocks clk_fpga_0] 0.100 [get_ports {Pwm_OutPort_LSS_0[0]}]
set_output_delay -clock [get_clocks clk_fpga_0] 0.100 [get_ports {Pwm_OutPort_LSS_0[1]}]
set_output_delay -clock [get_clocks clk_fpga_0] 0.100 [get_ports {Pwm_OutPort_LSS_0[2]}]
