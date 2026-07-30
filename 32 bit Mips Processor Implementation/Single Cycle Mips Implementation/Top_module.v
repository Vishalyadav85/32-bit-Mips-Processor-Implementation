`timescale 1ns / 1ps

module Top_module_single_cycle_mips_processor(
input clk,rst
);

wire [31:0]pc_out;
wire [31:0]instruction;
wire [31:0]mux3_out;
wire [31:0]pc_next;
wire [31:0] mux5_out;

// Program counter
program_counter d0 (.clk(clk),.rst(rst),.pc_in(mux5_out),.pc_out(pc_out));

// PC Adder
adder_pc_plus_four d1(.pc_in_four(pc_out),.pc_out_four(pc_next));

// instruction memory
instruction_memory d2(.read_address(pc_out),.instruction_out(instruction));

// Main Controller module
wire RegDst,jump,branch,Memread,MemtoReg,Memwrite,Regwrite,Alusrc;
wire [1:0]Aluop;

control_unit d4(.opcode(instruction[31:26]), .RegDst(RegDst),.jump(jump), .branch(branch),
.Memread(Memread), .MemtoReg(MemtoReg),.Aluop(Aluop),.Memwrite(Memwrite),
.Alusrc(Alusrc),.Regwrite(Regwrite));

// Mux1 Logic to provide the destination register
wire [4:0] rd;
Mux_logic1 d5(.in1(instruction[20:16]),.in2(instruction[15:11]),.RegDst(RegDst),.out(rd));

// Register File
wire [31:0]read_out1, read_out2;
register_file d6(.clk(clk),.rst(rst),.regwrite(Regwrite),
.rs(instruction[25:21]),.rt(instruction[20:16]),
.rd(rd),.read_out1(read_out1),.read_out2(read_out2),.write_in(mux3_out));

// MUX Logic 2 for ALU
wire [31:0] immediate_instruction;
wire [31:0] mux2_out;
assign immediate_instruction = {{16{instruction[15]}}, instruction[15:0]};
Mux_logic2 d7(.in1(read_out2),.in2(immediate_instruction),.Alusrc(Alusrc),.out(mux2_out));

// ALU control Logic
wire [2:0]control_out;
Alu_control d8(.funct(instruction[5:0]),.Aluop(Aluop),.control_out(control_out));

// ALU Logic
wire zero;
wire [31:0]Alu_out;
Alu d9(.a(read_out1),.b(mux2_out),.control_out(control_out),.zero(zero),.result(Alu_out));

// Data Memory
wire [31:0]data_out;
Data_memory d10(.rst(rst),.clk(clk),.read_address(Alu_out),
.write_data(read_out2),.read_out(data_out),
.Memread(Memread),.Memwrite(Memwrite));

// Mux Logic 3
Mux_logic3 d11(.in1(data_out),.in2(Alu_out),.MemtoReg(MemtoReg),.out(mux3_out));

// Branch logic
wire [31:0]shift1_out;
wire [31:0] adder_out;
assign shift1_out = immediate_instruction << 2;
Adder d12(.in1(pc_next),.in2(shift1_out),.out(adder_out));

wire and_out;
And_logic d13(.zero(zero),.branch(branch),.and_out(and_out));

wire [31:0]mux4_out;
Mux_logic4 d14(.in1(pc_next),.in2(adder_out),.sel(and_out),.out(mux4_out));

// Jump logic
wire [31:0]jump_instruction;
assign jump_instruction = {pc_next[31:28], instruction[25:0], 2'b00};

Mux_logic5 d15(.in1(mux4_out),.in2(jump_instruction),.jump(jump),.out(mux5_out));

endmodule


// Program Counter
module program_counter(input clk,input rst,input [31:0] pc_in,output reg [31:0] pc_out);
always@(posedge clk or posedge rst)
if(rst) pc_out<=0;
else pc_out<=pc_in;
endmodule


// PC + 4
module adder_pc_plus_four(input [31:0] pc_in_four,output [31:0] pc_out_four);
assign pc_out_four = pc_in_four + 4;
endmodule


// Instruction Memory
module instruction_memory(input [31:0] read_address,output [31:0] instruction_out);

reg [31:0] instruction_memory [0:63];

initial begin
instruction_memory[0] = 32'b000000_00001_00010_00011_00000_100000;
instruction_memory[1] = 32'b000000_00011_00001_00100_00000_100010;
instruction_memory[2] = 32'b000000_00001_00010_00101_00000_100100;
instruction_memory[3] = 32'b000000_00001_00010_00110_00000_100101;
instruction_memory[4] = 32'b000000_00001_00010_00111_00000_101010;
instruction_memory[5] = 32'b101011_00001_00011_0000000000000000;
instruction_memory[6] = 32'b100011_00001_01000_0000000000000000;
instruction_memory[7] = 32'b000000_01000_00001_01001_00000_100000;
instruction_memory[8] = 32'b000100_00001_00001_0000000000000010;
instruction_memory[9] = 32'b000000_00001_00001_01010_00000_100000;
instruction_memory[10] = 32'b000000_00001_00001_01011_00000_100000;
instruction_memory[11] = 32'b000010_00000000000000000000001110;
instruction_memory[12] = 32'b000000_00001_00001_01100_00000_100000;
instruction_memory[13] = 32'b000000_00001_00001_01101_00000_100000;
instruction_memory[14] = 32'b000000_00001_00001_01110_00000_100000;
end

assign instruction_out = instruction_memory[read_address[7:2]];

endmodule


// Register File
module register_file(input clk,input rst,input regwrite,input [4:0]rs,input [4:0] rt,
input [4:0]rd,output [31:0] read_out1,output [31:0]read_out2,input [31:0]write_in);

reg [31:0]registers[0:31];
integer i;

always@(posedge clk or posedge rst)
begin
if(rst) begin
for(i=0;i<32;i=i+1) registers[i]<=0;
registers[1]<=10;
registers[2]<=5;
end
else if(regwrite)
registers[rd]<=write_in;
end

assign read_out1 = registers[rs];
assign read_out2 = registers[rt];

endmodule


// ALU
module Alu(input [31:0] a,b,input [2:0]control_out,output reg zero,output reg [31:0]result);
always@(*) begin
case(control_out)
3'b000: result=a&b;
3'b001: result=a|b;
3'b010: result=a+b;
3'b110: result=a-b;
3'b111: result=(a<b);
endcase
zero = (result==0);
end
endmodule


// ALU Control
module Alu_control(input [5:0]funct,input [1:0] Aluop,output reg [2:0]control_out);
always@(*) begin
case(Aluop)
2'b00: control_out=3'b010;
2'b01: control_out=3'b110;
2'b10: case(funct)
6'b100000: control_out=3'b010;
6'b100010: control_out=3'b110;
6'b100100: control_out=3'b000;
6'b100101: control_out=3'b001;
6'b101010: control_out=3'b111;
endcase
endcase
end
endmodule


// Data Memory
module Data_memory(input rst,input clk,input [31:0]read_address,input [31:0]write_data,
output [31:0] read_out,input Memread,input Memwrite);

reg [31:0] Data_memory[0:63];
integer i;

always@(posedge clk or posedge rst)
begin
if(rst)
for(i=0;i<64;i=i+1) Data_memory[i]<=0;
else if(Memwrite)
Data_memory[read_address[7:2]]<=write_data;
end

assign read_out = Memread ? Data_memory[read_address[7:2]] : 0;

endmodule


// Control Unit
module control_unit(input [5:0]opcode,
output reg RegDst,reg jump,reg branch,reg Memread,reg MemtoReg,
reg [1:0]Aluop,reg Memwrite,reg Alusrc,reg Regwrite);

always@(*) begin
case(opcode)
6'b000000: {RegDst,jump,Alusrc,MemtoReg,Regwrite,Memread,Memwrite,branch,Aluop}=10'b1000100010;
6'b100011: {RegDst,jump,Alusrc,MemtoReg,Regwrite,Memread,Memwrite,branch,Aluop}=10'b0011110000;
6'b101011: {RegDst,jump,Alusrc,MemtoReg,Regwrite,Memread,Memwrite,branch,Aluop}=10'b0010001000;
6'b000100: {RegDst,jump,Alusrc,MemtoReg,Regwrite,Memread,Memwrite,branch,Aluop}=10'b0000000101;
6'b000010: {RegDst,jump,Alusrc,MemtoReg,Regwrite,Memread,Memwrite,branch,Aluop}=10'b0100000000;
endcase
end
endmodule


// AND
module And_logic(input zero,branch,output and_out);
assign and_out = zero & branch;
endmodule


// MUX modules
module Mux_logic1(input [4:0]in1,in2,input RegDst,output[4:0]out);
assign out = RegDst ? in2 : in1;
endmodule

module Mux_logic2(input [31:0]in1,in2,input Alusrc,output [31:0]out);
assign out = Alusrc ? in2 : in1;
endmodule

module Mux_logic3(input [31:0]in1,in2,input MemtoReg,output [31:0]out);
assign out = MemtoReg ? in1 : in2;
endmodule

module Mux_logic4(input [31:0] in1,in2,input sel,output [31:0]out);
assign out = sel ? in2 : in1;
endmodule

module Mux_logic5(input [31:0] in1,in2,input jump,output [31:0] out);
assign out = jump ? in2 : in1;
endmodule


// Adder
module Adder(input [31:0]in1,in2,output [31:0] out);
assign out = in1 + in2;
endmodule