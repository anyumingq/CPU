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
	input wire rst,							//��λ
	input wire clk,							//ʱ��
	input wire signed_mul_i,				//�Ƿ�Ϊ�з��ų˷����㣬1λ�з���
    input wire[31:0] opdata1_i,				//����1
    input wire[31:0] opdata2_i,				//����2
	input wire start_i,						//�Ƿ�ʼ�˷�����
	input wire annul_i,						//�Ƿ�ȡ���˷����㣬1λȡ��
    output reg[63:0] result_o,				//�˷�������
	output reg ready_o						//�˷������Ƿ����
);
//MulFree:00
//MulByZero:01
//MulOn:10
//MulEnd:11
    reg [63:0] op1;        // ������1��64λ
    reg [31:0] op2;        // ������2��32λ
    reg [1:0] state;       // ģ��״̬��00 - ��ʼ����01 - ������Ϊ0��10 - �˷����㣬11 - ���
    reg [5:0] cnt;         // ��������6λ
always@(posedge clk) begin
    if(rst || (!start_i)) begin
        state <= 2'b00;            // ��λ��δ����ʱ�����ʼ��״̬
        result_o <= {`ZeroWord, `ZeroWord};  // ����˷����
        ready_o <= 1'b0;           // ����δ���
    end else begin
        case(state)
            // ��ʼ���׶�
            2'b00: begin
                if(start_i == 1'b1 && annul_i == 1'b0) begin
                    if((opdata1_i == `ZeroWord) || (opdata2_i == `ZeroWord)) begin
                        state <= 2'b01;  // ���������Ϊ0������MulByZero״̬
                    end else begin
                        state <= 2'b10;  // �������˷�����״̬
                        cnt <= 6'b000000; // ����������
                        
                        // �Բ��������д����з��ų˷���Ҫ�������λ
                        if(signed_mul_i == 1'b1 && opdata1_i[31] == 1'b1) begin
                            op1 <= {`ZeroWord, ~opdata1_i + 1'b1};  // ����Ǹ�����ȡ����
                        end else begin
                            op1 <= {`ZeroWord, opdata1_i};  // ֱ�Ӹ�ֵ
                        end
                        
                        if(signed_mul_i == 1'b1 && opdata2_i[31] == 1'b1) begin
                            op2 <= ~opdata2_i + 1'b1;  // ����Ǹ�����ȡ����
                        end else begin
                            op2 <= opdata2_i;  // ֱ�Ӹ�ֵ
                        end
                        
                        result_o <= {`ZeroWord, `ZeroWord};  // ������
                    end
                end else begin
                    ready_o <= 1'b0;             // ���û����������׼���ź�Ϊ0
                    result_o <= {`ZeroWord, `ZeroWord};  // �������
                end
            end
            
            // ������Ϊ0�����
            2'b01: begin
                result_o <= {`ZeroWord, `ZeroWord};  // ���Ϊ0
                state <= 2'b11;  // �������״̬
            end
            
            // �˷�����׶�
            2'b10: begin
                if(cnt != 6'b10_0000) begin  // ���������û�е����ֵ
                    if(op2[cnt] == 1'b1) begin
                        result_o <= result_o + op1;  // ���op2�ĵ�ǰλΪ1������op1
                    end
                    op1 <= op1 << 1;  // ����op1��׼������һ��λ
                    cnt <= cnt + 1'b1;  // ��������1
                end else begin
                    // ������з��ų˷����Ҳ��������Ų�ͬ������ȡ������1�����룩
                    if(signed_mul_i == 1'b1 && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
                        result_o <= ~result_o + 1'b1;  // ȡ������1
                    end
                    state <= 2'b11;  // �������״̬
                    cnt <= 6'b000000;  // ���ü�����
                end
            end
            
            // ��ɽ׶γ�ʼ������
            2'b11: begin
                ready_o <= 1'b1;  // ������ɣ�׼���ź���1
                if(start_i == 1'b0) begin  // ���û�������ź�
                    state <= 2'b00;  // ���س�ʼ��״̬
                    ready_o <= 1'b0;  // ����δ׼����
                    result_o <= {`ZeroWord, `ZeroWord};  // ������
                end
            end
        endcase
    end
end

endmodule
