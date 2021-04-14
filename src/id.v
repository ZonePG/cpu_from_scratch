module id(
    input wire rst,
    input wire[`InstAddrBus] pc_i, // 译码阶段的指令对应的地址
    input wire[`InstBus] inst_i,   // 译码阶段的指令

    // 读取的Regfile的值
    input wire[`RegBus] reg1_data_i, // 从 Regfile输入的第一个读寄存器端口的输入
    input wire[`RegBus] reg2_data_i, // 从 Regfile输入的第二个读寄存器端口的输入

    // 处于执行阶段的指令的运算结果
    input wire ex_wreg_i,
    input wire[`RegBus] ex_wdata_i,
    input wire[`RegAddrBus] ex_wd_i,

    // 处于访存阶段的指令的运算结果
    input wire mem_wreg_i,
    input wire[`RegBus] mem_wdata_i,
    input wire[`RegAddrBus] mem_wd_i,

    // 输出到 Regfile 的信息
    output reg reg1_read_o, // Regfile 模块的第一个读寄存器端口的读使能信号
    output reg reg2_read_o, // Regfile 模块的第二个读寄存器端口的读使能信号
    output reg[`RegAddrBus] reg1_addr_o,  // Regfile 模块的第一个读寄存器端口的读地址信号
    output reg[`RegAddrBus] reg2_addr_o,  // Regfile 模块的第二个读寄存器端口的读地址信号

    // 送到执行阶段的信息
    output reg[`AluOpBus] aluop_o, // 译码阶段的指令要进行的运算的子类型
    output reg[`AluSelBus] alusel_o, // 译码阶段的指令要进行的运算的类型
    output reg[`RegBus] reg1_o, // 译码阶段的指令要进行的源操作数1
    output reg[`RegBus] reg2_o, // 译码阶段的指令要进行的源操作数2
    output reg[`RegAddrBus] wd_o, // 译码阶段的指令要写入的目的寄存器地址
    output reg wreg_o // 译码阶段的指令是否有要写入的目的寄存器
);
    // 取得指令的指令码，功能码
    // 对于 ori 指令只需通过判断26-31bit的值，即可判断是否是ori指令
    wire[5:0] op = inst_i[31:26]; // 指令码
    wire[4:0] op2 = inst_i[10:6];
    wire[5:0] op3 = inst_i[5:0];  // 功能码
    wire[4:0] op4 = inst_i[20:16];

    // 保存指令执行所需要的立即数
    reg[`RegBus] imm;

    // 指示指令是否有效
    reg instvalid;

    /************** 第一段：对指令进行译码 *************/
    always @(*) begin
        if (rst == `RstEnable) begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            wd_o <= `NOPRegAddr;
            wreg_o <= `WriteDisable;
            instvalid <= `InstInvalid;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= `NOPRegAddr;
            reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
        end else begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            wd_o <= inst_i[15:11];  // 默认目的寄存地址 wd_o
            wreg_o <= `WriteDisable;
            instvalid <= `InstInvalid;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= inst_i[25:21];   // 默认通过Regfile读端口1读取的寄存器地址
            reg2_addr_o <= inst_i[20:16];   // 默认通过Regfile读端口2读取的寄存器地址
            imm <= `ZeroWord;

            case (op)
                `EXE_SPECIAL_INST: begin    // 指令码是 SPECIAL
                    case (op2)
                        5'b00000: begin
                            case (op3)  // 依据功能码判断是哪种指令
                                `EXE_OR: begin // or 指令
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_OR_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_AND: begin // and 指令
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_AND_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_XOR: begin // xor指令
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_XOR_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_NOR: begin // nor 指令
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_NOR_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SLLV: begin // sllv 指令
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SLL_OP;
                                    alusel_o <= `EXE_RES_SHIFT;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SRLV: begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SRL_OP;
                                    alusel_o <= `EXE_RES_SHIFT;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SRAV: begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SRA_OP;
                                    alusel_o <= `EXE_RES_SHIFT;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SYNC: begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_NOP_OP;
                                    alusel_o <= `EXE_RES_SHIFT;
                                    reg1_read_o <= 1'b0;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MFHI: begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_MFHI_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b0;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MFLO: begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_MFLO_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b0;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MTHI: begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_MTHI_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MTLO: begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_MTLO_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MOVN: begin
                                    aluop_o <= `EXE_MOVN_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                    // reg2_o 的值就是地址为 rt 的寄存器的值
                                    if (reg2_o != `ZeroWord) begin
                                        wreg_o <= `WriteEnable;
                                    end else begin
                                        wreg_o <= `WriteDisable;
                                    end
                                end
                                `EXE_MOVZ: begin
                                    aluop_o <= `EXE_MOVZ_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                    // reg2_o 的值就是地址为 rt 的寄存器的值
                                    if (reg2_o == `ZeroWord) begin
                                        wreg_o <= `WriteEnable;
                                    end else begin
                                        wreg_o <= `WriteDisable;
                                    end
                                end
                                default: begin
                                end
                            endcase
                        end
                        default: begin
                        end
                    endcase
                end
                `EXE_ORI: begin // 依据 op 的值判断是否是 ori 指令
                    // ori 指令需要将结果写入目的寄存器，所以 wreg_o 为 WriteEnbale
                    wreg_o <= `WriteEnable;
                    // 运算的子类型是逻辑“或”运算
                    aluop_o <= `EXE_OR_OP;
                    // 运算类型是逻辑运算
                    alusel_o <= `EXE_RES_LOGIC;
                    // 需要通过 Regfile 的读端口 1 读取寄存器
                    reg1_read_o <= 1'b1;
                    // 不需要通过 Regfile 的读端口 2 读取寄存器
                    reg2_read_o <= 1'b0;
                    // 指令执需要的立即数
                    imm <= {16'h0, inst_i[15:0]};
                    // 执行指令要写的目的寄存器地址
                    wd_o <= inst_i[20:16];
                    // ori 指令是有效指令
                    instvalid <= `InstValid;
                end
                `EXE_ANDI: begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_AND_OP;
                    alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {16'h0, inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_XORI: begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_XOR_OP;
                    alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {16'h0, inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_LUI: begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_OR_OP;
                    alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {inst_i[15:0], 16'h0};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_PREF: begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_NOP_OP;
                    alusel_o <= `EXE_RES_NOP;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b0;
                    instvalid <= `InstValid;
                end
                default: begin
                end
            endcase // case op

            if (inst_i[31:21] == 11'b00000000000) begin
                if (op3 == `EXE_SLL) begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SLL_OP;
                    alusel_o <= `EXE_RES_SHIFT;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b1;
                    imm[4:0] <= inst_i[10:6];
                    instvalid <= `InstValid;
                end else if(op3 == `EXE_SRL) begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SRL_OP;
                    alusel_o <= `EXE_RES_SHIFT;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b1;
                    imm[4:0] <= inst_i[10:6];
                    instvalid <= `InstValid;
                end else if(op3 == `EXE_SRA) begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SRA_OP;
                    alusel_o <= `EXE_RES_SHIFT;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b1;
                    imm[4:0] <= inst_i[10:6];
                    instvalid <= `InstValid;
                end
            end
        end // if
    end // always


    /*************** 第二段：确定进行位运算的源操作数 1 ****************/
    // 给 reg1_o 赋值的过增加了两种情况
    // 1. 如果 Regfile 模块读端口 1 要读取的寄存器就是执行阶段要写的目的寄存器，
    //      那么直接把执行阶段的结果 ex_wdata_i 作为 reg1_o 的值
    // 2. 如果 Regfile 模块读端口 1 要读取的寄存器就是访存阶段要写的目的寄存器，
    //      那么直接把访存阶段的结果 mem_wdata_i 作为 reg1_o 的值
    always @(*) begin
        if (rst == `RstEnable) begin
            reg1_o <= `ZeroWord;
        end else if ((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o)) begin
            reg1_o <= ex_wdata_i;
        end else if ((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o)) begin
            reg1_o <= mem_wdata_i;
        end else if (reg1_read_o == 1'b1) begin
            reg1_o <= reg1_data_i;  // Regfile读端口 1 的输出值
        end else if (reg1_read_o == 1'b0) begin
            reg1_o <= imm;  // 立即数
        end else begin
            reg1_o <= `ZeroWord;
        end
    end

    /*************** 第二段：确定进行位运算的源操作数 2 ****************/
    // 给 reg2_o 赋值的过程增加了两种情况
    // 1. 如果 Regfile 模块读端口 2 要读取的寄存器就是执行阶段要写的目的寄存器，
    //      那么直接把执行阶段的结果 ex_wdata_i 作为 reg2_o 的值
    // 2. 如果 Regfile 模块读端口 2 要读取的寄存器就是访存阶段要写的目的寄存器，
    //      那么直接把访存阶段的结果 mem_wdata_i 作为 reg2_o 的值
    always @(*) begin
        if (rst == `RstEnable) begin
            reg2_o <= `ZeroWord;
        end else if ((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o)) begin
            reg2_o <= ex_wdata_i;
        end else if ((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o)) begin
            reg2_o <= mem_wdata_i;
        end else if (reg2_read_o == 1'b1) begin
            reg2_o <= reg2_data_i;  // Regfile读端口 2 的输出值
        end else if (reg2_read_o == 1'b0) begin
            reg2_o <= imm;  // 立即数
        end else begin
            reg2_o <= `ZeroWord;
        end
    end

endmodule