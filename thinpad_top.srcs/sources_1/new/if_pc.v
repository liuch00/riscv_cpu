`include "macro.vh"

module if_pc (
    input wire reset,
    input wire clock,
    input wire[31:0] pc_branch_target,
    input wire pc_branch_flag,
    input wire[5:0] stall,

    input wire[31:0] cs_target,
    input wire cs_taken,

    output reg[31:0] pc,

    //About pc_accept
    //When the SRAM component returns to the idle state, 
    //if the MEM has no memory access requirements, 
    //read the location pointed to by the PC
    input wire pc_accept,

    //ID branch prediction
    input wire branch_request,
    input wire branch_is_call,
    input wire branch_is_ret,
    input wire branch_is_jmp,
    input wire branch_is_taken,
    input wire branch_is_not_taken,
    input wire [31:0] branch_source,
    input wire [31:0] branch_pc,
    input wire branch_d_request,
    input wire[31:0]  branch_d_pc,

    output reg  pred_error

    );
localparam RAS_INVALID = 32'h00000001;

wire[ 31:0]  next_pc;
wire         next_taken;

//-------------------------------------------------------------
// NO  Branch prediction !!!
//-------------------------------------------------------------
// always @(posedge clock or posedge reset) begin
//     if(reset) begin
//         pc <= 32'h80000000;
//     end
//     else if(stall[0] == 0) begin
//         if (pc_branch_flag) begin
//             pc <= pc_branch_target;
//         end
//         else
//             pc <= pc + 4;
//     end
//     else if(stall[0] == 1 && pc_branch_flag && stall[5] != 1) begin
//         //when if stall and pc jump and pipe not stall ,pc jump
//         pc <= pc_branch_target;
//     end
// end


//-------------------------------------------------------------
// Branch prediction (BTB, BHT, RAS)!!!
//-------------------------------------------------------------








wire        pred_taken;
wire        pred_ntaken;

// Info from BTB
wire        btb_valid;
wire [31:0] btb_next_pc;
wire        btb_is_call;
wire        btb_is_ret;

//-------------------------------------------------------------
// Return Address Stack (actual)
//-------------------------------------------------------------
reg [`NUM_RAS_ENTRIES_W -1:0] ras_index_real_q;
reg [`NUM_RAS_ENTRIES_W -1:0] ras_index_real_r;

//ras_index_real_q is what we will use in later.
//ras_index_real_r is used to update.
//call  =>  index+1
//ret   =>  index-1

always @ (*)
begin
    ras_index_real_r = ras_index_real_q;

    if (branch_request & branch_is_call)
        ras_index_real_r = ras_index_real_q + 1;
    else if (branch_request & branch_is_ret)
        ras_index_real_r = ras_index_real_q - 1;
end

always @ (posedge clock or posedge reset)begin
if (reset)
    ras_index_real_q <= {`NUM_RAS_ENTRIES_W{1'b0}};
else
    ras_index_real_q <= ras_index_real_r;
end
//-------------------------------------------------------------
// Return Address Stack (speculative)
//-------------------------------------------------------------
reg [31:0] ras_stack_q[`NUM_RAS_ENTRIES-1:0];
reg [`NUM_RAS_ENTRIES_W-1:0] ras_index_q;
reg [`NUM_RAS_ENTRIES_W-1:0] ras_index_r;


//ras_index_q is we will use in later.
//ras_index_r is used to update.

wire [31:0] ras_pc_pred     = ras_stack_q[ras_index_q];
wire        ras_call_pred   = `RAS_ENABLE & (btb_valid & btb_is_call) & ~ras_pc_pred[0];
wire        ras_ret_pred    = `RAS_ENABLE & (btb_valid & btb_is_ret) & ~ras_pc_pred[0];


always @ (*)
begin
    ras_index_r = ras_index_q;

    // Mispredict - go from confirmed call stack index
    if (branch_request & branch_is_call)
        ras_index_r = ras_index_real_q + 1;
    else if (branch_request & branch_is_ret)
        ras_index_r = ras_index_real_q - 1;
    // Speculative call / returns
    else if (ras_call_pred & pc_accept)
        ras_index_r = ras_index_q + 1;
    else if (ras_ret_pred & pc_accept)
        ras_index_r = ras_index_q - 1;
end

integer int_i3;
always @ (posedge clock or posedge reset)begin
    if (reset)
    begin
        for (int_i3 = 0; int_i3 < `NUM_RAS_ENTRIES; int_i3 = int_i3 + 1) 
        begin
            ras_stack_q[int_i3] <= RAS_INVALID;
        end
        ras_index_q <= {`NUM_RAS_ENTRIES_W{1'b0}};
    end

    // On a call push return address onto RAS stack (current PC + 4)
    else if (branch_request & branch_is_call)
    begin
        ras_stack_q[ras_index_r] <= branch_source + 32'd4;
        ras_index_q              <= ras_index_r;
    end
    // On a call push return address onto RAS stack (current PC + 4)
    else if (ras_call_pred & pc_accept)
    begin
        ras_stack_q[ras_index_r] <= pc + 32'd4;
        ras_index_q              <= ras_index_r;
    end
    // Return - pop item from stack
    else if ((ras_ret_pred & pc_accept) || (branch_request & branch_is_ret))
    begin
        ras_index_q              <= ras_index_r;
    end

end
//-------------------------------------------------------------
// Global history register (actual history)
//-------------------------------------------------------------

reg [`NUM_BHT_ENTRIES_W-1:0] global_history_real_q;

always @ (posedge clock or posedge reset)
begin
    if (reset)
        global_history_real_q <= {`NUM_BHT_ENTRIES_W{1'b0}};
    else if (branch_is_taken || branch_is_not_taken)
        global_history_real_q <= {global_history_real_q[`NUM_BHT_ENTRIES_W-2:0], branch_is_taken};
end

//-------------------------------------------------------------
// Global history register (speculative)
//-------------------------------------------------------------
reg [`NUM_BHT_ENTRIES_W-1:0] global_history_q;

always @ (posedge clock or posedge reset)begin

    if (reset)begin
        global_history_q <= {`NUM_BHT_ENTRIES_W{1'b0}};
    end
    // Mispredict - revert to actual branch history to flush out speculative errors
    else if (branch_request)begin
        global_history_q <= {global_history_real_q[`NUM_BHT_ENTRIES_W-2:0], branch_is_taken};
    end
    // Predicted branch
    else if (pred_taken || pred_ntaken)begin
        global_history_q <= {global_history_q[`NUM_BHT_ENTRIES_W-2:0], pred_taken};
    end
end

always@(*)begin
    pred_error=0;
    if (branch_request)begin
        if(pc_branch_flag==1&&pc_branch_target!=pc)    begin
            pred_error =1'b1;  
        end
        else if (pc_branch_flag==0&&pc!=old_pc+4 &&pc!=32'h80000000)begin
            pred_error =1'b1; 
        end
    end
end
//-------------------------------------------------------------
// Branch prediction bits
//-------------------------------------------------------------
reg [1:0]   bht_sat_q[`NUM_BHT_ENTRIES-1:0];


wire [`NUM_BHT_ENTRIES_W-1:0] gshare_wr_entry = (branch_request ? global_history_real_q : global_history_q) ^ branch_source[2+`NUM_BHT_ENTRIES_W-1:2];
wire [`NUM_BHT_ENTRIES_W-1:0] gshare_rd_entry = global_history_q ^ {pc[3+`NUM_BHT_ENTRIES_W-2:3],1'b1};

wire [`NUM_BHT_ENTRIES_W-1:0] bht_wr_entry = `GSHARE_ENABLE ? gshare_wr_entry : branch_source[2+`NUM_BHT_ENTRIES_W-1:2];
wire [`NUM_BHT_ENTRIES_W-1:0] bht_rd_entry = `GSHARE_ENABLE ? gshare_rd_entry : {pc[3+`NUM_BHT_ENTRIES_W-2:3],1'b1};

integer int_i4;
always @ (posedge clock or posedge reset)
if (reset)
begin
    for (int_i4 = 0; int_i4 < `NUM_BHT_ENTRIES; int_i4 = int_i4 + 1)
    begin
        bht_sat_q[int_i4] <= 2'd3;
    end
end
else if (branch_is_taken && bht_sat_q[bht_wr_entry] < 2'd3)
    bht_sat_q[bht_wr_entry] <= bht_sat_q[bht_wr_entry] + 2'd1;
else if (branch_is_not_taken && bht_sat_q[bht_wr_entry] > 2'd0)
    bht_sat_q[bht_wr_entry] <= bht_sat_q[bht_wr_entry] - 2'd1;

wire bht_predict_taken= `BHT_ENABLE && (bht_sat_q[bht_rd_entry] >= 2'd2);

//-------------------------------------------------------------
// Branch target buffer
//-------------------------------------------------------------

reg [31:0]  btb_pc_q[`NUM_BTB_ENTRIES-1:0];
reg [31:0]  btb_target_q[`NUM_BTB_ENTRIES-1:0];
reg         btb_is_call_q[`NUM_BTB_ENTRIES-1:0];
reg         btb_is_ret_q[`NUM_BTB_ENTRIES-1:0];
reg         btb_is_jmp_q[`NUM_BTB_ENTRIES-1:0];

reg         btb_valid_r;
reg         btb_is_call_r;
reg         btb_is_ret_r;
reg [31:0]  btb_next_pc_r;
reg         btb_is_jmp_r;

reg [`NUM_BTB_ENTRIES_W-1:0] btb_entry_r;
integer int_i0;

always @ (*)
begin
    btb_valid_r   = 1'b0;
    btb_is_call_r = 1'b0;
    btb_is_ret_r  = 1'b0;
    btb_is_jmp_r  = 1'b0;
    btb_next_pc_r = {pc[31:2],2'b0} + 32'd4;
    btb_entry_r   = {`NUM_BTB_ENTRIES_W{1'b0}};

    for (int_i0 = 0; int_i0 < `NUM_BTB_ENTRIES; int_i0 = int_i0 + 1)
    begin
        if (btb_pc_q[int_i0] == pc)
        begin
            btb_valid_r   = 1'b1;
            btb_is_call_r = btb_is_call_q[int_i0];
            btb_is_ret_r  = btb_is_ret_q[int_i0];
            btb_is_jmp_r  = btb_is_jmp_q[int_i0];
            btb_next_pc_r = btb_target_q[int_i0];
/* verilator lint_off WIDTH */
            btb_entry_r   = int_i0;
/* verilator lint_on WIDTH */
        end
    end
end





reg [`NUM_BTB_ENTRIES_W-1:0]  btb_wr_entry_r;
wire [`NUM_BTB_ENTRIES_W-1:0] btb_wr_alloc_w;

reg btb_hit_r;
reg btb_miss_r;
integer int_i1;
always @ (*)
begin
    btb_wr_entry_r = {`NUM_BTB_ENTRIES_W{1'b0}};
    btb_hit_r      = 1'b0;
    btb_miss_r     = 1'b0;

    // Misprediction - learn / update branch details
    if (branch_request)
    begin
        for (int_i1 = 0; int_i1 < `NUM_BTB_ENTRIES; int_i1 = int_i1 + 1)
        begin
            if (btb_pc_q[int_i1] == branch_source)
            begin
                btb_hit_r      = 1'b1;
    /* verilator lint_off WIDTH */
                btb_wr_entry_r = int_i1;
    /* verilator lint_on WIDTH */
            end
        end
        btb_miss_r = ~btb_hit_r;
    end
end

integer int_i2;
always @ (posedge clock or posedge reset)
begin
    if (reset)
    begin
        for (int_i2 = 0; int_i2 < `NUM_BTB_ENTRIES; int_i2 = int_i2 + 1)
        begin
            btb_pc_q[int_i2]     <= 32'b0;
            btb_target_q[int_i2] <= 32'b0;
            btb_is_call_q[int_i2]<= 1'b0;
            btb_is_ret_q[int_i2] <= 1'b0;
            btb_is_jmp_q[int_i2] <= 1'b0;
        end
    end
    // Hit - update entry
    else if (btb_hit_r)
    begin
        btb_pc_q[btb_wr_entry_r]     <= branch_source;
        if (branch_is_taken)
            btb_target_q[btb_wr_entry_r] <= branch_pc;
        btb_is_call_q[btb_wr_entry_r]<= branch_is_call;
        btb_is_ret_q[btb_wr_entry_r] <= branch_is_ret;
        btb_is_jmp_q[btb_wr_entry_r] <= branch_is_jmp;
    end
    // Miss - allocate entry
    else if (btb_miss_r)
    begin
        btb_pc_q[btb_wr_alloc_w]     <= branch_source;
        btb_target_q[btb_wr_alloc_w] <= branch_pc;
        btb_is_call_q[btb_wr_alloc_w]<= branch_is_call;
        btb_is_ret_q[btb_wr_alloc_w] <= branch_is_ret;
        btb_is_jmp_q[btb_wr_alloc_w] <= branch_is_jmp;
    end
end

//-------------------------------------------------------------
// Replacement Selection
//-------------------------------------------------------------
pc_lfsr
#(
    .DEPTH(`NUM_BTB_ENTRIES),
    .ADDR_W(`NUM_BTB_ENTRIES_W)
)
u_lru
(
    .clock(clock),
    .reset(reset),

    .hit(btb_valid_r),
    .hit_entry(btb_entry_r),

    .alloc(btb_miss_r),
    .alloc_entry(btb_wr_alloc_w)
);




assign btb_valid   = btb_valid_r;
assign btb_is_call = btb_is_call_r;
assign btb_is_ret  = btb_is_ret_r;
assign next_pc   = ras_ret_pred      ? ras_pc_pred : 
                       (bht_predict_taken | btb_is_jmp_r) ? btb_next_pc_r :
                        {pc[31:2],2'b0} + 32'd4;

assign next_taken = (btb_valid & (ras_ret_pred | bht_predict_taken | btb_is_jmp_r)) ? 
                         1'b1 :1'b0;

assign pred_taken   = btb_valid & (ras_ret_pred | bht_predict_taken | btb_is_jmp_r) & pc_accept;
assign pred_ntaken  = btb_valid & ~pred_taken & pc_accept;





reg [31:0] old_pc;

always @(posedge clock or posedge reset) begin
    if(reset) begin
        pc <= 32'h80000000;
        old_pc <= 32'h80000000;
    end
    else if(stall[0] == 0 && cs_taken == 0) begin
        //pipe work well
        if(pred_error==1)begin
            old_pc<=pc;
            if (pc_branch_flag) begin
                pc<=pc_branch_target;
            end
            else begin
                pc <= old_pc+4;
            end
        end 
        else begin
            old_pc<=pc;
            pc <= next_pc;
        end
    end
    else if (cs_taken) begin  // context switch raised by exception
        pc <= cs_target;
    end
    else if(stall == 6'b000011 && pred_error) begin
        if (pc_branch_flag) begin
            pc<=pc_branch_target;
        end
        else begin
            pc <= old_pc;
        end
    end 

end






endmodule


//-------------------------------------------------------------
// Linear Feedback Shift Registe
//-------------------------------------------------------------

module pc_lfsr
#(
    parameter DEPTH            = 32,
    parameter ADDR_W           = 5,
    parameter INITIAL_VALUE    = 16'h0001,
    parameter TAP_VALUE        = 16'hB400
)
(
    // Inputs
    input           wire clock,
    input           wire reset,
    input           wire hit,
    input           wire [ADDR_W-1:0]  hit_entry,
    input           wire    alloc,
    // Outputs
    output          wire [ADDR_W-1:0]  alloc_entry
);

reg [15:0] lfsr;

always @ (posedge clock or posedge reset)
if (reset)
    lfsr <= INITIAL_VALUE;
else if (alloc)
begin
    if (lfsr[0])
        lfsr <= {1'b0, lfsr[15:1]} ^ TAP_VALUE;
    else
        lfsr <= {1'b0, lfsr[15:1]};
end

assign alloc_entry = lfsr[ADDR_W-1:0];




endmodule



