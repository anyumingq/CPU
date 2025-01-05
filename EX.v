`include "lib/defines.vh"
// 执行运算或计算地址（反正就是和ALU相关）
// 从ID/EX流水线寄存器中读取由寄存器1传过来的值和寄存器2传过来的值
// （或寄存器1传过来的值和符号扩展过后的立即数的值），
// 并用ALU将它们相加，结果值存入EX/MEM流水线寄存器。

// alu模块已经提供，基本通过给alu提供控制信号就可以完成逻辑和算术运算
// 对于需要访存的指令在此段发出访存请求

module EX(
    input wire clk,//时钟信号
    input wire rst,//复位信号
    // input wire flush,
    input wire [`StallBus-1:0] stall,//[5:0]

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,// ID（指令解码阶段）到 EX（执行阶段）之间传输数据总线的位宽。
    //1:0是高位至地位位宽，可以根据变量灵活调整位宽
    //位宽在作为id_to_ex_bus_r下扩充

    // LW SW
    input wire [`LoadBus-1:0] id_load_bus,
    input wire [`SaveBus-1:0] id_save_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    // 
    output wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus,

    input wire [71:0] id_hi_lo_bus,
    output wire [65:0] ex_hi_lo_bus,//寄存器写入相关内容
//乘除法高位hi地位low
    output wire stallreq_for_ex,

    output wire data_sram_en,//访问内存与否
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,//执行结果
    output wire [31:0] data_sram_wdata,//写入数据
    output wire ex_id,
    output wire [3:0] data_ram_sel,//字节选择信号
    output wire [`LoadBus-1:0] ex_load_bus
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;//信号寄存器

    reg [`LoadBus-1:0] id_load_bus_r;
    reg [`SaveBus-1:0] id_save_bus_r;
    reg [71:0] id_hi_lo_bus_r;//指令id发给hi和lo寄存器的指令

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;//信号置0，同时也是一种信号格式
            id_save_bus_r <= `SaveBus'b0;
            id_load_bus_r <= `LoadBus'b0;
            id_hi_lo_bus_r <= 71'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            id_save_bus_r <= `SaveBus'b0;
            id_load_bus_r <= `LoadBus'b0;
            id_hi_lo_bus_r <= 71'b0;//停止运行
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
            id_save_bus_r <= id_save_bus;
            id_load_bus_r <= id_load_bus;
            id_hi_lo_bus_r <= id_hi_lo_bus;
        end
    end

    wire [31:0] ex_pc, inst;//当前指令计数器PC指令地址
    wire [11:0] alu_op;//// 定义ALU操作码，用于指定ALU要执行的具体操作，
    wire [2:0] sel_alu_src1;//操作数来源
    wire [3:0] sel_alu_src2;//诸如立即数、寄存器或其它
    wire data_ram_en;//是否访问内存
    wire [3:0] data_ram_wen;//32位字节特定写入参与（写操作）
    wire rf_we;//是否写回寄存器文件
    wire [4:0] rf_waddr;//指定寄存器
    wire sel_rf_res;//选择写回数据，0是alu结构,1是读取结果
    wire [31:0] rf_rdata1, rf_rdata2;//寄存器读取到的数据
    reg is_in_delayslot;//是否处在延迟槽中，处于时则先执行后跳转，无需等待
    wire [3:0] byte_sel;//选择字节参与（读操作）只选择一个



    assign {//持续赋值语句
        ex_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    //将16位立即数扩展到32位
    //将inst[15]高位到前16位
    //取指令中低16位作为后半段，相当于扩充两份
    assign imm_zero_extend = {16'b0, inst[15:0]};//扩充，高位为0
    assign sa_zero_extend = {27'b0,inst[10:6]};//扩充，前27为0，后4位位inst[0-10] 用于表示位移量

    wire [31:0] alu_src1, alu_src2;//操作数
    wire [31:0] alu_result, ex_result;//ALU结果，执行结果，目标地址

    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw;//l为load,b字节，u无符号，h为半字，w为字
    wire inst_sb, inst_sh, inst_sw;//s为save
    //1，2，4
//因为寄存器就是32位因此不需要符号
    wire inst_mfhi, inst_mflo, inst_mthi, inst_mtlo;//mf读入寄存器，mt写入寄存器，后面是寄存器类型
    wire inst_mult, inst_multu;//mul乘法,储存在HI和LO中，u为无符号
    wire inst_div, inst_divu;//div为除法，储存在HI和LO中，u为无符号

    wire [31:0] hi;//寄存器
    wire [31:0] lo;
    wire hi_we;//该寄存器是否可写入信号
    wire lo_we;
    wire [31:0] hi_wdata;
    wire [31:0] lo_wdata;//要写入该寄存器的数据

    assign {
        inst_mfhi,
        inst_mflo,
        inst_mthi,
        inst_mtlo,
        inst_mult,
        inst_multu,
        inst_div,
        inst_divu,
        hi,
        lo
    }= id_hi_lo_bus_r;
//总线传递的是有关 HI/LO 寄存器的控制信号和数据
//立即数扩展、ALU 操作数的选择以及处理乘法、除法等运算指令的标识和操作

    assign alu_src1 = sel_alu_src1[1] ? ex_pc ://第一个操作数是来源于pc值还是位移量相关还是寄存器
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend ://立即数符号扩展
                      sel_alu_src2[2] ? 32'd8 ://用于偏移量
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;//立即数零扩展，寄存器
    
    alu u_alu(
    	.alu_control (alu_op      ),//alu_op是控制信号，表示进行的操作
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    assign ex_result =  inst_mfhi ? hi :
                        inst_mflo ? lo :
                        alu_result;//执行结果来源

    decoder_2_4 u_decoder_2_4(//通过解码器
        .in  (ex_result[1:0]),//共4个结果映射到0000中
        .out (byte_sel      )
    );

    assign ex_to_mem_bus = {//赋值

        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };//提供给内存

    assign ex_id = sel_rf_res;//是否将执行结果写回寄存器文件。

    // forwording
    assign ex_to_rf_bus = {//执行阶段到寄存器文件的转发总线

        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };



    assign {//加载字节指令
        inst_lb,
        inst_lbu,
        inst_lh,
        inst_lhu,
        inst_lw
    } = id_load_bus_r;

    assign {//字节存储指令
        inst_sb,
        inst_sh,
        inst_sw
    } = id_save_bus_r;

    assign ex_load_bus = {
        inst_lb,
        inst_lbu,
        inst_lh,
        inst_lhu,
        inst_lw
    };//将id_load_bus_r解包获得的数据转到 ex_load_bus

    // assign data_ram_sel = inst_lw | inst_sw ? 4'b1111 : 4'b0000;
    assign data_ram_sel =   inst_sb | inst_lb | inst_lbu ? byte_sel :
                            inst_sh | inst_lh | inst_lhu ? {{2{byte_sel[2]}},{2{byte_sel[0]}}} :
                            inst_sw | inst_lw ? 4'b1111 : 4'b0000;    //字节选择信号
    assign data_sram_en = data_ram_en;  //访问内存与否
    assign data_sram_wen = {4{data_ram_wen}} & data_ram_sel;//选择写入操作

    assign data_sram_addr = ex_result;
    assign data_sram_wdata  =   inst_sb ? {4{rf_rdata2[7:0]}}  ://写入数据 复制0-7四次
                                inst_sh ? {2{rf_rdata2[15:0]}} : rf_rdata2;





    // assign ex_result =  inst_mfhi ? hi :
    //                     inst_mflo ? lo :
    //                     alu_result;

    assign ex_hi_lo_bus = {
        hi_we,
        lo_we,
        hi_wdata,
        lo_wdata
    };

    // MUL part
    wire [63:0] mul_result;//乘法结果
    wire mul_signed; // 有符号乘法标记

    assign mul_signed = inst_mult;//有符号乘法与否

    // reg [31:0] mul_ina;
    // reg [31:0] mul_inb;


    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),//复位信号
        .mul_signed (mul_signed     ),//乘法符号
        .ina        (rf_rdata1        ), // 乘法源操作数1
        .inb        (rf_rdata2        ), // 乘法源操作数2
        .result     (mul_result     ) // 乘法结果 64bit
    );




    // DIV part
    wire [63:0] div_result;//除法结果
    wire inst_div, inst_divu;//除法符号
    wire div_ready_i;//是否可以输出
    reg stallreq_for_div;//处理流水线暂停寄存器符号，防止数据未准备好继续指令
    assign stallreq_for_ex = stallreq_for_div;//将除法操作暂停请求信号传递给EX

    reg [31:0] div_opdata1_o;//除法操作数1
    reg [31:0] div_opdata2_o;
    reg div_start_o;//开始信号
    reg signed_div_o;//有符号除法

    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),//取消信号，但这里不做操作
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );

    always @ (*) begin//对所有输入信号变换进行监视
        if (rst) begin//复位时
            stallreq_for_div = `NoStop;//继续流水线
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;//全部置为默认值
            signed_div_o = 1'b0;//默认无符号除法
        end
        else begin
            stallreq_for_div = `NoStop;//先复位
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin//有符号除法，结果未准备好时
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;//有符号除法
                        stallreq_for_div = `Stop;//流水线暂停
                    end
                    else if (div_ready_i == `DivResultReady) begin//结果准备好
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;//除法暂停
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;//流水线继续
                    end
                    else begin//未准备好也未开始除法时也就是处于x状态下
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;//不进行除法操作
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;//直接下一流水线继续
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin//同上
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // mul_result 和 div_result 可以直接使用
    //任一个出现高电平
    assign hi_we = inst_mthi | inst_mult | inst_multu | inst_div | inst_divu;//写入寄存器信号
    assign lo_we = inst_mtlo | inst_mult | inst_multu | inst_div | inst_divu;

    // 以乘法作为示例，如果两个整数相乘，那么乘法的结果低位保存在lo寄存器，高位保存在hi寄存器。
    assign hi_wdata = inst_mthi ? rf_rdata1 ://写入的话这读取否则是返回结果
                      inst_mult | inst_multu ? mul_result[63:32] :
                      inst_div | inst_divu ? div_result[63:32] :
                      32'b0;

    assign lo_wdata = inst_mtlo ? rf_rdata1 :
                      inst_mult | inst_multu ? mul_result[31:0] :
                      inst_div | inst_divu ? div_result[31:0] :
                      32'b0;

    
endmodule