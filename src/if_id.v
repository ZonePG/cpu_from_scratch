module if_id (
    input wire clk,
    input wire rst,

    // 来自取指阶段的信号，其中宏定义InstBus表示指令宽度，为32
    input wire[`InstAddrBus] if_pc,
    input wire[`InstBus] if_inst,

    input wire[5:0] stall,

    // 对应译码阶段的信号
    output reg[`InstAddrBus] id_pc,
    output reg[`InstBus] id_inst
);
    // (1) stall[1]为Stop时，stall[2]为NoStop时，表示取指阶段暂停，译码阶段继
    // 续，使用空指令作为下一个周期进入译码阶段的指令
    // (2) stall[2]为NoStop时，取指阶段继续，取得的指令进入译码阶段
    // (3) 其余情况，保持不变
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
        end else if (stall[1] == `Stop && stall[2] == `NoStop) begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
        end else if (stall[1] == `NoStop) begin
            id_pc <= if_pc;    // 其余时刻向下传递取值阶段的值
            id_inst <= if_inst;
        end
    end

endmodule
