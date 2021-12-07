`include "macro.vh"
`define NOP 5'b0
module id (
    input wire clk,
    input wire reset,
    input wire[31:0] if_id_pc,
    input wire[31:0] if_id_instr,

    //interface with reg_file
    output wire [4:0] reg_addr1,
    output wire [4:0] reg_addr2,
    
    input wire [31:0] data1_from_reg,
    input wire [31:0] data2_from_reg,
    
    // interface with csr
    output wire[11:0] csr_raddr,
    input wire[31:0] csr_rdata,

    // data send back from ex stage
    input wire [4:0] exe_id_alu_op,
    input wire [4:0] exe_rd,
    input wire exe_wreg,
    input wire [31:0] exe_wdata,

    //data send back from mem stage
    input wire [4:0] mem_rd,
    input wire mem_wreg,
    input wire [31:0] mem_wdata,
    
    // data send back from id-ex
    input wire pre_instr_is_load,


    //data send to exe_u
    output reg [4:0] id_alu_op,
    output reg [31:0] id_alu_a,
    output reg [31:0] id_alu_b,
    output wire [4:0] id_reg_addr_des,
    output reg id_reg_w_enable,
    output wire [31:0] reg_data2,
    output reg instr_is_load,  // set to 1 if THIS instruction is load
    
    output reg[1:0] exp_call_break_ret,
    output reg csr_we,
    output wire[11:0] csr_waddr,
    output wire[2:0] csr_op,
    output reg[31:0] csr_rs1,

    // data send back to if
    output reg pc_branch_flag,
    output reg [31:0] pc_branch_target,

    //stall
    output wire stallreq,

    //branch prediction
    output wire branch_request,
    output wire branch_is_call,
    output wire branch_is_ret,
    output wire branch_is_jmp,
    output wire branch_is_taken,
    output wire branch_is_not_taken,
    output wire [31:0] branch_source,
    output wire [31:0] branch_pc,
    output wire branch_d_request,
    output wire[31:0]  branch_d_pc

    // //check 
    // ,input   wire [31:0] next_pc
    // ,input   wire[1:0]   next_taken
    // ,output  reg         pred_correct


);

//-------------------------------------------------------------
//imm decode
//-------------------------------------------------------------
reg [31:0]  imm20_r;
reg [31:0]  imm12_r;
reg [31:0]  bimm_r;
reg[31:0]   simm_r;
reg [31:0]  jimm20_r;
reg [4:0]   shamt_r;

