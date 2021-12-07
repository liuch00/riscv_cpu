`include "macro.vh"

module mem_wb (
    input wire clk,
    input wire rst,

	input wire[5:0]    stall,	

	input wire[4:0]       mem_rd,
	input wire            mem_wreg,
	input wire[31:0]      mem_wdata,

    
    output reg[4:0]        wb_rd,
	output reg             wb_wreg,
	output reg[31:0]	   wb_wdata	      
);
    always @(posedge clk or posedge rst) begin
		if(rst == 1'b1) begin
			wb_rd <= 5'b0;
		    wb_wreg <= 1'b0;
		    wb_wdata <= 32'b0;		
		end else if(stall[4] == 1'b1 && stall[5] == 1'b0) begin
			wb_rd <= 5'b0;
		    wb_wreg <= 1'b0;
		    wb_wdata <= 32'b0;	
		end else if(stall[4] == 1'b0) begin
			wb_rd <= mem_rd;
			wb_wreg <= mem_wreg;
			wb_wdata <= mem_wdata;		
		end    
	end      
    
endmodule