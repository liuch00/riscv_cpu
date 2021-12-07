`include "macro.vh"
module exe(
    input wire[31:0] exe_alu_A,
    input wire[31:0] exe_alu_B,
    input wire[4:0] exe_alu_op,   
    input wire [5:0] exe_dst_addr, 
    input wire exe_w_enable,
    input wire [31:0] exe_reg_data2,
    
    output wire [5:0]  rd_o, 
    output wire        wreg_o,
    output wire [31:0] reg_data2_o,
    output wire [4:0]  alu_op_o,
    output reg [31:0] mem_addr_o,
    output reg [31:0] reg_wdata_o
);

    assign rd_o = exe_dst_addr;
    assign wreg_o = exe_w_enable;
    assign reg_data2_o = exe_reg_data2;
    assign alu_op_o = exe_alu_op;

    wire is_load_store;
    reg [31:0] result;
    reg[31:0] tmp;

    assign is_load_store = (exe_alu_op ==`ALU_LW) || (exe_alu_op==`ALU_LB) || (exe_alu_op == `ALU_SW) || (exe_alu_op ==`ALU_SB);

    always @(*) begin
        result = 32'b0;
        case (exe_alu_op) 
            `ALU_ADD, `ALU_LW, `ALU_LB, `ALU_SW, `ALU_SB: begin
                result = exe_alu_A + exe_alu_B;
            end
            `ALU_AND:begin
                result = exe_alu_A & exe_alu_B;
            end
            `ALU_OR:begin
                result=exe_alu_A | exe_alu_B;
            end
            `ALU_XOR:begin
                result=exe_alu_A ^ exe_alu_B;
            end
            `ALU_SLL:begin
                result=exe_alu_A << exe_alu_B[4:0];
            end
            `ALU_SRL:begin
                result=exe_alu_A >> exe_alu_B[4:0];
            end
            `ALU_PCNT : begin
                result = exe_alu_A;
                tmp = (result & 32'h55555555) + ((result >> 1) & 32'h55555555);
                result = (tmp & 32'h33333333) + ((tmp >> 2) & 32'h33333333);
                tmp = (result & 32'h0F0F0F0F) + ((result >> 4) & 32'h0F0F0F0F);
                result = (tmp & 32'h00FF00FF) + ((tmp >> 8) & 32'h00FF00FF);
                tmp = (result & 32'h0000FFFF) + ((result >> 16) & 32'h0000FFFF);
                result = tmp;
            end
            `ALU_SBSET: begin
                result = exe_alu_A | (32'h00000001 << exe_alu_B[4:0]);
            end
            `ALU_ANDN: begin
                result = exe_alu_A & ~(exe_alu_B);
            end
            `ALU_SLTU: begin
                if (exe_alu_A < exe_alu_B)
                    result = 1;
                else
                    result = 0;
            end
        endcase
    end


    //Connect the result
    always @(*) begin
        if(is_load_store)
            reg_wdata_o = 32'b0;
        else 
            reg_wdata_o = result;
    end

    always @(*) begin
        if (is_load_store)
            mem_addr_o = result;
        else
            mem_addr_o = 32'b0;
    end

endmodule
