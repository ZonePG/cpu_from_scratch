module rom (input wire ce,
            input wire[5:0] addr,   // 要读取的指令地址
            output reg[31:0] inst); // 读出的指令
    reg[31:0] rom[63:0];

    initial begin
        $readmemh("../testdata/rom.data", rom);
    end

    always @(*) begin
        if (ce == 1'b0) begin
            inst <= 32'h0;
        end else begin
            inst <= rom[addr];
        end
    end
endmodule
