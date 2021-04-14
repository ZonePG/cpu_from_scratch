% Start compiling %
iverilog -o wave pc_reg.v rom.v inst_fetch.v inst_fetch_tb.v
% Generating wave file %
vvp -n wave -lxt2
% Opening wave file %
gtkwave wave.vcd