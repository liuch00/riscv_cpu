module memExpDetector(
    input wire[31:0] address,
    input wire[4:0] alu_op,
    
    output reg exp_mem_store_access,
    output reg exp_mem_load_access
);

always @ (*) begin
    if (alu_op == `ALU_LW || alu_op == `ALU_SW || alu_op == `ALU_LB || alu_op == `ALU_SB) begin
        if ((address[31:3] == 29'b0001_0000_0000_0000_0000_0000_0000_0) || (address[31:23] == 9'b1000_0000_0) || (address[31:3] == 29'b0000_0010_0000_0000_1011_1111_1111_1) || (address[31:3] == 29'b0000_0010_0000_0000_0100_0000_0000_0) || (address[31:23] == 9'b0011_0000_0)) begin
            exp_mem_store_access = 0;
            exp_mem_load_access = 0;
        end
        else begin
            if (alu_op == `ALU_LW || alu_op == `ALU_LB) begin
                exp_mem_store_access = 0;
                exp_mem_load_access = 1;
            end
            else begin
                exp_mem_store_access = 1;
                exp_mem_load_access = 0;
            end
        end
    end
    else begin
        exp_mem_store_access = 0;
        exp_mem_load_access = 0;
    end
end

endmodule