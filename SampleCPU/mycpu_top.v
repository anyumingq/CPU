`include "lib/defines.vh"
module mycpu_top(
    input wire clk,//时钟
    input wire resetn,//重置
    input wire [5:0] ext_int,//中断

    output wire inst_sram_en,//指令使能
    output wire [3:0] inst_sram_wen,//指令写使能 一般不用（调试中）
    output wire [31:0] inst_sram_addr,//指令地址
    output wire [31:0] inst_sram_wdata,//写入指令的数据
    input wire [31:0] inst_sram_rdata,//指令读取的数据

    output wire data_sram_en,//数据使能
    output wire [3:0] data_sram_wen,//数据写入使能
    output wire [31:0] data_sram_addr,//数据地址（读或写的地址）
    output wire [31:0] data_sram_wdata,//写入的数据
    input wire [31:0] data_sram_rdata,//读取的数据

    output wire [31:0] debug_wb_pc,//程序计数器
    output wire [3:0] debug_wb_rf_wen,//回写的使能信号
    output wire [4:0] debug_wb_rf_wnum,//回写写入的寄存器编号
    output wire [31:0] debug_wb_rf_wdata //回写写入的数据
);
    //指令和数据的虚拟地址
    wire [31:0] inst_sram_addr_v, data_sram_addr_v;

    mycpu_core u_mycpu_core(
    	.clk               (clk               ),
        .rst               (~resetn           ),
        .int               (ext_int           ),
        .inst_sram_en      (inst_sram_en      ),
        .inst_sram_wen     (inst_sram_wen     ),
        .inst_sram_addr    (inst_sram_addr_v  ),
        .inst_sram_wdata   (inst_sram_wdata   ),
        .inst_sram_rdata   (inst_sram_rdata   ),
        .data_sram_en      (data_sram_en      ),
        .data_sram_wen     (data_sram_wen     ),
        .data_sram_addr    (data_sram_addr_v  ),
        .data_sram_wdata   (data_sram_wdata   ),
        .data_sram_rdata   (data_sram_rdata   ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    mmu u0_mmu(
    	.addr_i (inst_sram_addr_v ),
        .addr_o (inst_sram_addr   )
    );

    mmu u1_mmu(
    	.addr_i (data_sram_addr_v ),
        .addr_o (data_sram_addr   )
    );
    
    
    
    
endmodule 