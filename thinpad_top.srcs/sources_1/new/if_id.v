module if_id (
    input wire clock,
    input wire reset,
    input wire[5:0] stall,
    input wire cs_taken,
    input wire[31:0] instr_from_ram,
    input wire page_fault_if,
    input wire[31:0] pc_from_if,
    output reg[31:0] if_id_instr,
    output reg[31:0] if_id_pc,
    output reg      pc_accept,
    output reg page_fault_if_o
);
    
always @(posedge clock or posedge reset) begin
    if(reset) begin
        if_id_instr <= 32'h00000000;
        if_id_pc <= 32'h80000000;
        pc_accept<=0;
        page_fault_if_o <= 0;
    end
    else begin
        if(cs_taken || (stall[1] == 1 && stall[2] == 0)) begin
            if_id_instr <= 32'h00000000;
            if_id_pc <= 32'h80000000;
            pc_accept<=0;
            page_fault_if_o <= 0;
        end
        else if(stall[1] == 0) begin
            if (page_fault_if_o)
                if_id_instr <= 32'b0;
            else
                if_id_instr <= instr_from_ram;
            if_id_pc <= pc_from_if;
            pc_accept<=1;
            page_fault_if_o <= page_fault_if;
        end
    end
end
endmodule
