`timescale 1ns / 1ps
`include "macro.vh"
module exceptionRelatedRegs(
    input wire clock,
    input wire reset,
    
    output reg[1:0] mode,
    output reg[63:0] mtime,
    output reg[63:0] mtimecmp,
    
    input wire[1:0] mode_i,
    input wire[63:0] mtime_i,
    input wire[63:0] mtimecmp_i,
    
    input wire mode_we,
    input wire mtime_we,
    input wire mtimecmp_we
    );
always @ (posedge clock or posedge reset) begin
    if (reset) begin
        mode <= `MODE_M;
        mtime <= 64'b0;
        mtimecmp <= 64'b0;
    end
    else begin
        if (mode_we)
            mode <= mode_i;
        if (mtime_we)
            mtime <= mtime_i;
        if (mtimecmp_we)
            mtimecmp <= mtimecmp_i;
    end
end
endmodule
