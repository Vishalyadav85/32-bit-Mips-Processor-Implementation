`timescale 1ns/1ps

module tb_mips;

reg clk;
reg reset;

// DUT
Top_module uut (
    .clk(clk),
    .reset(reset)
);

// Clock
always #5 clk = ~clk;

initial begin

    clk   = 0;
    reset = 1;

    //================ Register Initialization =================//
    uut.RF.internal_regs[1] = 10;
    uut.RF.internal_regs[2] = 5;
    uut.RF.internal_regs[3] = 3;
    uut.RF.internal_regs[4] = 2;
    uut.RF.internal_regs[5] = 7;

    //================ Data Memory Initialization ==============//
    uut.data_mem[2] = 20;
    uut.data_mem[4] = 50;

    //==========================================================
    //                  TEST VECTORS
    //==========================================================

    //---------------- Arithmetic ----------------//
    // add  r1 = r2+r3 = 8
    uut.inst_mem[0] =
    32'b000000_00010_00011_00001_00000_100000;

    // sub r6 = r1-r4 = 6
    uut.inst_mem[1] =
    32'b000000_00001_00100_00110_00000_100010;

    //---------------- Forwarding ----------------//
    // add r7 = r6+r5 =13
    uut.inst_mem[2] =
    32'b000000_00110_00101_00111_00000_100000;

    // add r8 = r7+r6 =19
    uut.inst_mem[3] =
    32'b000000_00111_00110_01000_00000_100000;

    //---------------- Load Use Hazard ------------//
    // lw r9,0(r1)
    uut.inst_mem[4] =
    32'b100011_00001_01001_0000000000000000;

    // add r10=r9+r2
    uut.inst_mem[5] =
    32'b000000_01001_00010_01010_00000_100000;

    //---------------- Store ----------------------//
    // sw r10,4(r1)
    uut.inst_mem[6] =
    32'b101011_00001_01010_0000000000000100;

    //---------------- Branch Taken ---------------//
    // beq r2,r2 skip next
    uut.inst_mem[7] =
    32'b000100_00010_00010_0000000000000001;

    // flushed instruction
    uut.inst_mem[8] =
    32'b000000_00010_00010_01011_00000_100000;

    // executes
    uut.inst_mem[9] =
    32'b000000_00011_00011_01100_00000_100000;

    //---------------- Branch Not Taken -----------//
    // beq r2,r3 not taken
    uut.inst_mem[10] =
    32'b000100_00010_00011_0000000000000001;

    // executes
    uut.inst_mem[11] =
    32'b000000_00100_00100_01101_00000_100000;

    //---------------- Double Forwarding ----------//
    // add r14=r2+r3
    uut.inst_mem[12] =
    32'b000000_00010_00011_01110_00000_100000;

    // add r15=r14+r14
    uut.inst_mem[13] =
    32'b000000_01110_01110_01111_00000_100000;

    // add r16=r15+r14
    uut.inst_mem[14] =
    32'b000000_01111_01110_10000_00000_100000;

    //---------------- SLT Checks -----------------//
    // slt r17=(r3<r2)
    uut.inst_mem[15] =
    32'b000000_00011_00010_10001_00000_101010;

    // slt r18=(r2<r3)
    uut.inst_mem[16] =
    32'b000000_00010_00011_10010_00000_101010;

    // Release reset
    #10 reset = 0;

    // simulation time
    #400;

    //==========================================================
    // RESULTS
    //==========================================================
    $display("\n========================================");
    $display("      MIPS PIPELINE SIMULATION RESULTS");
    $display("========================================");

    $display("\n--- Arithmetic ---");
    $display("Reg[1]  : %d", uut.RF.internal_regs[1]);
    $display("Reg[6]  : %d", uut.RF.internal_regs[6]);

    $display("\n--- Forwarding ---");
    $display("Reg[7]  : %d", uut.RF.internal_regs[7]);
    $display("Reg[8]  : %d", uut.RF.internal_regs[8]);

    $display("\n--- Load/Use Hazard ---");
    $display("Reg[9]  : %d", uut.RF.internal_regs[9]);
    $display("Reg[10] : %d", uut.RF.internal_regs[10]);

    $display("\n--- Store Check ---");
    $display("Mem[12] : %d", uut.data_mem[12>>2]);

    $display("\n--- Branch Control ---");
    $display("Reg[11] : %d", uut.RF.internal_regs[11]);
    $display("Reg[12] : %d", uut.RF.internal_regs[12]);
    $display("Reg[13] : %d", uut.RF.internal_regs[13]);

    $display("\n--- Double Forwarding ---");
    $display("Reg[14] : %d", uut.RF.internal_regs[14]);
    $display("Reg[15] : %d", uut.RF.internal_regs[15]);
    $display("Reg[16] : %d", uut.RF.internal_regs[16]);

    $display("\n--- SLT Check ---");
    $display("Reg[17] : %d", uut.RF.internal_regs[17]);
    $display("Reg[18] : %d", uut.RF.internal_regs[18]);

    $display("========================================\n");

    $stop;

end

endmodule