always @(*)
begin
    imm20_r     = {if_id_instr[31:12], 12'b0};
    imm12_r     = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
    bimm_r      = {{19{if_id_instr[31]}}, if_id_instr[31], if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8], 1'b0};
    simm_r      = {{20{if_id_instr[31]}},if_id_instr[31:25],if_id_instr[11:7]};
    jimm20_r    = {{12{if_id_instr[31]}}, if_id_instr[19:12], if_id_instr[20], if_id_instr[30:25], if_id_instr[24:21], 1'b0};
    shamt_r     = if_id_instr[24:20];
end

//-------------------------------------------------------------
//normal
//-------------------------------------------------------------

    wire [6:0] opcode;
    wire [2:0] func3;
    wire [6:0] func7;
    assign opcode = if_id_instr[6:0];
    assign func3 = if_id_instr[14:12];
    assign func7 =if_id_instr[31:25];
    reg stallreq_for_reg1_load;
    reg stallreq_for_reg2_load;

    assign stallreq = stallreq_for_reg1_load | stallreq_for_reg2_load;

    localparam FROM_REG = 3'b001;
    localparam FROM_IMM = 3'b000;

    localparam FROM_PC  = 3'b010; // op_a
    localparam FROM_4   = 3'b010;  // op_b

    localparam FROM_ZERO = 3'b011;
    localparam FROM_CSR = 3'b100;
    reg [2:0] operand_a_sel;
    reg [2:0] operand_b_sel;

    reg [31:0] imm;

    wire [31:0] pc_4 = if_id_pc + 4;

    assign reg_addr1 = if_id_instr[19:15];
    assign reg_addr2 = if_id_instr[24:20];
    assign id_reg_addr_des = if_id_instr[11:7];
    assign csr_raddr = if_id_instr[31:20];
    assign csr_waddr = if_id_instr[31:20];
    assign csr_op = func3;
    
    
    
    reg [31:0] fixed_reg1;
    reg [31:0] fixed_reg2;
    assign reg_data2 = fixed_reg2;
    
    reg rs1_used;


    always @(*) begin
        id_alu_op = `NOP;
        instr_is_load = 0;
        operand_a_sel = FROM_ZERO;
        operand_b_sel = FROM_ZERO;
        id_reg_w_enable = 0;
        pc_branch_flag = 0;
        pc_branch_target = 0;
        imm = 0;
        exp_call_break_ret = `EXP_EXP_NONE;
        csr_we = 0;
        csr_rs1= 32'b0;
        rs1_used = 0;
        case (opcode)
            `OPCODE_R: begin
                operand_a_sel = FROM_REG;
                operand_b_sel = FROM_REG;
                id_reg_w_enable = 1'b1;
                case (func3)
                    `FUNC_ADD: id_alu_op = `ALU_ADD;
                    `FUNC_AND: begin
                        case (func7)
                            `FUNC7_AND: id_alu_op = `ALU_AND;
                            `FUNC7_ANDN: id_alu_op = `ALU_ANDN;
                        endcase
                    end
                    `FUNC_OR: id_alu_op = `ALU_OR;
                    `FUNC_XOR: begin
                        case (func7)
                            `FUNC7_XOR: id_alu_op = `ALU_XOR;
                        endcase
                    end
                    `FUNC_SBSET: id_alu_op = `ALU_SBSET;
                    `FUNC_SLTU: id_alu_op = `ALU_SLTU;
                endcase
            end
            `OPCODE_IMM: begin
                imm = imm12_r;
                operand_a_sel = FROM_REG;
                operand_b_sel = FROM_IMM;
                id_reg_w_enable = 1'b1;
                case (func3)
                    `FUNC_ADD:id_alu_op = `ALU_ADD;
                    `FUNC_AND:id_alu_op = `ALU_AND;
                    `FUNC_OR: id_alu_op = `ALU_OR;
                    `FUNC_SLL: begin
                        case(func7)
                            `FUNC7_PCNT: id_alu_op = `ALU_PCNT;
                            default: id_alu_op = `ALU_SLL;
                        endcase
                    end
                    `FUNC_SRL: id_alu_op = `ALU_SRL;
                    `FUNC_PCNT: id_alu_op = `ALU_PCNT;
                endcase
            end
            `OPCODE_BRANCH:begin
                imm = bimm_r;
                pc_branch_target = if_id_pc + imm;
                case (func3)
                    `FUNC_BEQ: pc_branch_flag = (fixed_reg1 == fixed_reg2);
                    `FUNC_BNE: pc_branch_flag = (fixed_reg1 != fixed_reg2);
                endcase
            end
            `OPCODE_LOAD: begin
                instr_is_load = 1;
                imm = imm12_r;
                operand_a_sel = FROM_REG;
                operand_b_sel = FROM_IMM;
                id_reg_w_enable = 1'b1;
                case (func3)
                    `FUNC_LW: id_alu_op = `ALU_LW;
                    `FUNC_LB: id_alu_op = `ALU_LB;
                endcase
            end
            `OPCODE_STORE: begin
                imm =simm_r;
                operand_a_sel = FROM_REG;
                operand_b_sel = FROM_IMM;
                case (func3)
                    `FUNC_SW: id_alu_op = `ALU_SW;
                    `FUNC_SB: id_alu_op = `ALU_SB;
                endcase
            end
            `OPCODE_AUIPC: begin
                id_reg_w_enable = 1'b1;
                imm = imm20_r;
                operand_a_sel = FROM_PC;
                operand_b_sel = FROM_IMM;
                id_alu_op = `ALU_ADD;
            end

            `OPCODE_LUI: begin
                id_reg_w_enable = 1'b1;
                imm =imm20_r;
                operand_a_sel = FROM_ZERO;
                operand_b_sel = FROM_IMM;
                id_alu_op = `ALU_ADD;
            end
            `OPCODE_JAL: begin
                id_reg_w_enable = 1'b1;
                imm =jimm20_r;
                pc_branch_target = if_id_pc + imm;
                pc_branch_flag = 1'b1;
                operand_a_sel = FROM_PC;
                operand_b_sel = FROM_4;
                id_alu_op = `ALU_ADD;
            end
            `OPCODE_JALR: begin
                id_reg_w_enable = 1'b1;
                imm = imm12_r;
                pc_branch_target = fixed_reg1 + imm;
                pc_branch_flag = 1'b1;
                operand_a_sel = FROM_PC;
                operand_b_sel = FROM_4;
                id_alu_op = `ALU_ADD;
            end
            `OPCODE_SYSTEM: begin
                case (func3)
                    `FUNC_PRIV: begin  // ecall ebreak mret
                        case (csr_raddr)
                            `FUNC12_ECALL: exp_call_break_ret = `EXP_EXP_ECALL;
                            `FUNC12_EBREAK: exp_call_break_ret = `EXP_EXP_EBREAK;
                            `FUNC12_MRET: exp_call_break_ret = `EXP_EXP_MRET;
                        endcase
                    end
                    `FUNC_CSRRW, `FUNC_CSRRS, `FUNC_CSRRC: begin
                        id_reg_w_enable = 1'b1;
                        csr_we = 1'b1;
                        csr_rs1 = fixed_reg1;
                        operand_a_sel = FROM_CSR;
                        rs1_used = 1;
                        id_alu_op = `ALU_ADD;
                    end
                endcase
            end
        endcase
    end
    
    
    always @(*) begin
        stallreq_for_reg1_load = 1'b0;
        if (operand_a_sel == FROM_REG || opcode == `OPCODE_BRANCH || opcode == `OPCODE_JALR || rs1_used == 1) begin
            if(pre_instr_is_load && exe_rd == reg_addr1 && (exe_rd != 5'b0)) begin 
                fixed_reg1 = exe_wdata;
                stallreq_for_reg1_load = 1'b1;
            end
            else if (exe_wreg == 1'b1 && (exe_rd == reg_addr1) && (exe_rd != 5'b0))  
                fixed_reg1 = exe_wdata;
            else if (mem_wreg == 1'b1 && (mem_rd == reg_addr1) && (mem_rd != 5'b0))
                fixed_reg1 = mem_wdata;
            else fixed_reg1 = data1_from_reg;
        end
        else begin
            fixed_reg1 = data1_from_reg;
        end
    end
    
    
    always @(*) begin
        stallreq_for_reg2_load = 1'b0;
        if (operand_b_sel == FROM_REG || opcode == `OPCODE_BRANCH || opcode == `OPCODE_STORE) begin
            if(pre_instr_is_load && (exe_rd == reg_addr2) && (exe_rd != 5'b0))
                stallreq_for_reg2_load = 1'b1;
            else if ((exe_wreg == 1'b1) && (exe_rd == reg_addr2) && (exe_rd != 5'b0))
                fixed_reg2 = exe_wdata;
            else if ((mem_wreg == 1'b1) && (mem_rd == reg_addr2) && (mem_rd != 5'b0))
                fixed_reg2 = mem_wdata;
            else fixed_reg2 = data2_from_reg;
        end
        else begin
            fixed_reg2 = data2_from_reg;
        end
    end

  
    always @(*) begin
        id_alu_a=0;
        case (operand_a_sel)
            FROM_REG : begin
                id_alu_a = fixed_reg1;
            end
            FROM_IMM : begin
                id_alu_a = imm;
            end
            FROM_PC : begin
                id_alu_a = if_id_pc;
            end
            FROM_ZERO:begin
                id_alu_a = 32'b0;
            end
            FROM_CSR: begin
                id_alu_a = csr_rdata;
            end
            default : id_alu_a = 32'b0;
        endcase
    end

   
    always @(*) begin
        id_alu_b=0;
        case (operand_b_sel)
            FROM_REG : begin
                id_alu_b = fixed_reg2;
            end
            FROM_IMM : begin
                id_alu_b = imm;
            end
            FROM_4 : begin
                id_alu_b = 4;
            end
            FROM_ZERO:begin
                id_alu_b = 32'b0;
            end
            default : id_alu_b = 32'b0;
        endcase
    end



//-------------------------------------------------------------
// less_than_signed: Less than operator (signed)
// Inputs: x = left operand, y = right operand
// Return: (int)x < (int)y
//-------------------------------------------------------------
function [0:0] less_than_signed;
    input  [31:0] x;
    input  [31:0] y;
    reg [31:0] v;
begin
    v = (x - y);
    if (x[31] != y[31])
        less_than_signed = x[31];
    else
        less_than_signed = v[31];
end
endfunction

//-------------------------------------------------------------
// greater_than_signed: Greater than operator (signed)
// Inputs: x = left operand, y = right operand
// Return: (int)x > (int)y
//-------------------------------------------------------------
function [0:0] greater_than_signed;
    input  [31:0] x;
    input  [31:0] y;
    reg [31:0] v;
begin
    v = (y - x);
    if (x[31] != y[31])
        greater_than_signed = y[31];
    else
        greater_than_signed = v[31];
end
endfunction
//-------------------------------------------------------------
//branch predictions
//-------------------------------------------------------------
reg        branch_r;
reg        branch_taken_r;
reg [31:0] branch_target_r;
reg        branch_call_r;
reg        branch_ret_r;
reg        branch_jmp_r;

always @(*) begin
    branch_r        = 1'b0;
    branch_taken_r  = 1'b0;
    branch_call_r   = 1'b0;
    branch_ret_r    = 1'b0;
    branch_jmp_r    = 1'b0;

    // Default branch_r target is relative to current PC
    branch_target_r = if_id_pc + bimm_r;
    if ((if_id_instr & `INST_JAL_MASK) == `INST_JAL) // jal
    begin
        branch_r        = 1'b1;
        branch_taken_r  = 1'b1;
        // pc += sext(offset) 
        branch_target_r = if_id_pc + jimm20_r;  
        branch_call_r   = (id_reg_addr_des == 5'd1); // RA
        branch_jmp_r    = 1'b1;
    end
    else if ((if_id_instr & `INST_JALR_MASK) == `INST_JALR) // jalr
    begin
        branch_r            = 1'b1;
        branch_taken_r      = 1'b1;
        //pc = (x[rs1]+sext(offset))&~1;
        branch_target_r     = (id_alu_a + imm12_r) ;
        branch_target_r[0]  = 1'b0;
        branch_ret_r        = (reg_addr1 == 5'd1 && imm12_r[11:0] == 12'b0); // RA
        branch_call_r       = ~branch_ret_r && (id_reg_addr_des == 5'd1); // RA
        branch_jmp_r        = ~(branch_call_r | branch_ret_r);
    end
    else if ((if_id_instr & `INST_BEQ_MASK) == `INST_BEQ) // beq
    begin
        branch_r      = 1'b1;
        branch_taken_r= (fixed_reg1 == fixed_reg2);
    end
    else if ((if_id_instr & `INST_BNE_MASK) == `INST_BNE) // bne
    begin
        branch_r      = 1'b1;    
        branch_taken_r= (fixed_reg1 != fixed_reg2);
    end
    else if ((if_id_instr & `INST_BLT_MASK) == `INST_BLT) // blt
    begin
        branch_r      = 1'b1;
        branch_taken_r= less_than_signed(fixed_reg1, fixed_reg2);
    end
    else if ((if_id_instr & `INST_BGE_MASK) == `INST_BGE) // bge
    begin
        branch_r      = 1'b1;    
        branch_taken_r= greater_than_signed(fixed_reg1,fixed_reg2) | (fixed_reg1 == fixed_reg2);
    end
    else if ((if_id_instr & `INST_BLTU_MASK) == `INST_BLTU) // bltu
    begin
        branch_r      = 1'b1;    
        branch_taken_r= (fixed_reg1 < fixed_reg2);
    end
    else if ((if_id_instr & `INST_BGEU_MASK) == `INST_BGEU) // bgeu
    begin
        branch_r      = 1'b1;
        branch_taken_r= (fixed_reg1 >= fixed_reg2);
    end
end

    reg  branch_call_reg;
    reg  branch_ret_reg;
    reg  branch_jmp_reg;
    reg  branch_taken_reg;
    reg  branch_ntaken_reg;
    reg [31:0] pc_x_reg;
    reg [31:0] pc_m_reg;

always @ (posedge clk or posedge reset)begin

if (reset)begin
    branch_call_reg     <= 1'b0;
    branch_ret_reg      <= 1'b0;
    branch_jmp_reg      <= 1'b0;
    branch_taken_reg    <= 1'b0;
    branch_ntaken_reg   <= 1'b0;
    pc_x_reg            <= 32'b0;
    pc_m_reg            <= 32'b0;
end
else  begin
    //todo: add opcode_valid ?
    branch_taken_reg    <= branch_r & branch_taken_r;
    branch_ntaken_reg   <= branch_r  & ~branch_taken_r;
    pc_x_reg            <= branch_taken_r ? branch_target_r : if_id_pc + 32'd4;
    branch_call_reg     <= branch_r  && branch_call_r;
    branch_ret_reg      <= branch_r  && branch_ret_r;
    branch_jmp_reg      <= branch_r  && branch_jmp_r;
    pc_m_reg            <= if_id_pc;
end

end

assign branch_request       = branch_taken_reg | branch_ntaken_reg;
assign branch_is_taken      = branch_taken_reg;
assign branch_is_not_taken  = branch_ntaken_reg;
assign branch_source        = pc_m_reg;
assign branch_pc            = pc_x_reg;
assign branch_is_call       = branch_call_reg;
assign branch_is_ret        = branch_ret_reg;
assign branch_is_jmp        = branch_jmp_reg;

assign branch_d_request     = (branch_r  && branch_taken_r);
assign branch_d_pc          = branch_target_r;


    

// always @ (*)begin
//     if(opcode==`OPCODE_BRANCH||opcode==`OPCODE_JAL||opcode==`OPCODE_JALR )begin
//         if(next_taken[1]==pc_branch_flag)begin
//             if (next_taken[1]&&next_pc!=pc_branch_target) begin
//                 pred_correct =0;
//             end
//             else begin
//                 pred_correct =1;
//             end
//         end else begin
//              pred_correct =0;
//         end

//     end
//     else begin
//         pred_correct =1;
//     end
// end




endmodule















