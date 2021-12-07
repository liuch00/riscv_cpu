`include "macro.vh"

module exe_mem(
	input wire clk,
	input wire rst,

	// stall signal
	input wire[5:0] stall,
	
	// provided by EXE
	input wire[31:0] exe_wdata_i,
    input wire [5:0] exe_rd_i, 
    input wire exe_wreg_i,
    input wire [31:0] exe_reg_data2_i,
	input wire[4:0] exe_alu_op,
	input wire[31:0] ex_addr_i,
	
	// provide for MEM
	output reg[5:0]		mem_rd_o,
	output reg 			mem_wreg_o,
	output reg[31:0]	mem_reg_data2_o,
	output reg [4:0] 	mem_alu_op_o,
	output reg [31:0] 	mem_wdata_o,
	output reg[31:0] mem_addr_o
);

    always @(posedge clk or posedge rst) begin
        
    end

	always @ (posedge clk) begin
		if (rst == 1'b1) begin
			mem_reg_data2_o <= 32'b0;
            mem_rd_o <= 6'b0;
			mem_wreg_o <= 1'b0;
			mem_wdata_o<=32'b0;
			mem_addr_o<=32'b0;
			mem_alu_op_o <=5'b0;
		end else if(stall[3] == 1'b1 && stall[4] == 1'b0) begin
			mem_reg_data2_o <= 32'b0;
            mem_rd_o <= 6'b0;
			mem_wreg_o <= 1'b0;	
			mem_wdata_o<=32'b0;	
			mem_addr_o<=32'b0;
			mem_alu_op_o <= 5'b0;
		end else if(stall[3] == 1'b0) begin
            mem_rd_o <= exe_rd_i;
			mem_wreg_o <= exe_wreg_i;
            mem_reg_data2_o <= exe_reg_data2_i;
			mem_wdata_o<=exe_wdata_i;
			mem_addr_o<=ex_addr_i;
			mem_alu_op_o <= exe_alu_op;
		end
	end
	
endmodule