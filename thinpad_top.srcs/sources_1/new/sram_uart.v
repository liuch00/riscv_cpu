`timescale 1ns / 1ps
`include "macro.vh"
`define STATE_IDLE 6'b000000
`define STATE_READ_UART_1 6'b000001
`define STATE_READ_UART_2 6'b000010
`define STATE_WRITE_UART_1 6'b000011
`define STATE_WRITE_UART_2 6'b000100
`define STATE_WRITE_UART_3 6'b000101
`define STATE_READ_SRAM_1 6'b000110
`define STATE_READ_SRAM_2 6'b000111
`define STATE_WRITE_SRAM_1 6'b001000
`define STATE_WRITE_SRAM_2 6'b001001
`define STATE_WRITE_SRAM_3 6'b001010
`define STATE_IDLE_0 6'b001011
`define STATE_RUN 6'b111111

`define STATE_WRITE_BRAM 6'b001100
`define STATE_READ_BRAM 6'b001101

`define STATE_TIME 6'b100000
`define STATE_TIMECMP 6'b100001

module sram_uart(
    //if
    input wire clk,
    input wire reset,
    input wire [31:0] pc,
    output wire if_stall,
    output reg mem_stall,
    //mem
    input wire[31:0] mem_address,
    input wire[31:0] mem_write_data,
    output reg[31:0] mem_read_data,
    input wire mem_need,                    //1 means need mem 
    input wire mem_read_or_write,           //1 is read and 0 is wirte
    input wire[4:0] alu_op,
    output reg[7:0] vga,

    //CPLD
    output reg uart_rdn,                
    output reg uart_wrn,                  
    input wire uart_dataready,         
    input wire uart_tbre,      
    input wire uart_tsre,                

    //BaseRAM
    inout wire[31:0] base_ram_data_wire,   
    output reg[19:0] base_ram_addr, 
    output reg[3:0] base_ram_be_n,       
    output reg base_ram_ce_n,          
    output reg base_ram_oe_n,          
    output reg base_ram_we_n,              

    //ExtRAM
    inout wire[31:0] ext_ram_data_wire,     
    output reg[19:0] ext_ram_addr,        
    output reg[3:0] ext_ram_be_n,          
    output reg ext_ram_ce_n,               
    output reg ext_ram_oe_n,               
    output reg ext_ram_we_n,

    output reg ena,
    output reg wea,
    output reg[16:0] addra,
    output reg[7:0] dina,              

    // mtime and mtimecmp
    output reg[63:0] mtime,
    output reg[63:0] mtimecmp
);

reg[58:0] cache[63:0];//31-0 bits represent dataï¿???32 bit represents validityï¿???58-33 bits represent tag

wire [31:0]address;
assign address = mem_need ? mem_address : pc;
assign if_stall = mem_need;
reg[5:0] state;
reg base_data_z;
reg ext_data_z;
reg[31:0] sram_data_reg;
assign base_ram_data_wire = base_data_z ? 32'bz : sram_data_reg;
assign ext_ram_data_wire = ext_data_z ? 32'bz : sram_data_reg;
always @(posedge clk or posedge reset) begin
    if(reset == 1) begin
        state <= `STATE_IDLE;
        mem_stall <= 1;
        // cache[63][58] = {3776'b0};
        for(integer i = 0; i <= 63; i = i + 1) begin
            cache[i] <= 59'b0;
        end

        mem_read_data <= 32'b0;

        uart_wrn <= 1;
        uart_rdn <= 1;

        base_ram_addr <= 20'b0;
        base_ram_be_n <= 4'b0000;
        base_ram_ce_n <= 0;
        base_ram_oe_n <= 1;
        base_ram_we_n <= 1;

        ext_ram_addr <= 20'b0;
        ext_ram_be_n <= 4'b0000;
        ext_ram_ce_n <= 0;
        ext_ram_oe_n <= 1;
        ext_ram_we_n <= 1;

        base_data_z <= 1;
        ext_data_z <= 1;
        sram_data_reg <= 32'b0;

        ena <= 0;
        wea <= 0;
        addra <= 17'b0;
        dina <= 8'b0;
        
        mtime <= 64'b0;
        mtimecmp <= 64'hffffffffffffffff;
    end
    else if(state == `STATE_IDLE)begin

        uart_wrn <= 1;
        uart_rdn <= 1;
        
        base_ram_addr <= 20'b0;
        base_ram_be_n <= 4'b0000;
        base_ram_oe_n <= 1;
        base_ram_we_n <= 1;
        
        ext_ram_addr <= 20'b0;
        ext_ram_be_n <= 4'b0000;
        ext_ram_oe_n <= 1;
        ext_ram_we_n <= 1;

        base_data_z <= 1;
        ext_data_z <= 1;
        mem_stall <= 1;
        sram_data_reg <= 32'b0;

        ena <= 0;
        wea <= 0;
        addra <= 17'b0;
        dina <= 8'b0;
        
        mtime <= mtime + 64'b1;
        
        if(address[31:3] == 29'b0001_0000_0000_0000_0000_0000_0000_0 && mem_read_or_write == 1) begin
            state <= `STATE_READ_UART_1;
        end
        else if(address[31:3] == 29'b0001_0000_0000_0000_0000_0000_0000_0 && mem_read_or_write == 0) begin
            state <= `STATE_WRITE_UART_1;
        end
        else if(address[31:23] == 9'b1000_0000_0 && mem_read_or_write == 1) begin
            state <= `STATE_READ_SRAM_1;
        end
        else if(address[31:23] == 9'b1000_0000_0 && mem_read_or_write == 0) begin
            state <= `STATE_WRITE_SRAM_1;
        end
        else if(address[31:23] == 9'b0011_0000_0 && mem_read_or_write == 0) begin
            state <= `STATE_WRITE_BRAM;
        end
        else if (address[31:3] == 29'b0000_0010_0000_0000_1011_1111_1111_1) begin
            state <= `STATE_TIME;
        end
        else if (address[31:3] == 29'b0000_0010_0000_0000_0100_0000_0000_0) begin
            state <= `STATE_TIMECMP;
        end
        else begin
            state <= `STATE_RUN;
            mem_stall <= 0;
        end
    end
    else if(state == `STATE_WRITE_BRAM) begin
        ena <= 1;
        wea <= 1;
        addra <= address[16:0];
        dina <= mem_write_data[7:0];
        state <= `STATE_RUN;
        mem_stall <= 0;
    end
    else if(state == `STATE_READ_UART_1) begin
        if(address[2:0] != 3'b101) begin
            uart_rdn <= 0;
        end
        else begin
            uart_rdn <= 1;
        end
        mem_stall <= 1;
        state <= `STATE_READ_UART_2;
    end
    else if(state == `STATE_READ_UART_2) begin
        if(address[2:0] != 3'b101) begin
            mem_read_data <= {24'b0, base_ram_data_wire[7:0]};            
        end
        else begin
            mem_read_data <= {26'b0,uart_tbre&uart_tsre, 4'b0, uart_dataready};
        end
        state <= `STATE_RUN;
        mem_stall <= 0;
    end

    else if(state == `STATE_WRITE_UART_1) begin
        state <= `STATE_WRITE_UART_2;
        sram_data_reg <= mem_write_data;
        base_data_z <= 0;
        mem_stall <= 1;
    end
    else if(state == `STATE_WRITE_UART_2) begin
        uart_wrn <= 0; 
        state <= `STATE_WRITE_UART_3;
    end
    else if(state == `STATE_WRITE_UART_3) begin
        state <= `STATE_RUN;
        mem_stall <= 0;
    end
    else if(state == `STATE_READ_SRAM_1) begin
        if(cache[address[5:0]][58:32] == {address[31:6], 1'b1}) begin
            if(alu_op == `ALU_LW) begin
                mem_read_data <= cache[address[5:0]][31:0];
            end
            else if(alu_op == `ALU_LB) begin
                case(address[1:0])
                    2'b00: begin
                        mem_read_data <= {24'b0, cache[address[5:0]][7:0]};
                    end
                    2'b01: begin
                        mem_read_data <= {24'b0, cache[address[5:0]][15:8]};
                    end
                    2'b10: begin
                        mem_read_data <= {24'b0, cache[address[5:0]][23:16]};
                    end
                    2'b11: begin
                        mem_read_data <= {24'b0, cache[address[5:0]][31:24]};
                    end
                endcase
            end
            else begin
                mem_read_data <= cache[address[5:0]][31:0];
            end
            state <= `STATE_RUN;
            mem_stall <= 0;
        end
        else begin
            state <= `STATE_READ_SRAM_2;
            mem_stall <= 1;
            if(address[22] == 0) begin
                base_ram_oe_n <= 0;
                //base_ram_ce_n <= 0;
                base_ram_addr <= address[21:2];
                base_ram_be_n <= 0;
            end
            else begin
                ext_ram_oe_n <= 0;
                //ext_ram_ce_n <= 0;
                ext_ram_addr <= address[21:2];
                ext_ram_be_n <= 0;
            end
        end    
    end
    else if(state == `STATE_READ_SRAM_2) begin
        state <= `STATE_RUN;
        mem_stall <= 0;
        if(alu_op != `ALU_LB) begin
            if(address[22] == 0)
                cache[address[5:0]] <= {address[31:6], 1'b1, base_ram_data_wire};
            else
                cache[address[5:0]] <= {address[31:6], 1'b1, ext_ram_data_wire};
        end
        else;
        if(address[22] == 0) begin
            if(alu_op == `ALU_LW) begin
                mem_read_data <= base_ram_data_wire;
            end
            else if(alu_op == `ALU_LB) begin
                case(address[1:0])
                    2'b00: begin
                        mem_read_data <= {24'b0, base_ram_data_wire[7:0]};
                    end
                    2'b01: begin
                        mem_read_data <= {24'b0, base_ram_data_wire[15:8]};
                    end
                    2'b10: begin
                        mem_read_data <= {24'b0, base_ram_data_wire[23:16]};
                    end
                    2'b11: begin
                        mem_read_data <= {24'b0, base_ram_data_wire[31:24]};
                    end
                endcase
            end
            else begin
                mem_read_data <= base_ram_data_wire;
            end
        end
        else if(address[22] == 1) begin
            if(alu_op == `ALU_LW) begin
                mem_read_data <= ext_ram_data_wire;
            end
            else if(alu_op == `ALU_LB) begin
                case(address[1:0])
                    2'b00: begin
                        mem_read_data <= {24'b0, ext_ram_data_wire[7:0]};
                    end
                    2'b01: begin
                        mem_read_data <= {24'b0, ext_ram_data_wire[15:8]};
                    end
                    2'b10: begin
                        mem_read_data <= {24'b0, ext_ram_data_wire[23:16]};
                    end
                    2'b11: begin
                        mem_read_data <= {24'b0, ext_ram_data_wire[31:24]};
                    end
                endcase
            end
            else begin
                mem_read_data <= ext_ram_data_wire;
            end
        end
    end
    else if(state == `STATE_WRITE_SRAM_1) begin
        state <= `STATE_WRITE_SRAM_2;
        if(cache[address[5:0]][32] == 0 || cache[address[5:0]][58:33] != address[31:6]) begin
            if(alu_op != `ALU_SB) begin
                cache[address[5:0]] <= {address[31:6], 1'b1, mem_write_data};                
            end
            else ;
        end
        else if (cache[address[5:0]][58:32] == {address[31:6], 1'b1}) begin
            if(alu_op != `ALU_SB) begin
                cache[address[5:0]][31:0] <= mem_write_data[31:0];
            end
            else begin
                case(address[1:0])
                    2'b00: begin
                        cache[address[5:0]][7:0] <= mem_write_data[7:0];
                    end 
                    2'b01: begin
                        cache[address[5:0]][15:8] <= mem_write_data[15:8];
                    end
                    2'b10: begin
                        cache[address[5:0]][23:16] <= mem_write_data[23:16];
                    end
                    2'b11: begin
                        cache[address[5:0]][31:24] <= mem_write_data[31:24];
                    end
                endcase
            end
        end
        else;
        mem_stall <= 1;
        if(address[22] == 0) begin
            base_data_z <= 0;
            base_ram_addr <= address[21:2];
            if(alu_op == `ALU_SB) begin
                case(address[1:0])
                    2'b00: begin
                        sram_data_reg <= {24'b0, mem_write_data[7:0]};
                    end 
                    2'b01: begin
                        sram_data_reg <= {16'b0, mem_write_data[15:8], 8'b0};
                    end
                    2'b10: begin
                        sram_data_reg <= {8'b0, mem_write_data[23:16], 16'b0};
                    end
                    2'b11: begin
                        sram_data_reg <= {mem_write_data[31:24], 24'b0};
                    end
                endcase
            end
            else begin
                sram_data_reg <= mem_write_data;
            end
        end
        else begin
            ext_data_z <= 0;
            ext_ram_addr <= address[21:2];
            if(alu_op == `ALU_SB) begin
                case(address[1:0])
                    2'b00: begin
                        sram_data_reg <= {24'b0, mem_write_data[7:0]};
                    end 
                    2'b01: begin
                        sram_data_reg <= {16'b0, mem_write_data[15:8], 8'b0};
                    end
                    2'b10: begin
                        sram_data_reg <= {8'b0, mem_write_data[23:16], 16'b0};
                    end
                    2'b11: begin
                        sram_data_reg <= {mem_write_data[31:24], 24'b0};
                    end
                endcase
            end
            else begin
                sram_data_reg <= mem_write_data;
            end
        end
    end
    else if(state == `STATE_WRITE_SRAM_2) begin
        state <= `STATE_WRITE_SRAM_3;
        if(address[22] == 0) begin
            base_ram_we_n <= 0;
            base_ram_ce_n <= 0;
            if(alu_op == `ALU_SB) begin
                case(address[1:0])
                    2'b00: begin
                        base_ram_be_n <= 4'b1110;
                    end 
                    2'b01: begin
                        base_ram_be_n <= 4'b1101;
                    end
                    2'b10: begin
                        base_ram_be_n <= 4'b1011;
                    end
                    2'b11: begin
                        base_ram_be_n <= 4'b0111;
                    end
                endcase
            end
            else begin
                base_ram_be_n <= 4'b0000;
            end
        end
        else begin
            ext_ram_we_n <= 0;
            ext_ram_ce_n <= 0;
            if(alu_op == `ALU_SB) begin
                case(address[1:0])
                    2'b00: begin
                        ext_ram_be_n <= 4'b1110;
                    end 
                    2'b01: begin
                        ext_ram_be_n <= 4'b1101;
                    end
                    2'b10: begin
                        ext_ram_be_n <= 4'b1011;
                    end
                    2'b11: begin
                        ext_ram_be_n <= 4'b0111;
                    end
                endcase
            end
            else begin
                ext_ram_be_n <= 4'b0000;
            end
        end
    end
    else if(state == `STATE_WRITE_SRAM_3) begin
        state <= `STATE_RUN;
        base_ram_be_n <= 4'b0000;
        base_ram_oe_n <= 1;
        base_ram_we_n <= 1;
        ext_ram_be_n <= 4'b0000;
        ext_ram_oe_n <= 1;
        ext_ram_we_n <= 1;
        mem_stall <= 0;
    end
    else if(state == `STATE_RUN) begin
        mem_stall <= 1;
        state <= `STATE_IDLE;
    end
    
    // mtime
    else if (state == `STATE_TIME) begin
        if (mem_read_or_write == 1) begin  // read
            if (address[2] == 1'b0)  // lower 32 bits
                mem_read_data <= mtime[31:0];
            else
                mem_read_data <= mtime[63:32];
        end
        mem_stall <= 0;
        state <= `STATE_RUN;
    end
    else if (state == `STATE_TIMECMP) begin
        if (mem_read_or_write == 1) begin  // read
            if (address[2] == 1'b0)  // lower 32 bits
                mem_read_data <= mtimecmp[31:0];
            else
                mem_read_data <= mtimecmp[63:32];
        end
        else begin  // write
            if (address[2] == 1'b0)  // lower 32 bits
                mtimecmp[31:0] <= mem_write_data;
            else
                mtimecmp[63:32] <= mem_write_data;
        end
        mem_stall <= 0;
        state <= `STATE_RUN;
    end
end



endmodule
