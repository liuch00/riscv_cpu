`default_nettype none

module thinpad_top(
    input wire clk_50M,           
    input wire clk_11M0592,       

    input wire clock_btn,         
    input wire reset_btn,         

    input  wire[3:0]  touch_btn,  
    input  wire[31:0] dip_sw,     
    output wire[15:0] leds,       
    output wire[7:0]  dpy0,       
    output wire[7:0]  dpy1,       

    //CPLD
    output wire uart_rdn,         
    output wire uart_wrn,        
    input wire uart_dataready,    
    input wire uart_tbre,         
    input wire uart_tsre,         

    //BaseRAM
    inout wire[31:0] base_ram_data,  
    output wire[19:0] base_ram_addr, 
    output wire[3:0] base_ram_be_n,  
    output wire base_ram_ce_n,       
    output wire base_ram_oe_n,       
    output wire base_ram_we_n,       

    //ExtRAM
    inout wire[31:0] ext_ram_data,  
    output wire[19:0] ext_ram_addr, 
    output wire[3:0] ext_ram_be_n,  
    output wire ext_ram_ce_n,       
    output wire ext_ram_oe_n,       
    output wire ext_ram_we_n,       

    
    output wire txd,  
    input  wire rxd,  

    //Flash
    output wire [22:0]flash_a,      
    inout  wire [15:0]flash_d,      
    output wire flash_rp_n,         
    output wire flash_vpen,         
    output wire flash_ce_n,         
    output wire flash_oe_n,         
    output wire flash_we_n,         
    output wire flash_byte_n,       

    //USB 
    output wire sl811_a0,
    //inout  wire[7:0] sl811_d,     
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    
    output wire dm9k_cmd,
    inout  wire[15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input  wire dm9k_int,

    
    output wire[2:0] video_red,    
    output wire[2:0] video_green,  
    output wire[1:0] video_blue,   
    output wire video_hsync,       
    output wire video_vsync,       
    output wire video_clk,         
    output wire video_de           
    );

/* =========== Demo code begin =========== */

// PLL
wire [11:0] hdata;
wire [11:0] vdata;
// assign video_red = 1; //红色竖条
// assign video_green = 3'b111; //绿色竖条
// assign video_blue = 2'b11; //蓝色竖条
assign video_clk = clk_50M;
wire[7:0] vga;
vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
    .clk(clk_50M), 
    .reset(reset_btn),
    .hdata(hdata), //横坐�????
    .vdata(vdata),      //纵坐�????
    .hsync(video_hsync),
    .vsync(video_vsync),
    .data_enable(video_de)
);

vga_show VGA_show(
    .hdata(hdata),
    .vdata(vdata),
    .vga(vga),
    .video_red(video_red),
    .video_green(video_green),
    .video_blue(video_blue),
    .enb(enb),
    .addrb(addrb),
    .doutb(doutb)
);

wire locked, clk_10M, clk_20M;
pll_example clock_gen 
(
  // Clock in ports
  .clk_in1(clk_50M),  
  // Clock out ports
  .clk_out1(clk_10M), 
  .clk_out2(clk_20M), 
  // Status and control signals        
  .reset(reset_btn), 
  .locked(locked)    
  
  );

reg reset_of_clk10M;
always@(posedge clk_10M or negedge locked) begin
    if(~locked) reset_of_clk10M <= 1'b1;
    else        reset_of_clk10M <= 1'b0;
end


//ID branch prediction used info
wire branch_request_w;
wire branch_is_call_w;
wire branch_is_ret_w;
wire branch_is_jmp_w;
wire branch_is_taken_w;
wire branch_is_not_taken_w;
wire [31:0] branch_source_w;
wire [31:0] branch_pc_w;
wire branch_d_request_w;
wire[31:0]  branch_d_pc_w;



wire pc_accept_w;
wire pred_error_w;
//IF stage

wire [31:0] if_pc; 
wire [5:0] stall; 

wire id_pc_branch_flag; 
wire [31:0] id_pc_branch_target; 

//if-pc module
if_pc IF_PC(
    .clock(clk_50M),
    .reset(reset_btn),
    .pc_branch_flag(id_pc_branch_flag),
    .pc_branch_target(id_pc_branch_target),
    .stall(stall),

    .cs_target(cs_target),
    .cs_taken(context_switch_by_exception),

    .pc(if_pc),

    .pc_accept(pc_accept_w),
    //ID branch prediction used info
    .branch_request(branch_request_w),
    .branch_is_call(branch_is_call_w),
    .branch_is_ret(branch_is_ret_w),
    .branch_is_jmp(branch_is_jmp_w),
    .branch_is_taken(branch_is_taken_w),
    .branch_is_not_taken(branch_is_not_taken_w),
    .branch_source(branch_source_w),
    .branch_pc(branch_pc_w),
    .branch_d_request(branch_d_request_w),
    .branch_d_pc(branch_d_pc_w),
    .pred_error(pred_error_w)
    );

//if-id
wire [31:0] if_id_pc;
wire [31:0] if_id_instr;
//if-id module
if_id IF_ID(
    .clock(clk_50M),
    .reset(reset_btn),
    .stall(stall),
    .cs_taken(context_switch_by_exception),
    .instr_from_ram(sram_uart_data),
    .pc_from_if(if_pc),
    .if_id_instr(if_id_instr),
    .if_id_pc(if_id_pc),
    .pc_accept(pc_accept_w)
    );
//ID stage
wire[31:0] data1_from_reg;
wire[31:0] data2_from_reg;
wire[31:0] id_data2_out;
wire[4:0] id_reg_addr1;
wire[4:0] id_reg_addr2;

wire[4:0] id_reg_addr_des;
wire[31:0] id_alu_A;
wire[31:0] id_alu_B;
wire[4:0] id_alu_op;
wire id_reg_w_enable;

wire[1:0] id_call_break_ret;
wire id_csr_we;
wire[11:0] id_csr_waddr;
wire[2:0] id_csr_op;
wire[31:0] id_csr_rs1;

wire id_instr_is_load;
wire exe_instr_is_load;



//regfile
wire[4:0] mem_wb_reg_w_addr;
wire mem_wb_reg_w_enable;
wire [31:0] mem_wb_reg_w_data;


regfile REG_FILE(
    .clk(clk_50M),
    .rst(reset_btn),
    .raddr1(id_reg_addr1),
    .raddr2(id_reg_addr2),
    .waddr(mem_wb_reg_w_addr),
    .we(mem_wb_reg_w_enable),
    .wdata(mem_wb_reg_w_data),
    .rdata1(data1_from_reg),
    .rdata2(data2_from_reg)
);

// CSR
wire[11:0] csr_raddr;
wire[31:0] csr_rdata;
wire[31:0] csr_mstatus_o;
wire[31:0] csr_mie_o;
wire[31:0] csr_mtvec_o;
wire[31:0] csr_mscratch_o;
wire[31:0] csr_mepc_o;
wire[31:0] csr_mcause_o;
wire[31:0] csr_mip_o;

wire csr_selection_we;
wire[11:0] csr_waddr;
wire[31:0] csr_wdata;
wire csr_direct_we;
wire[31:0] csr_mstatus_i;
wire[31:0] csr_mie_i;
wire[31:0] csr_mtvec_i;
wire[31:0] csr_mscratch_i;
wire[31:0] csr_mepc_i;
wire[31:0] csr_mcause_i;
wire[31:0] csr_mip_i;

csr CSR(
    .clock(clk_50M),
    .reset(reset_btn),
    // selection read
    .raddr(csr_raddr),  // address of register to read
    .rdata(csr_rdata),
    // direct read
    .mstatus(csr_mstatus_o),
    .mie(csr_mie_o),
    .mtvec(csr_mtvec_o),
    .mscratch(csr_mscratch_o),
    .mepc(csr_mepc_o),
    .mcause(csr_mcause_o),
    .mip(csr_mip_o),
    // seletion write
    .selection_we(csr_selection_we),  // 1 is enable
    .waddr(csr_waddr),
    .wdata(csr_wdata),
    // direct write
    .direct_we(csr_direct_we),  // 1 is enable, if this is enabled, selection we will be ignored
    .mstatus_i(csr_mstatus_i),
    .mie_i(csr_mie_i),
    .mtvec_i(csr_mtvec_i),
    .mscratch_i(csr_mscratch_i),
    .mepc_i(csr_mepc_i),
    .mcause_i(csr_mcause_i),
    .mip_i(csr_mip_i),
    // exception output
    .csr_addr_expcetion()  // this can cause "illegal instruction exception"
);

//decoder
wire stallreq_from_id;

// mem forward
wire[4:0] mem_w_addr;
wire mem_w_enable;
wire[31:0] mem_w_data;

//id module
id ID(
    .clk(clk_50M),
    .reset(reset_btn),

   .if_id_pc(if_id_pc),
   .if_id_instr(if_id_instr),
   .data1_from_reg(data1_from_reg),
   .data2_from_reg(data2_from_reg),
   .csr_raddr(csr_raddr),
   .csr_rdata(csr_rdata),
    
   .exe_id_alu_op(exe_alu_op),
   .exe_rd(exe_dst_addr),
   .exe_wreg(exe_w_enable),
   .exe_wdata(exe_reg_wdata),
   .mem_rd(mem_w_addr),
   .mem_wreg(mem_w_enable),
   .mem_wdata(mem_w_data),
   .pre_instr_is_load(exe_instr_is_load),
   
   .reg_addr1(id_reg_addr1),
   .reg_addr2(id_reg_addr2),
   
   .id_alu_op(id_alu_op),
   .id_alu_a(id_alu_A),
   .id_alu_b(id_alu_B),
   .id_reg_addr_des(id_reg_addr_des),
   .id_reg_w_enable(id_reg_w_enable),
   .reg_data2(id_data2_out),
   .instr_is_load(id_instr_is_load),
   
   .exp_call_break_ret(id_call_break_ret),
   .csr_we(id_csr_we),
   .csr_waddr(id_csr_waddr),
   .csr_op(id_csr_op),
   .csr_rs1(id_csr_rs1),
   
   .pc_branch_flag(id_pc_branch_flag),
   .pc_branch_target(id_pc_branch_target),
   .stallreq(stallreq_from_id),

    //branch prediction
    .branch_request(branch_request_w),
    .branch_is_call(branch_is_call_w),
    .branch_is_ret(branch_is_ret_w),
    .branch_is_jmp(branch_is_jmp_w),
    .branch_is_taken(branch_is_taken_w),
    .branch_is_not_taken(branch_is_not_taken_w),
    .branch_source(branch_source_w),
    .branch_pc(branch_pc_w),
    .branch_d_request(branch_d_request_w),
    .branch_d_pc(branch_d_pc_w)
);

//id-exe
wire[31:0] id_exe_reg_data2;
wire[31:0] id_exe_pc;

id_exe ID_EX(
    .clock(clk_50M),
    .reset(reset_btn),
    .stall(stall),
    .cs_taken(context_switch_by_exception),
    .id_alu_op(id_alu_op),
    .id_alu_A(id_alu_A),
    .id_alu_B(id_alu_B),
    .id_dst_addr(id_reg_addr_des),
    .id_reg_w_enable(id_reg_w_enable),
    .id_reg_data2(id_data2_out),
    .id_instr_is_load(id_instr_is_load),
    .id_call_break_ret(id_call_break_ret),
    .id_csr_we(id_csr_we),
    .id_csr_waddr(id_csr_waddr),
    .id_csr_op(id_csr_op),
    .id_csr_rs1(id_csr_rs1),
    .id_pc(if_id_pc),

    .exe_alu_op(id_exe_alu_op),
    .exe_alu_A(id_exe_alu_A),
    .exe_alu_B(id_exe_alu_B),
    .exe_dst_addr(id_exe_dst_addr),
    .exe_reg_data2(id_exe_reg_data2),
    .exe_w_enable(id_exe_w_enable),
    .exe_instr_is_load(exe_instr_is_load),
    .exe_call_break_ret(exe_call_break_ret),
    .exe_csr_we(exe_csr_we),
    .exe_csr_waddr(exe_csr_waddr),
    .exe_csr_op(exe_csr_op),
    .exe_csr_rs1(exe_csr_rs1),
    .exe_pc(id_exe_pc)
);
//EXE stage
wire[4:0] id_exe_alu_op;
wire[31:0] id_exe_alu_A;
wire[31:0] id_exe_alu_B;
wire[4:0]  id_exe_dst_addr;
wire id_exe_w_enable;

wire[31:0] alu_result;//not used
wire [5:0] exe_dst_addr;
wire exe_w_enable;
wire [31:0] exe_reg_data2;
wire [4:0] exe_alu_op;
wire [31:0] exe_sram_addr;
wire [31:0] exe_reg_wdata;


exe EXE(
    .exe_alu_A(id_exe_alu_A),
    .exe_alu_B(id_exe_alu_B),
    .exe_alu_op(id_exe_alu_op),
    .exe_dst_addr(id_exe_dst_addr),
    .exe_w_enable(id_exe_w_enable),
    .exe_reg_data2(id_exe_reg_data2),

    .rd_o(exe_dst_addr),
    .wreg_o(exe_w_enable),
    .reg_data2_o(exe_reg_data2),
    .alu_op_o(exe_alu_op),
    .mem_addr_o(exe_sram_addr),
    .reg_wdata_o(exe_reg_wdata)
    );

// detect whether there will be exception in MEM phase
wire exp_mem_store_access;
wire exp_mem_load_access;
memExpDetector MemExpDetector(
    .address(exe_sram_addr),
    .alu_op(id_exe_alu_op),
    .exp_mem_store_access(exp_mem_store_access),
    .exp_mem_load_access(exp_mem_load_access)
);

// ExceptionHandler
wire[1:0] exe_call_break_ret;
wire exe_csr_we;
wire[31:0] exe_csr_rs1;
wire[11:0] exe_csr_waddr;
wire[2:0] exe_csr_op;

wire context_switch_by_exception;
wire[31:0] cs_target;

wire[63:0] mtime;
wire[63:0] mtimecmp;

exceptionHandler ExceptionHandler(
    .clock(clk_50M),
    .reset(reset_btn),

    .mstatus_i(csr_mstatus_o),
    .mie_i(csr_mie_o),
    .mtvec_i(csr_mtvec_o),
    .mscratch_i(csr_mscratch_o),
    .mepc_i(csr_mepc_o),
    .mcause_i(csr_mcause_o),
    .mip_i(csr_mip_o),
    
    .direct_we(csr_direct_we),
    .mstatus_o(csr_mstatus_i),
    .mie_o(csr_mie_i),
    .mtvec_o(csr_mtvec_i),
    .mscratch_o(csr_mscratch_i),
    .mepc_o(csr_mepc_i),
    .mcause_o(csr_mcause_i),
    .mip_o(csr_mip_i),
    
    .selection_we(csr_selection_we),
    .csr_wdata(csr_wdata),
    .csr_waddr(csr_waddr),
    
    .exe_we(exe_csr_we),
    .exe_csr(id_exe_alu_A),  // from EXE input
    .exe_rs1(exe_csr_rs1),
    .exe_waddr(exe_csr_waddr),
    .csr_op(exe_csr_op),
    
    .exe_call_break_ret(exe_call_break_ret),
    .mem_store_access(exp_mem_store_access),
    .mem_load_access(exp_mem_load_access),
    
    .context_switch_by_exception(context_switch_by_exception),
    .cs_target(cs_target),
    
    .pc_exe(id_exe_pc),
    /*
    .mode(mode),
    .mode_o(mode_i),
    .mode_we(mode_we),*/
    .mtime(mtime),
    .mtimecmp(mtimecmp)
);


wire[5:0]   exe_mem_rd;
wire exe_mem_w_enable;
wire [31:0] exe_mem_reg_data2;
wire [4:0] exe_mem_alu_op;
wire[31:0] exe_mem_wdata;
wire[31:0] exe_mem_addr;

exe_mem EXE_MEM(
    .clk(clk_50M),
    .rst(reset_btn),
    .stall(stall),
    .exe_wdata_i(exe_reg_wdata),
    .exe_rd_i(exe_dst_addr),
    .exe_wreg_i(exe_w_enable),
    .exe_reg_data2_i(exe_reg_data2),
    .exe_alu_op(exe_alu_op),
    .ex_addr_i(exe_sram_addr),

    .mem_rd_o(exe_mem_rd),
    .mem_wreg_o(exe_mem_w_enable),
    .mem_reg_data2_o(exe_mem_reg_data2),
    .mem_alu_op_o(exe_mem_alu_op),
    .mem_wdata_o(exe_mem_wdata),
    .mem_addr_o(exe_mem_addr)
    );
//mem stage

wire is_byte_o;//not used
wire[31:0] mem_data_to_sram;
wire[31:0] mem_addr_to_sram;
wire mem_ram_req;
wire mem_ram_read;

mem MEM(
    .exe_mem_addr(exe_mem_addr),
    .data_in_i(exe_mem_reg_data2),
    .alu_op_i(exe_mem_alu_op),
    .sram_to_mem_data_i(exe_mem_wdata),
    .rd_i(exe_mem_rd),
    .wreg_i(exe_mem_w_enable),
    .read_from_sram_i(sram_uart_data),

    .is_byte_o(is_byte_o),
    .mem_data_to_sram(mem_data_to_sram),
    .mem_addr_to_sram(mem_addr_to_sram),

    .mem_ram_req(mem_ram_req),
    .mem_ram_read(mem_ram_read),

    .rd_o(mem_w_addr),
    .wreg_o(mem_w_enable),
    .reg_wdata_o(mem_w_data)
    );

// mem_wb


mem_wb MEM_WB (
    .clk(clk_50M),
    .rst(reset_btn),

    .stall(stall),

    .mem_rd(mem_w_addr),
    .mem_wreg(mem_w_enable),
    .mem_wdata(mem_w_data),

    .wb_rd(mem_wb_reg_w_addr),
    .wb_wreg(mem_wb_reg_w_enable),
    .wb_wdata(mem_wb_reg_w_data)
    );

//wb stage
wire[31:0] sram_uart_data;
wire if_stall;
wire mem_stall;
sram_uart SRAM_UART (
    .clk(clk_50M),
    .reset(reset_btn),
    .mem_stall(mem_stall),
    .vga(vga),
    .pc(if_pc),
    .if_stall(if_stall),
    .alu_op(exe_mem_alu_op),
    .mem_address(mem_addr_to_sram),
    .mem_need(mem_ram_req),
    .mem_read_or_write(mem_ram_read),
    .mem_write_data(mem_data_to_sram),
    .mem_read_data(sram_uart_data),
    
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre),
    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn),
    
    
    .base_ram_data_wire(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_we_n(base_ram_we_n),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_be_n(base_ram_be_n),

    .ext_ram_data_wire(ext_ram_data),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_we_n(ext_ram_we_n),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_be_n(ext_ram_be_n),

    .ena(ena),
    .wea(wea),
    .addra(addra),
    .dina(dina),
    
    .mtime(mtime),
    .mtimecmp(mtimecmp)
);
ctrl CTRL(
    .rst(reset_btn),
    .stallreq_from_mem(mem_stall),
    .stallreq_from_id(stallreq_from_id),
    .stallreq_from_if(if_stall),
    .branch_req(id_pc_branch_flag),
    .pred_error(pred_error_w),
    .stall(stall)
);
wire ena;
wire wea;
wire[16:0] addra;
wire[7:0] dina;
wire enb;
wire[16:0] addrb;
wire[7:0] doutb;
blk_mem_gen_0 blk(
    .clka(clk_50M),
    .ena(ena),
    .wea(wea),
    .addra(addra),
    .dina(dina),
    .clkb(clk_50M),
    .enb(enb),
    .addrb(addrb),
    .doutb(doutb)
);

endmodule
