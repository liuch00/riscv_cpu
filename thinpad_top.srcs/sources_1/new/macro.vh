`define OPCODE_R       7'b0110011
`define OPCODE_IMM     7'b0010011
`define OPCODE_BRANCH  7'b1100011
`define OPCODE_JAL     7'b1101111
`define OPCODE_JALR    7'b1100111
`define OPCODE_LOAD    7'b0000011
`define OPCODE_STORE   7'b0100011
`define OPCODE_AUIPC   7'b0010111
`define OPCODE_LUI     7'b0110111
`define OPCODE_SYSTEM  7'b1110011

`define FUNC_ADD  3'b000
`define FUNC_AND  3'b111
`define FUNC_XOR  3'b100
`define FUNC_SLTU 3'b011

`define FUNC_PRIV 3'b000
`define FUNC_CSRRW 3'b001
`define FUNC_CSRRS 3'b010
`define FUNC_CSRRC 3'b011

`define FUNC7_AND 7'b0000000
`define FUNC7_XOR  7'b0000000
`define FUNC7_PCNT 7'b0110000
`define FUNC7_SBSET 7'b0010100
`define FUNC7_ANDN 7'b0100000
`define FUNC7_SLTU 7'b0000000

`define FUNC_OR   3'b110
`define FUNC_SLL  3'b001
`define FUNC_SRL  3'b101
`define FUNC_PCNT 3'b001
`define FUNC_SBSET 3'b001

`define FUNC_BEQ  3'b000
`define FUNC_BNE  3'b001

`define FUNC_LB  3'b000
`define FUNC_LW  3'b010

`define FUNC_SB  3'b000
`define FUNC_SW  3'b010

`define FUNC12_ECALL    12'b000000000000
`define FUNC12_EBREAK   12'b000000000001
`define FUNC12_MRET     12'b001100000010

//exe defines by law
`define ALU_NOP   5'b00000

`define ALU_ADD   5'b00001
`define ALU_AND   5'b00010
`define ALU_OR    5'b00011
`define ALU_XOR   5'b00100
`define ALU_NOT   5'b00101
`define ALU_SLL   5'b00110
`define ALU_SRL   5'b00111

`define ALU_LW    5'b01011
`define ALU_LB    5'b01100
`define ALU_SW    5'b01101
`define ALU_SB    5'b01110
`define ALU_PCNT  5'b01111
`define ALU_SBSET 5'b10000
`define ALU_ANDN  5'b10001
`define ALU_SLTU  5'b10010

// PC defines
`define PC_DEFAULT      1'b0
`define PC_IMMIDIATE    1'b1

// RAM defines, used in pipeline
`define RAM_EN      1'b1
`define RAM_DIS     1'b0

`define RAM_READ    1'b1
`define RAM_WRITE   1'b0

`define IS_BYTE_EN  1'b1
`define IS_BYTE_DIS 1'b0

// exception related
`define MODE_U 2'b00
`define MODE_S 2'b01
`define MODE_H 2'b10
`define MODE_M 2'b11  // when using machine mode, use this, not H

`define EXP_EXP_NONE     2'b00
`define EXP_EXP_ECALL    2'b01
`define EXP_EXP_EBREAK   2'b10
`define EXP_EXP_MRET     2'b11

//-------------------------------------------------------------
// Branch prediction settings
//-------------------------------------------------------------
`define NUM_BTB_ENTRIES 	16'h8	//Number of branch target buffer entries.
`define NUM_BTB_ENTRIES_W	4'h3	//Set to log2(NUM_BTB_ENTRIES).
`define NUM_BHT_ENTRIES		16'h8	//Number of branch history table entries.
`define NUM_BHT_ENTRIES_W	4'h3	//Set to log2(NUM_BHT_ENTRIES_W).
`define BHT_ENABLE			1'b1	//Enable branch history table based prediction.
`define GSHARE_ENABLE		1'b1	//Enable GSHARE branch prediction algorithm.
`define RAS_ENABLE			1'b1	//Enable return address stack prediction.
`define NUM_RAS_ENTRIES		4'h8	//Number of return stack addresses supported.
`define NUM_RAS_ENTRIES_W	4'h3	//Set to log2(NUM_RAS_ENTRIES_W).



//-------------------------------------------------------------
//pc and jump instruction
//-------------------------------------------------------------
// jal
`define INST_JAL 32'h6f
`define INST_JAL_MASK 32'h7f
// jalr
`define INST_JALR 32'h67
`define INST_JALR_MASK 32'h707f

// beq
`define INST_BEQ 32'h63
`define INST_BEQ_MASK 32'h707f

// bne
`define INST_BNE 32'h1063
`define INST_BNE_MASK 32'h707f

// blt
`define INST_BLT 32'h4063
`define INST_BLT_MASK 32'h707f

// bge
`define INST_BGE 32'h5063
`define INST_BGE_MASK 32'h707f

// bltu
`define INST_BLTU 32'h6063
`define INST_BLTU_MASK 32'h707f

// bgeu
`define INST_BGEU 32'h7063
`define INST_BGEU_MASK 32'h707f
//-------------------------------------------------------------
//
//-------------------------------------------------------------
