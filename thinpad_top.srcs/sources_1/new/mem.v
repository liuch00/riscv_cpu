`include "macro.vh"

module mem (
    input wire[31:0] exe_mem_addr,  // address input for sram
    input wire[31:0] data_in_i,   // data input for sram
    input wire[4:0] alu_op_i,
    input wire[31:0] sram_to_mem_data_i,  // data input for target register
    input wire[4:0] rd_i,  // address input for target register
    input wire wreg_i,  // flag for register data input
    input wire[31:0] read_from_sram_i,  // data read from sram

    // 内存控制
    output reg is_byte_o,  // whether byte operation should be enabled
    output wire[31:0] mem_data_to_sram,  // data input for sram
    output wire[31:0] mem_addr_to_sram,  // address input for sram

    output reg mem_ram_req,   // flag for sram operation
    output reg mem_ram_read,  // flag for sram operation (whether read or write)

    output wire[4:0] rd_o,  // address for register input
    output wire wreg_o,  // flag for register data input
    output reg[31:0] reg_wdata_o  // data input for target register (could be chosen from sram_to_mem_data_i or data_in_i)


);

// set sram data with direct access
assign mem_data_to_sram = data_in_i;
assign mem_addr_to_sram = exe_mem_addr;
assign wreg_o = wreg_i;
assign rd_o = rd_i;
localparam SRAM_READ =2'b00;
localparam SRAM_WRITE = 2'b01;
localparam SRAM_DISABLE1 = 2'b10;

reg[1:0] sram_state_flag;


// choose flag for sram control
always @(*) begin
    case (alu_op_i)
        `ALU_LW: begin
            is_byte_o = `IS_BYTE_DIS;
            sram_state_flag = SRAM_READ;
            reg_wdata_o = read_from_sram_i;
        end
        `ALU_LB: begin
            is_byte_o = `IS_BYTE_EN;
            sram_state_flag = SRAM_READ;
            reg_wdata_o = read_from_sram_i;
        end
        `ALU_SW: begin
            is_byte_o = `IS_BYTE_DIS;
            sram_state_flag = SRAM_WRITE;
            reg_wdata_o = sram_to_mem_data_i;
        end
        `ALU_SB: begin
            is_byte_o = `IS_BYTE_EN;
            sram_state_flag = SRAM_WRITE;
            reg_wdata_o = sram_to_mem_data_i;
        end
        default: begin
            is_byte_o = `IS_BYTE_DIS;
            sram_state_flag = SRAM_DISABLE1;
            reg_wdata_o = sram_to_mem_data_i;
        end
    endcase
end

// sram control
always @(*) begin
    if (sram_state_flag == SRAM_READ) begin
        mem_ram_req = `RAM_EN;
        mem_ram_read = `RAM_READ;
    end
    else if (sram_state_flag == SRAM_WRITE) begin
        mem_ram_req = `RAM_EN;
        mem_ram_read = `RAM_WRITE;
    end
    else begin
        mem_ram_req = `RAM_DIS;
        mem_ram_read = `RAM_READ;
    end
end
endmodule : mem


