// Edited By SeungJae Yoo (2020.04.19)
`include "opcodes.v" 

module register (readReg1, readReg2, writeReg, readReg1Data, readReg2Data, writeRegData, regReadReady, regWriteReady, regReadComplete, regWriteComplete, reset_n);

	input [1:0] readReg1;						// Read Register 1
	input [1:0] readReg2;						// Read Register 2
	input [1:0] writeReg;						// Write Register
	output reg [`WORD_SIZE-1:0] readReg1Data;	// Data of Read Register 1
	output reg [`WORD_SIZE-1:0] readReg2Data;	// Data of Read Register 2
	input [`WORD_SIZE-1:0] writeRegData;		// Data of Write Register

	input regReadReady;							// Is Read Register ready
	input regWriteReady;						// Is Write Register ready
	output reg regReadComplete;					// Is Read Register completed
	output reg regWriteComplete;				// Is Write Register completed

	input reset_n;								// Reset Bit

	reg [`WORD_SIZE-1:0] registers [0:`NUM_REGS-1];	// Register Storage

	// Reset
	always @(negedge reset_n) begin
		// Register Storage
		registers[0] <= 0;
		registers[1] <= 0;
		registers[2] <= 0;
		registers[3] <= 0;
		
		// Output
		readReg1Data <= 0;
		readReg2Data <= 0;
		regReadComplete <= 0;
		regWriteComplete <= 0;
	end

	// Read Register
	always @(posedge regReadReady) begin
		readReg1Data = registers[readReg1];
		readReg2Data = registers[readReg2];
		regReadComplete = 1;
	end

	always @(negedge regReadReady) begin
		regReadComplete = 0;
	end

	// Write Register
	always @(posedge regWriteReady) begin
		registers[writeReg] = writeRegData;
		regWriteComplete = 1;
	end

	always @(negedge regWriteReady) begin
		regWriteComplete = 0;
	end


endmodule
