# Vivado Board Files for Digilent FPGA Boards

This repository contains custom ips and their kernel/vitis code examples that can be used by zybo z710 and z720 boards. Zybo reference manual can be found [here](https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual).
 ## Files existed inside this repo
  | Folder Name | Description |
|-------------|------------|
| ConstraintsFiles         | Files that can be used as contraint files for synthesis on vivado |
| HardwareLibraries      | Vhdl and Verilog files that you can use to make custom ips |
| Kernel Modules  | Linux Kernel modules which uses the ips from HardwareLibraries |
| PedalBoardProject       | Vitis code for custom i2s effects pedal ip (HardwareLibraries/PedalBoard) |
| UserSpace       | UserSpace projects on linux using the known ips and kernel modules |
