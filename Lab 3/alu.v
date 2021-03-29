// Edited By SeungJae Yoo (2020.04.19)
`include "opcodes.v"

module ALU (A, B, C, aluCode, aluReady, aluComplete, reset_n);

	input [`WORD_SIZE-1:0] A;		// ALU Input 1
	input [`WORD_SIZE-1:0] B;		// ALU Input 2
	output reg [`WORD_SIZE-1:0] C;	// ALU Output
	
	input [3:0] aluCode;			// Code of ALU

	input aluReady;					// Is ALU ready
	output reg aluComplete;			// Is ALU completed

	input reset_n;					// Reset Bit

	// Reset
	always @(negedge reset_n) begin
		C <= 0;
		aluComplete <= 0;
	end   	

	// ALU Design
	always @(posedge aluReady) begin
		case (aluCode)
			4'b0000 : C = A + B;											// FUNC_ADD
			4'b0001 : C = A + (~B) + 1;										// FUNC_SUB
			4'b0010 : C = A & B;											// FUNC_AND
			4'b0011 : C = A | B;											// FUNC_ORR
			4'b0100 : C = ~A; 												// FUNC_NOT
			4'b0101 : C = (~A) + 1; 										// FUNC_TCP
			4'b0110 : C = A << 1; 											// FUNC_SHL
			4'b0111 : C = (A[`WORD_SIZE-1] << (`WORD_SIZE-1)) + (A >> 1); 	// FUNC_SHR
			4'b1000 : C = B << 8; 											// LHI_OP
			4'b1001 : C = A; 												// Identity A (Branch)
			4'b1010 : C = B; 												// Identity B (Jump)
		endcase
		aluComplete = 1;
	end

	always @(negedge aluReady) begin
		aluComplete = 0;
	end

endmodule

