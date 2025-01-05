`include "lib/defines.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/12/13 19:45:12
// Design Name: 
// Module Name: mul_self
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module mul_self(
	input wire rst,							//复位
	input wire clk,							//时钟
	input wire signed_mul_i,				//是否为有符号乘法运算，1位有符号
    input wire[31:0] opdata1_i,				//乘数1
    input wire[31:0] opdata2_i,				//乘数2
	input wire start_i,						//是否开始乘法运算
	input wire annul_i,						//是否取消乘法运算，1位取消
    output reg[63:0] result_o,				//乘法运算结果
	output reg ready_o						//乘法运算是否结束
);
//MulFree:00
//MulByZero:01
//MulOn:10
//MulEnd:11
    reg [63:0] op1;        // 操作数1，64位
    reg [31:0] op2;        // 操作数2，32位
    reg [1:0] state;       // 模块状态：00 - 初始化，01 - 操作数为0，10 - 乘法计算，11 - 完成
    reg [5:0] cnt;         // 计数器，6位
always@(posedge clk) begin
    if(rst || (!start_i)) begin
        state <= 2'b00;            // 复位或未启动时进入初始化状态
        result_o <= {`ZeroWord, `ZeroWord};  // 清零乘法结果
        ready_o <= 1'b0;           // 运算未完成
    end else begin
        case(state)
            // 初始化阶段
            2'b00: begin
                if(start_i == 1'b1 && annul_i == 1'b0) begin
                    if((opdata1_i == `ZeroWord) || (opdata2_i == `ZeroWord)) begin
                        state <= 2'b01;  // 如果操作数为0，进入MulByZero状态
                    end else begin
                        state <= 2'b10;  // 否则进入乘法计算状态
                        cnt <= 6'b000000; // 计数器清零
                        
                        // 对操作数进行处理：有符号乘法需要处理符号位
                        if(signed_mul_i == 1'b1 && opdata1_i[31] == 1'b1) begin
                            op1 <= {`ZeroWord, ~opdata1_i + 1'b1};  // 如果是负数，取补码
                        end else begin
                            op1 <= {`ZeroWord, opdata1_i};  // 直接赋值
                        end
                        
                        if(signed_mul_i == 1'b1 && opdata2_i[31] == 1'b1) begin
                            op2 <= ~opdata2_i + 1'b1;  // 如果是负数，取补码
                        end else begin
                            op2 <= opdata2_i;  // 直接赋值
                        end
                        
                        result_o <= {`ZeroWord, `ZeroWord};  // 清零结果
                    end
                end else begin
                    ready_o <= 1'b0;             // 如果没有启动，则准备信号为0
                    result_o <= {`ZeroWord, `ZeroWord};  // 结果清零
                end
            end
            
            // 操作数为0的情况
            2'b01: begin
                result_o <= {`ZeroWord, `ZeroWord};  // 结果为0
                state <= 2'b11;  // 进入完成状态
            end
            
            // 乘法计算阶段
            2'b10: begin
                if(cnt != 6'b10_0000) begin  // 如果计数器没有到最大值
                    if(op2[cnt] == 1'b1) begin
                        result_o <= result_o + op1;  // 如果op2的当前位为1，加上op1
                    end
                    op1 <= op1 << 1;  // 左移op1，准备乘下一个位
                    cnt <= cnt + 1'b1;  // 计数器加1
                end else begin
                    // 如果是有符号乘法，且操作数符号不同，则结果取反并加1（补码）
                    if(signed_mul_i == 1'b1 && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
                        result_o <= ~result_o + 1'b1;  // 取反并加1
                    end
                    state <= 2'b11;  // 进入完成状态
                    cnt <= 6'b000000;  // 重置计数器
                end
            end
            
            // 完成阶段初始化设置
            2'b11: begin
                ready_o <= 1'b1;  // 运算完成，准备信号置1
                if(start_i == 1'b0) begin  // 如果没有启动信号
                    state <= 2'b00;  // 返回初始化状态
                    ready_o <= 1'b0;  // 运算未准备好
                    result_o <= {`ZeroWord, `ZeroWord};  // 清零结果
                end
            end
        endcase
    end
end

endmodule
