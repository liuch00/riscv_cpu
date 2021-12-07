module csr(
    // clock
    input wire clock,
    input wire reset,
    
    // selection read
    input wire[11:0] raddr,  // address of register to read
    output wire[31:0] rdata,
    
    // direct read
    output reg[31:0] mstatus,
    output reg[31:0] mie,
    output reg[31:0] mtvec,
    output reg[31:0] mscratch,
    output reg[31:0] mepc,
    output reg[31:0] mcause,
    output reg[31:0] mip,
    
    // seletion write
    input wire selection_we,  // 1 is enable
    input wire[11:0] waddr,
    input wire[31:0] wdata,
    
    // direct write
    input wire direct_we,  // 1 is enable, if this is enabled, selection we will be ignored
    input wire[31:0] mstatus_i,
    input wire[31:0] mie_i,
    input wire[31:0] mtvec_i,
    input wire[31:0] mscratch_i,
    input wire[31:0] mepc_i,
    input wire[31:0] mcause_i,
    input wire[31:0] mip_i,
    
    // exception output
    output reg csr_addr_expcetion  // this can cause "illegal instruction exception"
);

// ----- timing: reset and write ----- //

always @ (posedge clock or posedge reset) begin
// reset
if (reset) begin
    mstatus <= 32'b0;
    mie <= 32'b0;
    mtvec <= 32'b0;
    mscratch <= 32'b0;
    mepc <= 32'b0;
    mcause <= 32'b0;
    mip <= 32'b0;
    csr_addr_expcetion <= 0;
end

// direct write
else if (direct_we) begin
    mstatus <= mstatus_i;
    mie <= mie_i;
    mtvec <= mtvec_i;
    mscratch <= mscratch_i;
    mepc <= mepc_i;
    mcause <= mcause_i;
    mip <= mip_i;
end

// selection write
else if (selection_we) begin
    case (waddr)
        12'h300: mstatus <= wdata;
        12'h304: mie <= wdata;
        12'h305: mtvec <= wdata;
        12'h340: mscratch <= wdata;
        12'h341: mepc <= wdata;
        12'h342: mcause <= wdata;
        12'h344: mip <= wdata;
        default: csr_addr_expcetion <= 1;
    endcase
end
end

// ----- comb: read ----- //

reg[31:0] wdata_ready;  // possible candidate for output, may not be used if there is a conflict
always @ (*) begin
// direct read: in fact one can read from output directly, so there is no additional codes
// selection read: the same way to process conflict as regFile
    case (raddr)
        12'h300: wdata_ready = mstatus;
        12'h304: wdata_ready = mie;
        12'h305: wdata_ready = mtvec;
        12'h340: wdata_ready = mscratch;
        12'h341: wdata_ready = mepc;
        12'h342: wdata_ready = mcause;
        12'h344: wdata_ready = mip;
        default: begin
            wdata_ready = 32'b0;
        end
    endcase
end

// conflict if reading a register that will be written to in the next posedge
// direct write is not considered, because there is always a context switch after direct write
// and current instruction will be flushed
assign rdata = (raddr == waddr && selection_we) ? wdata : wdata_ready;

endmodule
