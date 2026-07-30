`timescale 1ns/1ps

// ================= TOP MODULE =================
module Top_module(clk, reset);
input clk, reset;

reg [31:0] curr_pc;

// Memories
reg [31:0] inst_mem[0:255];
reg [31:0] data_mem[0:255];

// ================= PIPELINE REGISTERS =================

// IF/ID
reg [31:0] if_id_inst, if_id_pc_plus4;

// ID/EX
reg [31:0] id_ex_pc4, id_ex_data1, id_ex_data2, id_ex_sign_ext;
reg [4:0]  id_ex_rs_addr, id_ex_rt_addr, id_ex_rd_addr;
reg [5:0]  id_ex_fcode;
reg        id_ex_dst_sel, id_ex_src_sel, id_ex_m2r, id_ex_rf_en;
reg        id_ex_dread, id_ex_dwrite, id_ex_br_en;
reg [1:0]  id_ex_alu_ctrl_op;

// EX/MEM
reg [31:0] ex_mem_res, ex_mem_wdata, ex_mem_br_target;
reg        ex_mem_is_zero;
reg [4:0]  ex_mem_wreg_addr;
reg        ex_mem_m2r, ex_mem_rf_en;
reg        ex_mem_dread, ex_mem_dwrite, ex_mem_br_en;

// MEM/WB
reg [31:0] mem_wb_rdata, mem_wb_res;
reg [4:0]  mem_wb_wreg_addr;
reg        mem_wb_m2r, mem_wb_rf_en;

// ================= WIRES =================
wire [31:0] fetched_inst = inst_mem[curr_pc[9:2]];
wire pipe_stall;

// ================= PC UPDATE =================
always @(posedge clk or posedge reset) begin
    if (reset)
        curr_pc <= 0;
    else if (!pipe_stall)
        curr_pc <= curr_pc + 4;
end

// ================= IF/ID =================
always @(posedge clk) begin
    if (pipe_stall)
        if_id_inst <= if_id_inst; // hold
    else
        if_id_inst <= fetched_inst;

    if_id_pc_plus4 <= curr_pc;
end

// ================= ID STAGE =================
wire [5:0] op_field = if_id_inst[31:26];
wire [4:0] rs_field = if_id_inst[25:21];
wire [4:0] rt_field = if_id_inst[20:16];
wire [4:0] rd_field = if_id_inst[15:11];
wire [5:0] func_field = if_id_inst[5:0];

wire [31:0] extended_imm = {{16{if_id_inst[15]}}, if_id_inst[15:0]};

// Control Wires
wire ctrl_dst, ctrl_src, ctrl_m2r, ctrl_rf_en;
wire ctrl_dread, ctrl_dwrite, ctrl_branch;
wire [1:0] ctrl_alu_op;

Control CU(op_field, ctrl_dst, ctrl_src, ctrl_m2r, ctrl_rf_en,
           ctrl_dread, ctrl_dwrite, ctrl_branch, ctrl_alu_op);

// Register File Wires
wire [31:0] rf_out1, rf_out2, wb_final_data;

RegFile RF(clk, mem_wb_rf_en, rs_field, rt_field,
           mem_wb_wreg_addr, wb_final_data,
           rf_out1, rf_out2);

// ================= HAZARD DETECTION =================
HazardUnit HU(id_ex_dread, id_ex_rt_addr, rs_field, rt_field, pipe_stall);

// ================= ID/EX =================
always @(posedge clk) begin
    if (pipe_stall) begin
        id_ex_rf_en  <= 0; // insert NOP
        id_ex_dread  <= 0;
        id_ex_dwrite <= 0;
    end else begin
        id_ex_pc4        <= if_id_pc_plus4;
        id_ex_data1      <= rf_out1;
        id_ex_data2      <= rf_out2;
        id_ex_sign_ext   <= extended_imm;
        id_ex_rs_addr    <= rs_field;
        id_ex_rt_addr    <= rt_field;
        id_ex_rd_addr    <= rd_field;
        id_ex_fcode      <= func_field;

        id_ex_dst_sel    <= ctrl_dst;
        id_ex_src_sel    <= ctrl_src;
        id_ex_m2r        <= ctrl_m2r;
        id_ex_rf_en      <= ctrl_rf_en;
        id_ex_dread      <= ctrl_dread;
        id_ex_dwrite     <= ctrl_dwrite;
        id_ex_br_en      <= ctrl_branch;
        id_ex_alu_ctrl_op <= ctrl_alu_op;
    end
end

// ================= FORWARDING =================
wire [1:0] fwd_sel_a, fwd_sel_b;

ForwardingUnit FU(ex_mem_rf_en, ex_mem_wreg_addr,
                  mem_wb_rf_en, mem_wb_wreg_addr,
                  id_ex_rs_addr, id_ex_rt_addr,
                  fwd_sel_a, fwd_sel_b);

// ALU input selection
reg [31:0] op_a_mux, op_b_mux;

always @(*) begin
    case(fwd_sel_a)
        2'b00: op_a_mux = id_ex_data1;
        2'b10: op_a_mux = ex_mem_res;
        2'b01: op_a_mux = wb_final_data;
        default: op_a_mux = id_ex_data1;
    endcase

    case(fwd_sel_b)
        2'b00: op_b_mux = id_ex_data2;
        2'b10: op_b_mux = ex_mem_res;
        2'b01: op_b_mux = wb_final_data;
        default: op_b_mux = id_ex_data2;
    endcase
end

wire [31:0] alu_rhs = (id_ex_src_sel) ? id_ex_sign_ext : op_b_mux;

// ================= ALU =================
wire [3:0] alu_mode;
ALUControl ALUCTRL(id_ex_alu_ctrl_op, id_ex_fcode, alu_mode);

wire [31:0] raw_alu_out;
wire zero_flag;

ALU alu(op_a_mux, alu_rhs, alu_mode, raw_alu_out, zero_flag);

// ================= EX/MEM =================
always @(posedge clk) begin
    ex_mem_res       <= raw_alu_out;
    ex_mem_wdata     <= op_b_mux;
    ex_mem_wreg_addr <= (id_ex_dst_sel) ? id_ex_rd_addr : id_ex_rt_addr;

    ex_mem_m2r       <= id_ex_m2r;
    ex_mem_rf_en     <= id_ex_rf_en;
    ex_mem_dread     <= id_ex_dread;
    ex_mem_dwrite    <= id_ex_dwrite;
end

// ================= MEM =================
always @(posedge clk) begin
    if (ex_mem_dwrite)
        data_mem[ex_mem_res[9:2]] <= ex_mem_wdata;
end

always @(posedge clk) begin
    mem_wb_rdata     <= data_mem[ex_mem_res[9:2]];
    mem_wb_res       <= ex_mem_res;
    mem_wb_wreg_addr <= ex_mem_wreg_addr;

    mem_wb_m2r       <= ex_mem_m2r;
    mem_wb_rf_en     <= ex_mem_rf_en;
end

// ================= WB =================
assign wb_final_data = (mem_wb_m2r) ? mem_wb_rdata : mem_wb_res;

endmodule


// ================= FORWARDING UNIT =================
module ForwardingUnit(
    input ex_mem_rf_we,
    input [4:0] ex_mem_rd,
    input mem_wb_rf_we,
    input [4:0] mem_wb_rd,
    input [4:0] id_ex_rs, id_ex_rt,
    output reg [1:0] fwd_a, fwd_b
);

always @(*) begin
    fwd_a = 2'b00;
    fwd_b = 2'b00;

    if (ex_mem_rf_we && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs))
        fwd_a = 2'b10;
    else if (mem_wb_rf_we && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs))
        fwd_a = 2'b01;

    if (ex_mem_rf_we && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rt))
        fwd_b = 2'b10;
    else if (mem_wb_rf_we && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rt))
        fwd_b = 2'b01;
end
endmodule


// ================= HAZARD UNIT =================
module HazardUnit(
    input id_ex_mread,
    input [4:0] id_ex_rt,
    input [4:0] if_id_rs, if_id_rt,
    output reg stall_sig
);

always @(*) begin
    if (id_ex_mread && ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt)))
        stall_sig = 1;
    else
        stall_sig = 0;
end
endmodule


module Control(
    input [5:0] op,
    output reg dst, src, m2r, rwe,
    output reg mrd, mwr, br,
    output reg [1:0] alu_op,
    output reg jmp
);

always @(*) begin
    case(op)
        6'b000000: begin // R-type
            dst=1; src=0; m2r=0; rwe=1;
            mrd=0; mwr=0; br=0; alu_op=2'b10; jmp=0;
        end
        6'b100011: begin // lw
            dst=0; src=1; m2r=1; rwe=1;
            mrd=1; mwr=0; br=0; alu_op=2'b00; jmp=0;
        end
        6'b101011: begin // sw
            dst=0; src=1; m2r=0; rwe=0;
            mrd=0; mwr=1; br=0; alu_op=2'b00; jmp=0;
        end
        6'b000100: begin // beq
            dst=0; src=0; m2r=0; rwe=0;
            mrd=0; mwr=0; br=1; alu_op=2'b01; jmp=0;
        end
        6'b000010: begin // jump
            dst=0; src=0; m2r=0; rwe=0;
            mrd=0; mwr=0; br=0; alu_op=2'b00; jmp=1;
        end
        default: begin
            dst=0; src=0; m2r=0; rwe=0;
            mrd=0; mwr=0; br=0; alu_op=2'b00; jmp=0;
        end
    endcase
end
endmodule


// ================= ALU CONTROL =================
module ALUControl(
    input [1:0] op_mode,
    input [5:0] func,
    output reg [3:0] alu_cmd
);

always @(*) begin
    case(op_mode)
        2'b00: alu_cmd = 4'b0010;
        2'b01: alu_cmd = 4'b0110;
        2'b10: begin
            case(func)
                6'b100000: alu_cmd = 4'b0010;
                6'b100010: alu_cmd = 4'b0110;
                6'b100100: alu_cmd = 4'b0000;
                6'b100101: alu_cmd = 4'b0001;
                6'b101010: alu_cmd = 4'b0111;
                default:   alu_cmd = 4'b0000;
            endcase
        end
        default: alu_cmd = 4'b0000;
    endcase
end
endmodule


// ================= ALU =================
module ALU(
    input [31:0] src_a, src_b,
    input [3:0] cmd,
    output reg [31:0] out,
    output zero
);

always @(*) begin
    case(cmd)
        4'b0000: out = src_a & src_b;
        4'b0001: out = src_a | src_b;
        4'b0010: out = src_a + src_b;
        4'b0110: out = src_a - src_b;
        4'b0111: out = (src_a < src_b) ? 1 : 0;
        default: out = 0;
    endcase
end

assign zero = (out == 0);
endmodule


// ================= REGISTER FILE =================
module RegFile(
    input clk,
    input we,
    input [4:0] ra1, ra2, wa,
    input [31:0] wd,
    output [31:0] rd1, rd2
);

reg [31:0] internal_regs [0:31];

assign rd1 = internal_regs[ra1];
assign rd2 = internal_regs[ra2];

always @(posedge clk) begin
    if (we)
        internal_regs[wa] <= wd;
end
endmodule