`timescale 1ns / 1ps

module tb_top_module;

reg clk;
reg rst;

// Instantiate DUT
Top_module uut (
    .clk(clk),
    .rst(rst)
);

// Clock generation (10ns period)
always #5 clk = ~clk;

// Initial block
initial begin
    clk = 0;
    rst = 1;

    // Apply reset
    #10;
    rst = 0;

    // Run simulation
    #300;

    $finish;
end

//------------------------------------------------------
// ? Initialize Instruction Memory
//------------------------------------------------------
initial begin
    // Format: memory[address] = instruction

    // ADDI (we simulate using lw-like immediate logic if needed)
    // Example program:

    // R1 = 5
    uut.d2.memory[0] = 32'b001000_00000_00001_0000000000000101; // addi r1, r0, 5

    // R2 = 10
    uut.d2.memory[1] = 32'b001000_00000_00010_0000000000001010; // addi r2, r0, 10

    // R3 = R1 + R2
    uut.d2.memory[2] = 32'b000000_00001_00010_00011_00000_100000; // add r3, r1, r2

    // R4 = R3 - R1
    uut.d2.memory[3] = 32'b000000_00011_00001_00100_00000_100010; // sub r4, r3, r1

    // Store R4 to memory[10]
    uut.d2.memory[4] = 32'b101011_00000_00100_0000000000001010; // sw r4, 10(r0)

    // Load back to R5
    uut.d2.memory[5] = 32'b100011_00000_00101_0000000000001010; // lw r5, 10(r0)

    // Infinite loop (jump to itself)
    uut.d2.memory[6] = 32'b000010_00000000000000000000000110; // j 6
end

//------------------------------------------------------
// ? Monitor Important Signals
//------------------------------------------------------
initial begin
    $monitor("TIME=%0t | PC=%h | Instr=%h | ALUResult=%h | R1=%d R2=%d R3=%d R4=%d R5=%d",
        $time,
        uut.instruction_address_out,
        uut.memory_out,
        uut.Alu_result,
        uut.d6.register_memory[1],
        uut.d6.register_memory[2],
        uut.d6.register_memory[3],
        uut.d6.register_memory[4],
        uut.d6.register_memory[5]
    );
end

//------------------------------------------------------
// ? Dump Waveform (for GTKWave / Vivado)
//------------------------------------------------------
initial begin
    $dumpfile("mips.vcd");
    $dumpvars(0, tb_top_module);
end

endmodule