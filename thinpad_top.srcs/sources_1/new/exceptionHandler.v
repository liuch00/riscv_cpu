`timescale 1ns / 1ps
`include "macro.vh"

module exceptionHandler(
    input wire clock,
    input wire reset,

    // read from csr
    // only direct read needed
    input wire[31:0] mstatus_i,
    input wire[31:0] mie_i,
    input wire[31:0] mtvec_i,
    input wire[31:0] mscratch_i,
    input wire[31:0] mepc_i,
    input wire[31:0] mcause_i,
    input wire[31:0] mip_i,
    
    // write to csr
    // direct write
    output reg direct_we,
    output reg[31:0] mstatus_o,
    output reg[31:0] mie_o,
    output reg[31:0] mtvec_o,
    output reg[31:0] mscratch_o,
    output reg[31:0] mepc_o,
    output reg[31:0] mcause_o,
    output reg[31:0] mip_o,
    // selection write
    output reg selection_we,
    output reg[31:0] csr_wdata,
    output wire[11:0] csr_waddr,
    
    // csrxx instructions related signals
    input wire exe_we,
    input wire[31:0] exe_csr,
    input wire[31:0] exe_rs1,
    input wire[11:0] exe_waddr,
    input wire[2:0] csr_op,
    
    // signals that indicate whether exception occurs
    // signals appearing earlier means they are caused by earlier instrcutions
    // so they need to be processed before others
    input wire[1:0] exe_call_break_ret,
    input wire mem_store_access,
    input wire mem_load_access,
    
    // output used for context switch
    output reg context_switch_by_exception,  // 1 means enable
    output reg[31:0] cs_target,
    
    // other signals
    input wire[31:0] pc_exe,  // pc of the instruction currently at EXE phase
    
/*    input wire[1:0] mode,
    output reg[1:0] mode_o,
    output reg mode_we,*/
    input wire[63:0] mtime,
    input wire[63:0] mtimecmp
    );

// direct assign, to make things easier
assign csr_waddr = exe_waddr;

// mode
reg[1:0] mode;
reg[1:0] mode_o;
always @ (posedge clock or posedge reset) begin
    if (reset)
        mode = `MODE_M;
    else
        mode = mode_o;
end

always @ (*) begin
/* signals that need to be assigned
direct_we = 0;
mstatus_o = mstatus_i;
mie_o = mie_i;
mtvec_o = mtvec_i;
mscratch_o = mscratch_i;
mepc_o = mepc_i;
mcause_o = mcause_i;
mip_o = mip_i;

context_switch_by_exception = 0;
cs_target = 32'b0;
mode_we = 0;
mode_o = mode;

selection_we = 0;
csr_wdata = 32'b0;
*/

// ----- first priority: check whether context switch is triggered ----- //
// interruption
if (mtime >= mtimecmp && mie_i[7] == 1'b1 && mode != `MODE_M) begin
    direct_we = 1;
    mstatus_o = {mstatus_i[31:13], mode, mstatus_i[10:0]};
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = pc_exe;
    mcause_o = {1'b1, 31'h7};
    mip_o = {mip_i[31:8], 1'b1, mip_i[6:0]};
    
    context_switch_by_exception = 1;
    cs_target = mtvec_i;
    //mode_we = 0;
    mode_o = `MODE_M;
    
    selection_we = 0;
    csr_wdata = 32'b0;
end
// exception encountered at IF phase
// exception encountered at ID phase
// exception encountered at EXE phase
else if (exe_call_break_ret == `EXP_EXP_ECALL) begin  // ecall
    direct_we = 1;
    mstatus_o = {mstatus_i[31:13], mode, mstatus_i[10:0]};
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = pc_exe;
    mcause_o = {1'b0, 31'h8};
    mip_o = mip_i;

    context_switch_by_exception = 1;
    cs_target = mtvec_i;
    //mode_we = 1;
    mode_o = `MODE_M;

    selection_we = 0;
    csr_wdata = 32'b0;
end
else if (exe_call_break_ret == `EXP_EXP_EBREAK) begin  // ebreak
    direct_we = 1;
    mstatus_o = {mstatus_i[31:13], mode, mstatus_i[10:0]};
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = pc_exe;
    mcause_o = {1'b0, 31'h3};
    mip_o = mip_i;

    context_switch_by_exception = 1;
    cs_target = mtvec_i;
    //mode_we = 1;
    mode_o = `MODE_M;

    selection_we = 0;
    csr_wdata = 32'b0;
end
else if (exe_call_break_ret == `EXP_EXP_MRET) begin  // mret
    direct_we = 1;
    mstatus_o = mstatus_i;
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = mepc_i;
    mcause_o = 32'b0;
    mip_o = 32'b0;

    context_switch_by_exception = 1;
    cs_target = mepc_i;
    //mode_we = 1;
    mode_o = mstatus_i[12:11];

    selection_we = 0;
    csr_wdata = 32'b0;
end
// exception encountered at MEM phase (actually this is "will be encountered")
else if (mem_load_access == 1) begin
    direct_we = 1;
    mstatus_o = {mstatus_i[31:13], mode, mstatus_i[10:0]};
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = pc_exe;
    mcause_o = {1'b0, 31'h5};
    mip_o = mip_i;
    
    context_switch_by_exception = 1;
    cs_target = mtvec_i;
    //mode_we = 0;
    mode_o = `MODE_M;
    
    selection_we = 0;
    csr_wdata = 32'b0;
end
else if (mem_store_access == 1) begin
    direct_we = 1;
    mstatus_o = {mstatus_i[31:13], mode, mstatus_i[10:0]};
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = pc_exe;
    mcause_o = {1'b0, 31'h7};
    mip_o = mip_i;
    
    context_switch_by_exception = 1;
    cs_target = mtvec_i;
    //mode_we = 0;
    mode_o = `MODE_M;
    
    selection_we = 0;
    csr_wdata = 32'b0;
end

// ----- no exception, YES! YES! let's deal with CSR assignment next ----- //
else if (exe_we) begin
    direct_we = 0;
    mstatus_o = mstatus_i;
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = mepc_i;
    mcause_o = mcause_i;
    mip_o = mip_i;
    
    context_switch_by_exception = 0;
    cs_target = 32'b0;
    //mode_we = 0;
    mode_o = mode;
    
    selection_we = 1;
    case (csr_op)
        `FUNC_CSRRW: csr_wdata = exe_rs1;
        `FUNC_CSRRS: csr_wdata = exe_csr | exe_rs1;
        `FUNC_CSRRC: csr_wdata = exe_csr & (~exe_rs1);
    endcase
end

// ----- no assignment either ----- //
else begin
    direct_we = 0;
    mstatus_o = mstatus_i;
    mie_o = mie_i;
    mtvec_o = mtvec_i;
    mscratch_o = mscratch_i;
    mepc_o = mepc_i;
    mcause_o = mcause_i;
    mip_o = mip_i;
    
    context_switch_by_exception = 0;
    cs_target = 32'b0;
    //mode_we = 0;
    mode_o = mode;
    
    selection_we = 0;
    csr_wdata = 32'b0;
end

end

endmodule
