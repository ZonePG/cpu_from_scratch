module pc_reg(input wire clk,
              input wire rst,
              output reg[`InstAddrBus] pc,
              output reg ce); // 指令存储器使能信号
    
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            ce <= `ChipDisable; // 在复位信号有效的时候，指令存储器使能信号无效
        end else begin
            ce <= `ChipEnable; // 复位信号无效的时候，指令存储器使能信号有效
        end
    end
    
    always @(posedge clk) begin
        if (ce == `ChipDisable) begin
            pc <= `ZeroWord;    // 指令存储器使能信号有效时，pc保持为0
        end else begin
            pc <= pc + 4'h4;       // 指令存储器使能时，pc的值每时钟周期加4
        end
    end

endmodule
