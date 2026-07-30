`timescale 1ns / 1ps

module tb_top;

reg clk;
reg rst;

// Instantiate DUT (Device Under Test)
Top_module_single_cycle_mips_processor uut (
    .clk(clk),
    .rst(rst)
);

/////////////////////////////////////////////////
// CLOCK GENERATION (10 ns period)
/////////////////////////////////////////////////

always #6 clk = ~clk;

/////////////////////////////////////////////////
// INITIAL BLOCK
/////////////////////////////////////////////////

initial begin

// Initialize signals
clk = 0;
rst = 1;

// Apply reset
#10;
rst = 0;

// Run simulation for enough cycles
#1000;

// Finish simulation
$finish;

end

/////////////////////////////////////////////////
// MONITOR SIGNALS (VERY IMPORTANT FOR DEBUG)
/////////////////////////////////////////////////

initial begin
$monitor("Time=%0t | PC=%h | Instruction=%h | ALU_out=%h | Zero=%b",
         $time,
         uut.pc_out,
         uut.instruction,
         uut.Alu_out,
         uut.zero);
end


endmodule