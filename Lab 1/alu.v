`timescale 1ns / 100ps

`define	NumBits	16

module ALU (A, B, FuncCode, C, OverflowFlag);
	input [`NumBits-1:0] A;
	input [`NumBits-1:0] B;
	input [3:0] FuncCode;
	output [`NumBits-1:0] C;
	output OverflowFlag;

	reg [`NumBits-1:0] C;
	reg OverflowFlag;

	// You can declare any variables as needed.

	// new variables
	reg temp;

	initial begin
		C = 0;
		temp = 0;
		OverflowFlag = 0;
	end   	

	// TODO: You should implement the functionality of ALU!
	// (HINT: Use 'always @(...) begin ... end')

	// Alu Design
	always @(*) begin
		case (FuncCode)
			// Signed Addiction
			4'b0000 : begin
				C <= A + B;
				temp <= A[`NumBits-1];
				OverflowFlag <= (temp == B[`NumBits-1]) && (temp != C[`NumBits-1]);
			end	
			
			// Signed Subtraction
			4'b0001 : begin
				C <= A - B;
				temp <= A[`NumBits-1];
				OverflowFlag <= (temp != B[`NumBits-1]) && (temp != C[`NumBits-1]);
			end
			
			// Identity
			4'b0010 :
				C <= A;

			// bitwise NOT
			4'b0011 :
				C <= ~A;

			// bitwise AND
			4'b0100 :
				C <= A&B;
			
			// bitwise OR
			4'b0101 :
				C <= A|B;

			// bitwise NAND
			4'b0110 :
				C <= ~(A&B);

			// bitwise NOR
			4'b0111 :
				C <= ~(A|B);

			// bitwise XOR
			4'b1000 :
				C <= A^B;

			// bitwise XNOR
			4'b1001 :
				C <= ~(A^B);

			// Logical Left Shift
			4'b1010 :
				C <= A << 1;

			// Logical Right Shift
			4'b1011 :
				C <= A >> 1;
				
			// Arithmetic Left Shift
			4'b1100 :
				C <= A << 1;

			// Arithmetic Right Shift
			4'b1101 :
				C <= (A[`NumBits-1] << (`NumBits-1)) + (A >> 1);

			// Two's Complement
			4'b1110 :
				C <= ~A + 1;

			// Zero
			4'b1111 :
				C <= 0;
		endcase
	end
endmodule

