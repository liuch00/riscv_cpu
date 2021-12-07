`include "macro.vh"

module id_exe(

	input wire clock,
	input wire reset,

	// stall signal
	input wire[5:0] stall,
	input wire cs_taken,
	
	// provided by decoder
	input wire[4:0]               id_alu_op,
	input wire[31:0]              id_alu_A,
	input wire[31:0]              id_alu_B,
	input wire[4:0]               id_dst_addr,
    input wire[31:0]               id_reg_data2,
	input wire                    id_reg_w_enable,
	input wire                    id_instr_is_load,
	input wire[1:0]               id_call_break_ret,
    input wire                    id_csr_we,
    input wire[11:0]              id_csr_waddr,
    input wire[2:0]               id_csr_op,
    input wire[31:0]              id_csr_rs1,
    input wire[31:0]              id_pc,
    input wire					  id_page_fault_if,
	
	// provide for exee
	output reg[4:0]               exe_alu_op,
	output reg[31:0]              exe_alu_A,
	output reg[31:0]              exe_alu_B,
	output reg[4:0]               exe_dst_addr,
    output reg[31:0]              exe_reg_data2,
	output reg                    exe_w_enable,
	output reg                    exe_instr_is_load,
	output reg[1:0]               exe_call_break_ret,
    output reg                    exe_csr_we,
    output reg[11:0]              exe_csr_waddr,
    output reg[2:0]               exe_csr_op,
    output reg[31:0]              exe_csr_rs1,
    output reg[31:0]              exe_pc,
    output reg 					  exe_page_fault_if
);

	always @ (posedge clock or posedge reset) begin
		if (reset == 1'b1) begin
			exe_alu_op <= `ALU_NOP;
            exe_alu_A <= 32'b0;
			exe_alu_B <= 32'b0;
            exe_reg_data2 <= 32'b0;
            exe_dst_addr <= 5'b0;
			exe_w_enable <= 1'b0;
			exe_instr_is_load <= 1'b0;
			
			exe_call_break_ret <= `EXP_EXP_NONE;
			exe_csr_we <= 1'b0;
			exe_csr_waddr <= 12'b0;
			exe_csr_op <= `FUNC_CSRRW;
			exe_csr_rs1 <= 32'b0;
			exe_pc <= 32'b0;
			exe_page_fault_if <= 0;

		end else if(cs_taken || (stall[2] == 1'b1 && stall[3] == 1'b0)) begin  
			exe_alu_op <= `ALU_NOP;
            exe_alu_A <= 32'b0;
			exe_alu_B <= 32'b0;
            exe_reg_data2 <= 32'b0;
            exe_dst_addr <= 5'b0;
			exe_w_enable <= 1'b0;			
			exe_instr_is_load <= 1'b0;
			exe_call_break_ret <= `EXP_EXP_NONE;
			exe_csr_we <= 1'b0;
			exe_csr_waddr <= 12'b0;
			exe_csr_op <= `FUNC_CSRRW;
			exe_csr_rs1 <= 32'b0;
			exe_pc <= 32'b0;
			exe_page_fault_if <= 0;
		end else if(stall[2] == 1'b0) begin  
			exe_alu_op <= id_alu_op;
            exe_alu_A <= id_alu_A;
			exe_alu_B <= id_alu_B;
            exe_dst_addr <= id_dst_addr;
			exe_w_enable <= id_reg_w_enable;
            exe_reg_data2 <= id_reg_data2;
            exe_instr_is_load <= id_instr_is_load;
            
            exe_call_break_ret <= id_call_break_ret;
			exe_csr_we <= id_csr_we;
			exe_csr_waddr <= id_csr_waddr;
			exe_csr_op <= id_csr_op;
			exe_csr_rs1 <= id_csr_rs1;
			exe_pc <= id_pc;
			exe_page_fault_if <= id_page_fault_if;
        end
	end
	
endmodule