module pc_reg(input wire clk,
              input wire rst,
              output reg[5:0] pc,
              output reg ce); // 指令存储器使能信号
    
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            ce <= 1'b0; // 在复位信号有效的时候，指令存储器使能信号无效
        end else begin
            ce <= 1'b1; // 复位信号无效的时候，指令存储器使能信号有效
        end
    end
    
    always @(posedge clk) begin
        if (ce == 1'b0) begin
            pc <= 6'h00;    // 指令存储器使能信号有效时，pc保持为0
        end else begin
            pc <= pc + 1'b1;
        end
    end

endmodule
