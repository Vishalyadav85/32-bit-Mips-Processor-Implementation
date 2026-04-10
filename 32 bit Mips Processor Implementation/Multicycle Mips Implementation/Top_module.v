`timescale 1ns / 1ps

module Top_module( input clk, input rst); 
wire [31:0]instruction_address_in; wire PCWrite; 
wire PCWriteCond; 
wire zero; 
wire [31:0]instruction_address_out; 

//Instantiation of the Program counter Module 

program_counter d0(.clk(clk),.rst(rst),.PCWrite(PCWrite),.PCWriteCond(PCWriteCond),.Zero(zero),.pc_in(instruction_address_in),.pc_out(instruction_address_out));

wire [31:0]ALUout_result; 
wire IorD; 
wire [31:0]address; // will contain the address of the instruction

//Instantiation of the Mux Logic 1
 
mux_logic1 d1(.in1(instruction_address_out),.in2(ALUout_result),.IorD(IorD),.out(address)); 

wire [31:0] B_reg_data; //Data coming out of the register B to be written inside B 
wire MemRead; 
wire MemWrite; 
wire [31:0]memory_out; //memory out when the instruction address read by the memory

//Instantiation of the Memory Module 

Memory d2(.clk(clk),.in_address(address),.data(B_reg_data),.MemRead(MemRead),
.MemWrite(MemWrite),.out(memory_out));
 
wire IRWrite; 
wire [5:0] opcode;
wire [25:0] jump_data;
wire [4:0] rs,rt,rd;
wire [15:0] imme_data;
wire [5:0]funct;
//Instantiation of the Instruction Register 
instruction_register d3(.clk(clk),.rst(rst),.IRwrite(IRWrite),
 .instruction_in(memory_out),.opcode(opcode),.jump_data(jump_data),.rs(rs), .rt(rt), 
 .imme_data(imme_data),.rd(rd),.funct(funct)); 

wire [31:0]MDR_out; // 32 bit Memory Data Register result 

//Instantion of the Memory data Register 

memory_register d4(.clk(clk),.rst(rst),.data_in(memory_out),.mem_out(MDR_out)); 
wire RegDst; 
wire [4:0]destination_address;
//instantiation of the MUX Logic 2 

mux_logic2 d5(.in1(rt),.in2(rd),.RegDst(RegDst),.out(destination_address) ); 

wire RegWrite; 
wire [31:0]read1_data; 
wire [31:0]read2_data; 
wire [31:0] write_data; // data to be written back at the register file
 
//instantiation of the Register File 
register_file d6(.clk(clk), .rst(rst),.rs(rs), .rt(rt),
  .rd(destination_address),  .write_data(write_data),.regwrite(RegWrite),
  .read_out1(read1_data),.read_out2(read2_data)
); 

wire [31:0] A_out; // data out of the Register A 
wire [31:0] B_out; // data out of the Register B 

//instantiation of the A register 

A_register d7(.clk(clk),.rst(rst),.instruction(read1_data),.A_out(A_out)); 

//instantiation of the B register 

B_register d8(.instruction(read2_data),.rst(rst),.clk(clk),.B_out(B_out)); 

wire ALUSrcA; 
wire [31:0] Alu_in1; // ALU input 1 

//instantiation of the Mux Logic 3 

mux_logic3 d9(.in1(instruction_address_out),.in2(A_out),.ALUSrcA(ALUSrcA),.out(Alu_in1)); 

wire [31:0] Alu_in2; 
wire [1:0]ALUSrcB; 
wire [31:0]immediate_signextend; // 32 bit sign extended value 
assign immediate_signextend = {{16{imme_data[15]}}, imme_data}; // 32 bit sign extended value 
wire [31:0] immediate_shift_out; 
assign immediate_shift_out=immediate_signextend<<2;
 
//instantiation of the Mux Logic 4 

mux_logic4 d10(.in1(B_out),.in2(immediate_signextend),.in3(immediate_shift_out),
.ALUSrcB(ALUSrcB),.out(Alu_in2));
 
wire[31:0]Alu_result; 
wire [2:0]control_out; // output of the ALU control module

//instantiation of the ALU 

Alu d11(.a(Alu_in1), .b(Alu_in2),.control_out(control_out), .zero(zero),.result(Alu_result)); 

wire [1:0]ALUop; 

//instantiation of the ALU Control 

ALU_control d12(.funct(funct),.Aluop(ALUop),.control_out(control_out)); 

//instantiation of the ALUout register 

ALUout_register d13(.clk(clk),.rst(rst),.data_in(Alu_result),.data_out(ALUout_result)); 

wire [1:0]PCSource; 
wire [31:0] jump_shift_result; 
assign jump_shift_result = {instruction_address_out[31:28], jump_data, 2'b00};

//instantiation of MUX Logic 5 

mux_logic5 d14(.in1(Alu_result),.in2(jump_shift_result),.in3(ALUout_result),.PCSource(PCSource),.out(instruction_address_in)); 

//instantiation of the FSM Control 
wire MemtoReg; 

fsm_control d15(.clk(clk),.rst(rst),.opcode(opcode),.RegDst(RegDst), .RegWrite(RegWrite), 
.ALUSrcA(ALUSrcA), .MemRead(MemRead),.MemWrite(MemWrite), .MemtoReg(MemtoReg), .IorD(IorD), 
.IRWrite(IRWrite),.PCWrite(PCWrite), .PCWriteCond(PCWriteCond),.ALUop(ALUop), 
.ALUSrcB(ALUSrcB), .PCSource(PCSource)); 

//instantiation of MUX Logic 6 

mux_logic6 d16(.in1(ALUout_result),.in2(MDR_out),.MemtoReg(MemtoReg),.out(write_data)); endmodule


// Program counter module
module program_counter(
    input clk,
    input rst,
    input PCWrite,
    input PCWriteCond,
    input Zero,
    input [31:0] pc_in,
    output reg [31:0] pc_out
);

// PC update logic
wire pc_enable;
assign pc_enable = PCWrite | (PCWriteCond & Zero);

always @(posedge clk or posedge rst) begin
if (rst)
pc_out <= 32'b0;
else if (pc_enable)
pc_out <= pc_in;
else
pc_out <= pc_out; // hold value
end

endmodule


// Memory Module

module Memory(
    input clk,
    input [31:0] in_address,
    input [31:0] data,
    input MemRead,
    input MemWrite,
    output reg [31:0] out
);

reg [31:0] memory [0:63];

// READ 
always @(*) begin
    if (MemRead)
    out = memory[in_address[7:2]];
    else
    out = 32'b0;  // HOLD previous value (IMPORTANT FIX)
end

// WRITE 
always @(posedge clk) begin
    if (MemWrite)
        memory[in_address[7:2]] <= data;
end
endmodule

//Instruction Register Module
module instruction_register(
    input clk,
    input rst,
    input IRwrite,
    input [31:0] instruction_in,

    output reg [5:0] opcode,
    output reg [25:0] jump_data,
    output reg [4:0] rs,
    output reg [4:0] rt,
    output reg [15:0] imme_data,
    output reg [4:0] rd,
    output reg [5:0] funct
);

reg [31:0] instruction;

//Instruction Register 
always @(posedge clk or posedge rst) begin
if (rst)
instruction <= 32'b0;
else if (IRwrite)
instruction <= instruction_in;
end

//Decode Logic
always @(*) begin
    opcode     = instruction[31:26];
    jump_data  = instruction[25:0];
    rs         = instruction[25:21];
    rt         = instruction[20:16];
    rd         = instruction[15:11];
    funct      = instruction[5:0];
    imme_data  = instruction[15:0];
end
endmodule


//Memory Data Register
module memory_register(
    input clk,
    input rst,
    input [31:0] data_in,
    output reg [31:0] mem_out
);

always @(posedge clk or posedge rst) begin
if (rst)
mem_out <= 32'b0;
else
mem_out <= data_in;
end
endmodule


// Register File Module
module register_file(
    input clk,
    input rst,
    input [4:0] rs,
    input [4:0] rt,
    input [4:0] rd,
    input [31:0] write_data,
    input regwrite,

    output [31:0] read_out1,
    output [31:0] read_out2
);

reg [31:0] register_memory [31:0];  // 32 registers
integer i;
// Reset 
always @(posedge clk or posedge rst) begin
if (rst) begin
for (i = 0; i < 32; i = i + 1)
register_memory[i] <= 32'b0;
end
else if (regwrite && rd != 5'b00000) begin
register_memory[rd] <= write_data;
end
end

//Read 
assign read_out1 = register_memory[rs];
assign read_out2 = register_memory[rt];
endmodule

// A Register Module
module A_register(
input clk,
input rst,
input [31:0]instruction,
output reg [31:0]A_out
    );
always@(posedge clk or posedge rst)begin
if(rst)
A_out<=32'b0;
else
A_out<=instruction;
end
endmodule

// B Register Module
module B_register(
input [31:0]instruction,
input rst,
input clk,
output reg [31:0] B_out
);
always@(posedge clk or posedge rst)begin
if(rst)
    B_out <= 32'b0;
else
    B_out <= instruction;
end
endmodule

//ALU Module
module Alu(
    input [31:0] a, b,
    input [2:0] control_out,
    output reg zero,
    output reg [31:0] result
);

always @(*) begin

// Default assignment (prevents latches)
result = 32'b0;

case (control_out)
3'b000: result = a & b; // AND
3'b001: result = a | b; // OR
3'b010: result = a + b; // ADD
3'b110: result = a - b; // SUB
3'b111: result = (a < b) ? 32'd1 : 32'd0; // SLT

default: result = 32'b0;

endcase

//Zero flag
zero = (result == 32'b0);
end
endmodule

//ALU Control Module
module ALU_control(
input [5:0] funct,
input [1:0] Aluop,
output reg [2:0] control_out
);

always@(*) begin
case(Aluop)
2'b00: control_out = 3'b010; // ADD
2'b01: control_out = 3'b110; // SUB
2'b10: begin
case(funct)
6'b100000: control_out = 3'b010;
6'b100010: control_out = 3'b110;
6'b100100: control_out = 3'b000;
6'b100101: control_out = 3'b001;
6'b101010: control_out = 3'b111;
default:   control_out = 3'b010;
endcase
end
default: control_out = 3'b010; // SAFE DEFAULT
endcase
end
endmodule
// ALUout Register Module
module ALUout_register(
    input clk,
    input rst,
    input [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge rst) begin
if (rst)
data_out <= 32'b0;
else
data_out <= data_in;
end
endmodule

//FSM Control Module
module fsm_control(
input clk,
input rst,
input [5:0] opcode,
output reg RegDst, RegWrite, ALUSrcA, MemRead,
output reg MemWrite, MemtoReg, IorD, IRWrite,
output reg PCWrite, PCWriteCond,
output reg [1:0] ALUop, ALUSrcB, PCSource
);

// State Encoding
parameter s0 = 4'd0,  // IF
          s1 = 4'd1,  // ID
          s2 = 4'd2,  // EX
          s3 = 4'd3,  // MEM / WB
          s4 = 4'd4;  // WB for lw

reg [3:0] ps, ns;

// Opcodes
parameter LW    = 6'b100011;
parameter SW    = 6'b101011;
parameter RTYPE = 6'b000000;
parameter BEQ   = 6'b000100;
parameter JUMP  = 6'b000010;

// State Register
always @(posedge clk or posedge rst) begin
if (rst)
ps <= s0;
else
ps <= ns;
end

//Next State + Output Logic
always @(*) begin

//Default values
RegDst = 0; RegWrite = 0; ALUSrcA = 0; MemRead = 0;
MemWrite = 0; MemtoReg = 0; IorD = 0; IRWrite = 0;
PCWrite = 0; PCWriteCond = 0;
ALUop = 2'b00; ALUSrcB = 2'b00; PCSource = 2'b00;
ns = s0;

case (ps)
// STATE s0: Instruction Fetch
s0: begin
MemRead   = 1;
IRWrite   = 1;
ALUSrcA   = 0;
ALUSrcB   = 2'b01;   // +4
ALUop     = 2'b00;
PCWrite   = 1;
PCSource  = 2'b00;

ns = s1;
end

//STATE s1: Instruction Decode
s1: begin
ALUSrcA = 0;
ALUSrcB = 2'b11;   // branch address calc
ALUop   = 2'b00;

case (opcode)
LW, SW:   ns = s2;
RTYPE:    ns = s2;
BEQ:      ns = s2;
JUMP:     ns = s2;
default:  ns = s0;
endcase
end

//STATE s2: Execute
s2: begin
case (opcode)

// R-type
RTYPE: begin
ALUSrcA = 1;
ALUSrcB = 2'b00;
ALUop   = 2'b10;
ns = s3;
end

// lw / sw
LW, SW: begin
ALUSrcA = 1;
ALUSrcB = 2'b10;
ALUop   = 2'b00;
ns = s3;
end

// beq
BEQ: begin
ALUSrcA = 1;
ALUSrcB = 2'b00;
ALUop   = 2'b01;
PCWriteCond = 1;
PCSource = 2'b01;
ns = s0;
end

// jump
JUMP: begin
PCWrite  = 1;
PCSource = 2'b10;
ns = s0;
 end

default: ns = s0;

endcase
end

//STATE s3: Memory / Write-back
s3: begin
case (opcode)

// R-type write back
RTYPE: begin
RegDst   = 1;
RegWrite = 1;
MemtoReg = 0;
ns = s0;
end

// lw memory read
LW: begin
MemRead = 1;
IorD    = 1;
ns = s4;
end

// sw memory write
SW: begin
MemWrite = 1;
IorD     = 1;
ns = s0;
end
default: ns = s0;
endcase
end
    
//STATE s4: Load Write Back
s4: begin
RegDst   = 0;
RegWrite = 1;
MemtoReg = 1;
ns = s0;
end

default: ns = s0;
endcase
end
endmodule


//MUX Logics
module mux_logic1(
input [31:0]in1,in2,
input IorD,
output [31:0]out
    );
assign out=IorD?in2:in1;
endmodule

// Mux Logic between the instruction register and the register file
module mux_logic2(
input [4:0]in1,in2,
input RegDst,
output [4:0]out );
assign out=RegDst?in2:in1;
endmodule

//Mux logic between the A register and the ALU
module mux_logic3(
input [31:0] in1, in2,
input ALUSrcA,
output [31:0] out
);
assign out = ALUSrcA ? in2 : in1;
endmodule

//Mux logic between the Memory data register and the register file
module mux_logic6(
input [31:0]in1,in2,
input MemtoReg,
output [31:0]out);
assign out=MemtoReg?in2:in1;
endmodule

// Mux logic between the ALUout register and the program counter
module mux_logic5(
input [31:0]in1,in2,in3,
input [1:0]PCSource,
output reg [31:0]out
    );
always@(*)begin
case(PCSource)
2'b00: out = in1; // PC+4
2'b01: out = in3; // branch (ALUout)
2'b10: out = in2; // jump
default: out = 32'b0;
endcase
end
endmodule

//Mux Logic between the B register and the ALU

module mux_logic4(
input [31:0]in1,in2,in3,
input [1:0]ALUSrcB,
output reg [31:0]out);
always@(*)begin
case(ALUSrcB)
2'b00:out=in1;
2'b01:out=32'b0000_0000_0000_0000_0000_0000_0000_0100;
2'b10:out=in2;
2'b11:out=in3;
endcase
end
endmodule
