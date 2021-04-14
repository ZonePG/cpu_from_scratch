module regfile (
    input wire clk,
    input wire rst,

    // 写端口
    input wire we,
    input wire[`RegAddrBus] waddr, // 要写入的寄存器地址
    input wire[`RegBus] wdata,     // 要写入的数据

    // 读端口 1
    input wire re1,
    input wire[`RegAddrBus] raddr1, // 第一个读寄存器端口要读取的寄存器的地址
    output reg[`RegBus] rdata1,     // 第一个读寄存器端口输出的寄存器值

    // 读端口 2
    input wire re2,
    input wire[`RegAddrBus] raddr2,
    output reg[`RegBus] rdata2
);

    /*
     * 第一段：定义 32 个 32 位寄存器
     */
    reg[`RegBus] regs[0: `RegNum - 1];

    /*
     * 第二段：写操作
     */
    always @(posedge clk) begin
        if (rst == `RstDisable) begin
            if ((we == `WriteEnable) && (waddr != `RegNumLog2'h0)) begin
                regs[waddr] <= wdata;
            end
        end
    end

    /*
     * 第三段：读端口 1 的操作
     */
    always @(*) begin
        if (rst == `RstEnable) begin
            rdata1 <= `ZeroWord;
        end else if (raddr1 == `RegNumLog2'h0) begin
            rdata1 <= `ZeroWord;
        end else if ((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable)) begin
            rdata1 <= wdata;
        end else if (re1 == `ReadEnable) begin
            rdata1 <= regs[raddr1];
        end else begin
            rdata1 <= `ZeroWord;
        end
    end

    /*
     * 第四段：读端口 2 的操作
     */
    always @(*) begin
        if (rst == `RstEnable) begin
            rdata2 <= `ZeroWord;
        end else if (raddr2 == `RegNumLog2'h0) begin
            rdata2 <= `ZeroWord;
        end else if ((raddr2 == waddr) && (we == `WriteEnable) && (re2 == `ReadEnable)) begin
            rdata2 <= wdata;
        end else if (re2 == `ReadEnable) begin
            rdata2 <= regs[raddr2];
        end else begin
            rdata2 <= `ZeroWord;
        end
    end

endmodule