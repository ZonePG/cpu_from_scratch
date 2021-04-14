module inst_fetch (input wire clk,
                   input wire rst,
                   output wire[31:0] inst_o);
    wire[5:0] pc;
    wire rom_ce;
    
    // PC 模块的实例化
    pc_reg pc_reg0(.clk(clk), .rst(rst), .pc(pc), .ce(rom_ce));
    
    // 指令存储器ROM的实例化
    rom rom0(.ce(rom_ce), .addr(pc), .inst(inst_o));
    
endmodule
