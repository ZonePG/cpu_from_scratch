% Start compiling %
% iverilog -o  %
iverilog -o wave def.v pc_reg.v if_id.v id.v regfile.v id_ex.v ex.v ex_mem.v mem.v mem_wb.v openmips.v inst_rom.v openmips_min_sopc.v openmips_min_sopc_tb.v
% Generating wave file %
vvp -n wave -lxt2 %
% Opening wave file %
gtkwave wave.vcd %