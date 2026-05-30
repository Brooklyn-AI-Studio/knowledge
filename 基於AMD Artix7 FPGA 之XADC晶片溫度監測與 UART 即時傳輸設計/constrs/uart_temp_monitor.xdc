############## 50MHz Clock ##############
create_clock -period 20.000 -name CLK_50M [get_ports CLK_50M]

set_property PACKAGE_PIN J19 [get_ports CLK_50M]
set_property IOSTANDARD LVCMOS33 [get_ports CLK_50M]

############## Reset ##############
set_property PACKAGE_PIN L18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

############## Key ##############
set_property PACKAGE_PIN AA1 [get_ports key_in]
set_property IOSTANDARD LVCMOS33 [get_ports key_in]

############## LED ##############
set_property PACKAGE_PIN N18 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

############## UART TX ##############
set_property PACKAGE_PIN V2 [get_ports rs232_tx]
set_property IOSTANDARD LVCMOS33 [get_ports rs232_tx]

############## Unused Pins ##############
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]