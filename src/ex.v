module ex (
    input wire rst,

    // 译码阶段送到执行阶段的信息
    input wire[`AluOpBus] aluop_i,
    input wire[`AluSelBus] alusel_i,
    input wire[`RegBus] reg1_i,
    input wire[`RegBus] reg2_i,
    input wire[`RegAddrBus] wd_i,
    input wire wreg_i,

    // HILO 模给出的HI、LO寄存器的值
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,

    // 回写阶段的指令是否要写HI、LO，用于检测HI、LO寄存器带来的数据相关问题
    input wire[`RegBus] wb_hi_i,
    input wire[`RegBus] wb_lo_i,
    input wire          wb_whilo_i,

    // 访存阶段的指令是否要写HI、LO，用于检测HI、LO寄存器带来的数据相关问题
    input wire[`RegBus] mem_hi_i,
    input wire[`RegBus] mem_lo_i,
    input wire          mem_whilo_i,

    input wire[`DoubleRegBus] hilo_temp_i, // 第一个执行周期得到的乘法结果
    input wire[1:0] cnt_i,                 // 当前处于执行阶段的第几个时钟周期

    // 执行的结果
    output reg[`RegAddrBus] wd_o, // 执行阶段的指令最终要写入的目的寄存器地址
    output reg wreg_o,            // 执行阶段的指令是否有要写入的目的寄存器
    output reg[`RegBus] wdata_o, // 执行阶段的指令最终要写入的目的寄存器的值

    // 处于执行阶段的指令对HI、LO寄存器的写操作请求
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    output reg          whilo_o,

    output reg[`DoubleRegBus] hilo_temp_o, // 第一个执行周期得到的乘法结果
    output reg[1:0] cnt_o,                 // 下一个时钟周期处于执行阶段的第几个时钟周期

    output reg stallreq
);

    // 保存逻辑运算的结果
    reg[`RegBus] logicout;  // 逻辑操作的结果
    reg[`RegBus] shiftres;  // 移位操作的结果
    reg[`RegBus] moveres;   // 移动操作的结果
    reg[`RegBus] HI;        // 保存 HI 寄存器的最新值
    reg[`RegBus] LO;        // 保存 LO 寄存器的最新值

    wire ov_sum;            // 保存溢出情况
    wire reg1_eq_reg2;      // 第一个操作数是否等于第二个操作数
    wire reg1_lt_reg2;      // 第一个操作数是否小于第二个操作数
    reg[`RegBus] arithmeticres; // 保存算数运算的结构
    wire[`RegBus] reg2_i_mux;    // 保存输入的第二个操作数 reg2_i 的补码
    wire[`RegBus] reg1_i_not;    // 保存输入的第一个操作数 reg1_i 的反码
    wire[`RegBus] result_sum;    // 保存假发结果
    wire[`RegBus] opdata1_mult;  // 乘法操作中的被乘数
    wire[`RegBus] opdata2_mult;  // 乘法操作中的乘数
    wire[`DoubleRegBus] hilo_temp; // 临时保存乘法结果，宽度为 64 位
    reg[`DoubleRegBus] hilo_temp1;
    reg stallreq_for_madd_msub;
    reg[`DoubleRegBus] mulres;     // 保存乘法结果，宽度为 64 位

    /*************** 进行逻辑运算 ***********/
    always @(*) begin
        if (rst == `RstEnable) begin
            logicout <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_OR_OP: begin
                    logicout <= reg1_i | reg2_i;
                end
                `EXE_AND_OP: begin
                    logicout <= reg1_i & reg2_i;
                end
                `EXE_NOR_OP: begin
                    logicout <= ~(reg1_i | reg2_i);
                end
                `EXE_XOR_OP: begin
                    logicout <= reg1_i ^ reg2_i;
                end
                default: begin
                    logicout <= `ZeroWord;
                end
            endcase
        end // if
    end // always

    always @(*) begin
        if (rst == `RstEnable) begin
            shiftres <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_SLL_OP: begin
                    shiftres <= reg2_i << reg1_i[4:0];
                end
                `EXE_SRL_OP: begin
                    shiftres <= reg2_i >> reg1_i[4:0];
                end
                `EXE_SRA_OP: begin
                    shiftres <= ({32{reg2_i[31]}} << (6'd32-{1'b0, reg1_i[4:0]})) | reg2_i >> reg1_i[4:0];
                end
                default: begin
                    shiftres <= `ZeroWord;
                end
            endcase
        end // if
    end // always



    /*****************************************************************************
    **       第一段：得到最新的HI、LO寄存器的值，此处要解决数据相关问题                   **
    *****************************************************************************/
    always @(*) begin
        if (rst == `RstEnable) begin
            {HI, LO} <= {`ZeroWord, `ZeroWord};
        end else if (mem_whilo_i == `WriteEnable) begin
            {HI, LO} <= {mem_hi_i, mem_lo_i};
        end else if (wb_whilo_i == `WriteEnable) begin
            {HI, LO} <= {wb_hi_i, wb_lo_i};
        end else begin
            {HI, LO} <= {hi_i, lo_i};
        end
    end

    /*****************************************************************************
    **       第一段：计算以下 5 个变量的值                                      **
    *****************************************************************************/
    // (1) 减法或有符号比较运算
    assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) ||
                         (aluop_i == `EXE_SUBU_OP) ||
                         (aluop_i == `EXE_SLT_OP)) ?
                         (~reg2_i) + 1 : reg2_i;
     
    // (2) 满足加法运算、减法运算、有符号比较运算
    assign result_sum = reg1_i + reg2_i_mux;

    // (3) 计算溢出
    // A. reg1_i 为正数，reg2_i_mux 为正数，和为负数
    // B. reg1_i 为负数，reg2_i_mux 为负数，但是两者之和为正数
    assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31])
    || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

    // (4) 计算操作数 1 是否小于操作数 2
    // A.有符号比较：(负，正), (正，正)，(负，正)
    // B. 无符号数比较，直接比较
    assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP)) ?
                        ((reg1_i[31] && !reg2_i[31]) ||
                        (!reg1_i[31] && !reg2_i[31] && result_sum[31]) ||
                        (reg1_i[31] && reg2_i[31] && result_sum[31]))
                        : (reg1_i < reg2_i);

    // (5) 对操作数 1 逐位取反。赋给 reg1_i_not
    assign reg1_i_not = ~reg1_i;

    /*****************************************************************************
    **       第二段：依据不同的算术运算类型，给arithmeticres变量赋值            **
    *****************************************************************************/

    always @ (*) begin
        if (rst == `RstEnable) begin
            arithmeticres <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_SLT_OP, `EXE_SLTU_OP: begin
                    arithmeticres <= reg1_lt_reg2;
                end
                `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP: begin
                    arithmeticres <= result_sum;
                end
                `EXE_SUB_OP, `EXE_SUBU_OP: begin
                    arithmeticres <= result_sum;
                end
                `EXE_CLZ_OP: begin
                    arithmeticres <= reg1_i[31] ? 0 : reg1_i[30] ? 1 :
                                     reg1_i[29] ? 2 : reg1_i[28] ? 3 :
                                     reg1_i[27] ? 4 : reg1_i[26] ? 5 :
                                     reg1_i[25] ? 6 : reg1_i[24] ? 7 :
                                     reg1_i[23] ? 8 : reg1_i[22] ? 9 :
                                     reg1_i[21] ? 10 : reg1_i[20] ? 11 :
                                     reg1_i[19] ? 12 : reg1_i[18] ? 13 :
                                     reg1_i[17] ? 14 : reg1_i[16] ? 15 :
                                     reg1_i[15] ? 16 : reg1_i[14] ? 17 :
                                     reg1_i[13] ? 18 : reg1_i[12] ? 19 :
                                     reg1_i[11] ? 20 : reg1_i[10] ? 21 :
                                     reg1_i[9] ? 22 : reg1_i[8] ? 23 :
                                     reg1_i[7] ? 24 : reg1_i[6] ? 25 :
                                     reg1_i[5] ? 26 : reg1_i[4] ? 27 :
                                     reg1_i[3] ? 28 : reg1_i[2] ? 29 :
                                     reg1_i[1] ? 30 : reg1_i[0] ? 31 : 32;
                end
                `EXE_CLO_OP: begin
                    arithmeticres <= reg1_i_not[31] ? 0 : reg1_i_not[30] ? 1 :
                                     reg1_i_not[29] ? 2 : reg1_i_not[28] ? 3 :
                                     reg1_i_not[27] ? 4 : reg1_i_not[26] ? 5 :
                                     reg1_i_not[25] ? 6 : reg1_i_not[24] ? 7 :
                                     reg1_i_not[23] ? 8 : reg1_i_not[22] ? 9 :
                                     reg1_i_not[21] ? 10 : reg1_i_not[20] ? 11 :
                                     reg1_i_not[19] ? 12 : reg1_i_not[18] ? 13 :
                                     reg1_i_not[17] ? 14 : reg1_i_not[16] ? 15 :
                                     reg1_i_not[15] ? 16 : reg1_i_not[14] ? 17 :
                                     reg1_i_not[13] ? 18 : reg1_i_not[12] ? 19 :
                                     reg1_i_not[11] ? 20 : reg1_i_not[10] ? 21 :
                                     reg1_i_not[9] ? 22 : reg1_i_not[8] ? 23 :
                                     reg1_i_not[7] ? 24 : reg1_i_not[6] ? 25 :
                                     reg1_i_not[5] ? 26 : reg1_i_not[4] ? 27 :
                                     reg1_i_not[3] ? 28 : reg1_i_not[2] ? 29 :
                                     reg1_i_not[1] ? 30 : reg1_i_not[0] ? 31 : 32;
                end
                default: begin
                    arithmeticres <= `ZeroWord;
                end
            endcase
        end
    end

    /*****************************************************************************
    **       第三段：乘法运算                                                   **
    *****************************************************************************/
    // (1) 取得乘法运算的被乘数，如果是有符号乘法且被乘数是负数，那么取补码
    assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) ||
                            (aluop_i == `EXE_MULT_OP)) ||
                            (aluop_i == `EXE_MADD_OP) ||
                            (aluop_i == `EXE_MSUB_OP)) &&
                            (reg1_i[31] == 1'b1) ?
                            (~reg1_i + 1) : reg1_i;

    // (2) 取得乘法运算的乘数，如果是有符号乘法且乘数是负数，那么取补码
    assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP)) &&
                            (reg2_i[31] == 1'b1)) ? (~reg2_i + 1) : reg2_i;

    // (3) 得到临时乘法结果，保存在变量hilo_temp中
    assign hilo_temp = opdata1_mult * opdata2_mult;

    // (4) 对临时乘法结果进行修正，最终的乘法结果保存在变量 mulres 中，主要有两点：
    // A. 有符号乘法mult、mul，修正临时乘法结构，如下：
    //    A1. 一正一负：结果求补码
    //    A2. 同号，直接赋值
    // B. 如果无符号乘法指令 multu，那么直接赋值
    always @ (*) begin
        if (rst == `RstEnable) begin
            mulres <= {`ZeroWord, `ZeroWord};
        end else if ((aluop_i == `EXE_MULT_OP) ||
                     (aluop_i == `EXE_MUL_OP) ||
                     (aluop_i == `EXE_MADD_OP) ||
                     (aluop_i == `EXE_MSUB_OP)) begin
            if (reg1_i[31] ^ reg2_i[31] == 1'b1) begin
                mulres <= ~hilo_temp + 1;
            end else begin
                mulres <= hilo_temp;
            end
        end else begin
            mulres <= hilo_temp;
        end
    end

    /*****************************************************************************
    **       第二段：MFHI、MFLO、MOVN、MOVZ指令                                    **
    *****************************************************************************/
    always @(*) begin
        if (rst == `RstEnable) begin
            moveres <= `ZeroWord;
        end else begin
            moveres <= `ZeroWord;
            case (aluop_i)
                `EXE_MFHI_OP: begin
                    // 如果是 mfhi 指令，那么 HI 的值作为移动操作的结果
                    moveres <= HI;
                end
                `EXE_MFLO_OP: begin
                    // 如果是 mflo 指令，那么 LO 的值作为移动操作的结果
                    moveres <= LO;
                end
                `EXE_MOVZ_OP: begin
                    // 如果是 movz 指令，那么 reg1_i 的值作为移动操作的结果
                    moveres <= reg1_i;
                end
                `EXE_MOVN_OP: begin
                    // 如果是 movn 指令，那么 reg1_i 的值作为移动操作的结果
                    moveres <= reg1_i;
                end
                default: begin
                end
            endcase
        end
    end
    
    /*****************************************************************************
    **       第三段：暂停流水线                                                 **
    *****************************************************************************/
    // 目前只有乘累加、乘累减指令会导致流水线的暂停，所以stallreq就直接等于
    // stalstallreq_for_madd_msub的值
    always @ (*) begin
       stallreq = stallreq_for_madd_msub;
    end


    /*****************************************************************************
    **       第二段：乘累加、乘累减                                             **
    *****************************************************************************/
    always @ (*) begin
        if (rst == `RstEnable) begin
            hilo_temp_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;
            stallreq_for_madd_msub = `NoStop;
          end else begin
              case (aluop_i)
                  `EXE_MADD_OP, `EXE_MADDU_OP: begin       // madd、maddu指令
                      if (cnt_i == 2'b00) begin         // 执行阶段第一个时钟周期
                          hilo_temp_o <= mulres;
                          cnt_o <= 2'b01;
                          hilo_temp1 <= {`ZeroWord, `ZeroWord};
                          stallreq_for_madd_msub <= `Stop;
                      end else if (cnt_i == 2'b01) begin
                          hilo_temp_o <= {`ZeroWord, `ZeroWord};
                          cnt_o <= 2'b10;
                          hilo_temp1 <= hilo_temp_i + {HI, LO};
                          stallreq_for_madd_msub <= `NoStop;
                      end
                  end
                  `EXE_MSUB_OP, `EXE_MSUBU_OP: begin
                      if (cnt_i == 2'b00) begin
                          hilo_temp_o <= ~mulres + 1;
                          cnt_o <= 2'b01;
                          stallreq_for_madd_msub <= `Stop;
                      end else if (cnt_i == 2'b01) begin
                          hilo_temp_o <= {`ZeroWord, `ZeroWord};
                          cnt_o <= 2'b10;
                          hilo_temp1 <= hilo_temp_i + {HI, LO};
                          stallreq_for_madd_msub <= `NoStop;
                      end
                  end
                  default: begin
                      hilo_temp_o <= {`ZeroWord, `ZeroWord};
                      cnt_o <= 2'b00;
                      stallreq_for_madd_msub <= `NoStop;
                  end
              endcase
          end
    end

    /*****************************************************************************
    **       第四段：确定要写入目的寄存器的数据                                 **
    *****************************************************************************/
    always @(*) begin
        wd_o <= wd_i;
        if (((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
            wreg_o <= `WriteDisable;
        end else begin
            wreg_o <= wreg_i;
        end
        case (alusel_i)
            `EXE_RES_LOGIC: begin
                wdata_o <= logicout;    // 选择逻辑运算结果作为最终结果
            end
            `EXE_RES_SHIFT: begin
                wdata_o <= shiftres;    // 选择移位运结果作为最终结果
            end
            `EXE_RES_MOVE: begin
                wdata_o <= moveres;
            end
            `EXE_RES_ARITHMETIC: begin  // 除乘法外的简单算术操作指令
                wdata_o <= arithmeticres;
            end
            `EXE_RES_MUL: begin
                wdata_o <= mulres[31:0];
            end
            default: begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end

    /*****************************************************************************
    **       第五段：确定HI、LO寄存器的操作信息                                 **
    *****************************************************************************/
    always @(*) begin
        if (rst == `RstEnable) begin
            whilo_o <= `WriteEnable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end else if ((aluop_i == `EXE_MSUB_OP) ||
                     (aluop_i == `EXE_MSUBU_OP)) begin
            whilo_o <= `WriteEnable;
            hi_o <= hilo_temp1[63:32];
            lo_o <= hilo_temp1[31:0];
        end else if ((aluop_i == `EXE_MADD_OP) ||
                     (aluop_i == `EXE_MADDU_OP)) begin
            whilo_o <= `WriteEnable;
            hi_o <= hilo_temp1[63:32];
            lo_o <= hilo_temp1[31:0];
        end else if ((aluop_i == `EXE_MULT_OP) ||
                     (aluop_i == `EXE_MULTU_OP)) begin // mult、multu指令
            whilo_o <= `WriteEnable;
            hi_o <= mulres[63:32];
            lo_o <= mulres[31:0];
        end else if (aluop_i == `EXE_MTHI_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= reg1_i;
            lo_o <= LO;
        end else if (aluop_i == `EXE_MTLO_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= HI;
            lo_o <= reg1_i;
        end else begin
            whilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end
    end


endmodule
