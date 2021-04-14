module inst_fetch_tb;

    /*iverilog */
    initial
    begin            
        $dumpfile("wave.vcd");        //生成的vcd文件名称
        $dumpvars(0, inst_fetch_tb);    //tb模块名称
    end
    /*iverilog */

    /*
     * 第一段：数据说明
     */
    reg clk;    // 激励信号 clk
    reg rst;    // 激励信号 rst
    wire[31:0] inst; // 显示信号 inst, 取出的指令

    /*
     * 第二段：激励向量定义
     */
    // 定义 clk，每隔 10 个时间单位，翻转，即 50 MHz的时钟
    // 仿真的时候，一个时间单位默认是 1ns
    initial begin
        clk = 1'b0;
        forever begin
            #10 clk = ~clk;
        end
    end

    // 定义 rst 信号，最开始为 1，复位有效，过了 195个时间单位
    // 设置 rst 信号的值为0， 复位信号无效，复位结束，再运行1000ns，暂停仿真
    initial begin
        rst = 1'b1;
        #195 rst = 1'b0;
        #1000 $stop;
    end


    /*
     * 第三段：待测试模块实例化
     */
    inst_fetch inst_fetch0(
        .clk(clk),
        .rst(rst),
        .inst_o(inst)
    );
    
endmodule
