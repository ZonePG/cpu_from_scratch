module openmips (
    input wire clk,
    input wire rst,

    input wire[`RegBus] rom_data_i,
    output wire[`RegBus] rom_addr_o,
    output wire rom_ce_o
);

    // 连接 IF / ID 模块与译码阶段 ID　模块的变量
    wire[`InstAddrBus] pc;
    wire[`InstAddrBus] id_pc_i;
    wire[`InstBus] id_inst_i;

    // // 连接译码阶段 ID 模块输出与 ID / EX 模块的输入的变量
    wire[`AluOpBus] id_aluop_o;
    wire[`AluSelBus] id_alusel_o;
    wire[`RegBus] id_reg1_o;
    wire[`RegBus] id_reg2_o;
    wire id_wreg_o;
    wire[`RegAddrBus] id_wd_o;

    // 连接 ID / EX 模块输出与执行阶段 EX 模块的输入变量
    wire[`AluOpBus] ex_aluop_i;
    wire[`AluSelBus] ex_alusel_i;
    wire[`RegBus] ex_reg1_i;
    wire[`RegBus] ex_reg2_i;
    wire ex_wreg_i;
    wire[`RegAddrBus] ex_wd_i;

    // // 连接执行阶段 EX 模块的输出与 EX / MEM 模块的输入变量
    wire ex_wreg_o;
    wire[`RegAddrBus] ex_wd_o;
    wire[`RegBus] ex_wdata_o;

    wire ex_whilo_o;
    wire[`RegBus] ex_hi_o;
    wire[`RegBus] ex_lo_o;

    // 连接 EX/MEM 模块的输出与访存阶段 MEM 模块的输入变量
    wire mem_wreg_i;
    wire[`RegAddrBus] mem_wd_i;
    wire[`RegBus] mem_wdata_i;

    wire mem_whilo_i;
    wire[`RegBus] mem_hi_i;
    wire[`RegBus] mem_lo_i;

    // 连接访存阶段 MEM 模块的输出与 MEM/WB 模块的输入的变量
    wire mem_wreg_o;
    wire[`RegAddrBus] mem_wd_o;
    wire[`RegBus] mem_wdata_o;
    
    wire mem_whilo_o;
    wire[`RegBus] mem_hi_o;
    wire[`RegBus] mem_lo_o;

    // 连接 MEM/WB 模块的输出与回写阶段的输入的变量
    wire wb_wreg_i;
    wire[`RegAddrBus] wb_wd_i;
    wire[`RegBus] wb_wdata_i;

    wire wb_whilo_i;
    wire[`RegBus] wb_hi_i;
    wire[`RegBus] wb_lo_i;

    // 连接译码阶段 ID 模块与通用寄存器 Regfile 模块的变量
    wire reg1_read;
    wire reg2_read;
    wire[`RegBus] reg1_data;
    wire[`RegBus] reg2_data;
    wire[`RegAddrBus] reg1_addr;
    wire[`RegAddrBus] reg2_addr;

    // 连接回写阶段 HILO 的输出与执行阶段 EX 模块的输入的变量入
    wire[`RegBus] ex_hi_i;
    wire[`RegBus] ex_lo_i;

    // pc_reg 实例化
    pc_reg pc_reg0(
        .clk(clk), .rst(rst), .pc(pc), .ce(rom_ce_o)
    );

    assign rom_addr_o = pc;  // 指令存储器的输入地址就是 pc 的值

    // IF/ID 模块实例化
    if_id if_id0(
        .clk(clk), .rst(rst), .if_pc(pc),
        .if_inst(rom_data_i), .id_pc(id_pc_i),
        .id_inst(id_inst_i)
    );

    // 译码阶段 ID 模块实例化
    id id0(
        .rst(rst), .pc_i(id_pc_i), .inst_i(id_inst_i),

        // 来自 Regfile 模块的输入
        .reg1_data_i(reg1_data), .reg2_data_i(reg2_data),

        // 来自执行阶段 EX 模块的输入，解决译码阶段与执行阶段数据相关
        .ex_wreg_i(ex_wreg_o), .ex_wdata_i(ex_wdata_o), .ex_wd_i(ex_wd_o),

        // 来自访存阶段 MEM 模块的输入，解决译码阶段与访存阶段数据相关
        .mem_wreg_i(mem_wreg_o), .mem_wdata_i(mem_wdata_o), .mem_wd_i(mem_wd_o),

        // 送到 regfile 模块的信息
        .reg1_read_o(reg1_read), .reg2_read_o(reg2_read),
        .reg1_addr_o(reg1_addr), .reg2_addr_o(reg2_addr),

        // 送到 ID/EX 模块的信息
        .aluop_o(id_aluop_o), .alusel_o(id_alusel_o),
        .reg1_o(id_reg1_o), .reg2_o(id_reg2_o),
        .wd_o(id_wd_o), .wreg_o(id_wreg_o)
    );

    // 通用寄存器 Regfile 模块实例化
    regfile regfile1(
        .clk(clk), .rst(rst),

        // 回写阶段写入信息
        .we(wb_wreg_i), .waddr(wb_wd_i),
        .wdata(wb_wdata_i),
        
        // 译码阶段 ID 模块传递过来的信息，并将 data 送到 ID模块
        .re1(reg1_read), .raddr1(reg1_addr), .rdata1(reg1_data),
        .re2(reg2_read), .raddr2(reg2_addr), .rdata2(reg2_data)
    );

    // ID/EX 模块实例化
    id_ex id_ex0(
        .clk(clk), .rst(rst),

        // 从译码阶段 ID 模块 传递过来的信息
        .id_aluop(id_aluop_o), .id_alusel(id_alusel_o),
        .id_reg1(id_reg1_o), .id_reg2(id_reg2_o),
        .id_wd(id_wd_o), .id_wreg(id_wreg_o),

        // 传递到执行阶段 EX 模块的信息
        .ex_aluop(ex_aluop_i), .ex_alusel(ex_alusel_i),
        .ex_reg1(ex_reg1_i), .ex_reg2(ex_reg2_i),
        .ex_wd(ex_wd_i), .ex_wreg(ex_wreg_i)
    );

    // EX 模块实例化
    ex ex0(
        .rst(rst),

        // 从 ID/EX 模块传递过来的信息
        .aluop_i(ex_aluop_i), .alusel_i(ex_alusel_i),
        .reg1_i(ex_reg1_i), .reg2_i(ex_reg2_i),
        .wd_i(ex_wd_i), .wreg_i(ex_wreg_i),

        // 从 HILO 模块传递过来的信息
        .hi_i(ex_hi_i), .lo_i(ex_lo_i),

        // 回写阶段传递过来的信息
        .wb_hi_i(wb_hi_i), .wb_lo_i(wb_lo_i), .wb_whilo_i(wb_whilo_i),

        // 访存阶段传递过来的信息
        .mem_hi_i(mem_hi_o), .mem_lo_i(mem_lo_o), .mem_whilo_i(mem_whilo_o),

        // 输出到 EX/MEM 模块的信息
        .wd_o(ex_wd_o), .wreg_o(ex_wreg_o),
        .wdata_o(ex_wdata_o),

        .hi_o(ex_hi_o), .lo_o(ex_lo_o), .whilo_o(ex_whilo_o)
    );

    // EX/MEM 模块实例化
    ex_mem ex_mem0(
        .clk(clk), .rst(rst),

        // 来自执行阶段 EX 模块的信息
        .ex_wd(ex_wd_o), .ex_wreg(ex_wreg_o),
        .ex_wdata(ex_wdata_o),

        .ex_hi(ex_hi_o), .ex_lo(ex_lo_o),
        .ex_whilo(ex_whilo_o),

        // 送到访存阶段 MEM 模块的信息
        .mem_wd(mem_wd_i), .mem_wreg(mem_wreg_i),
        .mem_wdata(mem_wdata_i),

        .mem_hi(mem_hi_i), .mem_lo(mem_lo_i),
        .mem_whilo(mem_whilo_i)
    );

    // MEM 模块实例化
    mem mem0(
        .rst(rst),

        // 来自 EX/MEM 模块的信息
        .wd_i(mem_wd_i), .wreg_i(mem_wreg_i),
        .wdata_i(mem_wdata_i),

        .hi_i(mem_hi_i), .lo_i(mem_lo_i),
        .whilo_i(mem_whilo_i),

        // 送到 MEM/WB 模块的信息
        .wd_o(mem_wd_o), .wreg_o(mem_wreg_o),
        .wdata_o(mem_wdata_o),

        .hi_o(mem_hi_o), .lo_o(mem_lo_o),
        .whilo_o(mem_whilo_o)
    );

    // MEM/WB 模块实例化
    mem_wb mem_wb0(
        .clk(clk), .rst(rst),

        // 来自访存阶段 MEM 模块的信息
        .mem_wd(mem_wd_o), .mem_wreg(mem_wreg_o),
        .mem_wdata(mem_wdata_o),

        .mem_hi(mem_hi_o), .mem_lo(mem_lo_o),
        .mem_whilo(mem_whilo_o),

        // 送到回写阶段的信息
        .wb_wd(wb_wd_i), .wb_wreg(wb_wreg_i),
        .wb_wdata(wb_wdata_i),

        .wb_hi(wb_hi_i), .wb_lo(wb_lo_i),
        .wb_whilo(wb_whilo_i)
    );

    // HILO_REG 模块实例化
    hilo_reg hilo_reg0(
        .clk(clk), .rst(rst),

        // 写端口
        .we(wb_whilo_i), .hi_i(wb_hi_i), .lo_i(wb_lo_i),

        // 读端口
        .hi_o(ex_hi_i), .lo_o(ex_lo_i)
    );

endmodule