`include "lib/defines.vh"

module IF(
    input wire clk,//时钟
    input wire rst,//复位
    input wire [`StallBus-1:0] stall,//暂停

    // input wire flush,
    // input wire [31:0] new_pc,

    input wire [`BR_WD-1:0] br_bus,//总线跳转信息

    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus,//IF到ID传输指令

    output wire inst_sram_en,//指令使能
    output wire [3:0] inst_sram_wen,//指令写使能信号
    output wire [31:0] inst_sram_addr,//指令地址
    output wire [31:0] inst_sram_wdata//指令写入数据
);
    //当前程序计数器的值
    reg [31:0] pc_reg;

    //
    reg ce_reg;


    wire [31:0] next_pc;
    wire br_e;
    wire [31:0] br_addr;

    //br_e表示是否有跳转，addr表示跳转地址
    assign {
        br_e,
        br_addr
    } = br_bus;//33位，1位使是否跳转，32位是跳转位置



    //PC更新
    always @ (posedge clk) begin
        if (rst) begin  //复位，则使PC计数变为默认
            pc_reg <= 32'hbfbf_fffc;
        end

        else if (stall[0]==`NoStop) begin//如果未停，则next_Pc给PC
            pc_reg <= next_pc;
        end
    end



    always @ (posedge clk) begin
        if (rst) begin
            ce_reg <= 1'b0;//ce_reg 恢复初始值
        end

        else if (stall[0]==`NoStop) begin//如果不停，则赋值为1，表示寄存器可用
            ce_reg <= 1'b1;
        end
    end


    assign next_pc = br_e ? br_addr //判断是跳转地址，还是下一跳地址
                   : pc_reg + 32'h4;

    
    assign inst_sram_en = ce_reg;//寄存器是否可用
    assign inst_sram_wen = 4'b0;//指令写使能
    assign inst_sram_addr = pc_reg;//指令地址
    assign inst_sram_wdata = 32'b0;//指令写的地址
    assign if_to_id_bus = {//寄存器使能，与寄存器中的值打包
        ce_reg,
        pc_reg
    };

endmodule