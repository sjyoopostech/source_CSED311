`timescale 1ns/1ns
`define WORD_SIZE 16    // data and address word size

module cpu(clk, reset_n, readM, writeM, address, data, num_inst, output_port, is_halted);
	input clk;
	input reset_n;
	
	output readM;
	output writeM;
	output [`WORD_SIZE-1:0] address;

	inout [`WORD_SIZE-1:0] data;

	output [`WORD_SIZE-1:0] num_inst;		// number of instruction during execution (for debuging & testing purpose)
	output [`WORD_SIZE-1:0] output_port;	// this will be used for a "WWD" instruction
	output is_halted;

	// TODO : Implement your multi-cycle CPU!
	reg [`WORD_SIZE-1:0] num_inst;
	reg [`WORD_SIZE-1:0] output_port;

	// state
	reg [`WORD_SIZE-1:0] STATE;

	// storage unit
	reg [`WORD_SIZE-1:0] PC;
	reg [`WORD_SIZE-1:0] IR;
	reg [`WORD_SIZE-1:0] MDR;
	reg [`WORD_SIZE-1:0] A;
	reg [`WORD_SIZE-1:0] B;
	reg [`WORD_SIZE-1:0] ALUOut;
	reg BranchOut;
	reg [1:0] writeReg;

	// multiplexer
	wire [`WORD_SIZE-1:0] addressMux;
	wire [`WORD_SIZE-1:0] aluInput1Mux;
	wire [`WORD_SIZE-1:0] aluInput2Mux;
	wire [`WORD_SIZE-1:0] writeDataMux;


	// control bit
	wire [1:0] ALUSrcB;
	wire ALUSrcA, IorD, MemtoReg, RegWrite, PCWrite, IRWrite, MDRWrite, ABWrite, ALUWrite, BranchWrite;
	reg [15:0] Controller;

	// Register
	wire [1:0] readReg1, readReg2;
	wire [`WORD_SIZE-1:0] readData1, readData2;

	// Imm Generator
	wire [`WORD_SIZE-1:0] immOut;

	// ALU
	wire [3:0] aluOpcode;
	wire bcond;
	wire [`WORD_SIZE-1:0] aluResult;

	// assign register
	assign readReg1 = IR[11:10];
	assign readReg2 = IR[9:8];

	// assign control bit
	// ALUSrcA, ALUSrcB[1], ALUSrcB[0], IorD, MemtoReg, RegWrite
	// PCWrite, IRWrite, MDRWrite, ABWrite, ALUWrite, BranchWrite
	// readM, writeM, is_halted
	assign ALUSrcA = Controller[14];
	assign ALUSrcB = Controller[13:12];
	assign IorD = Controller[11];
	assign MemtoReg = Controller[10];
	assign RegWrite = Controller[9];

	assign PCWrite = Controller[8];
	assign IRWrite = Controller[7];
	assign MDRWrite = Controller[6];
	assign ABWrite = Controller[5];
	assign ALUWrite = Controller[4];
	assign BranchWrite = Controller[3];

	assign readM = Controller[2];
	assign writeM = Controller[1];
	assign is_halted = Controller[0];

	// Assign Mux
	assign addressMux = (IorD) ? ALUOut : PC;
	assign aluInput1Mux = (ALUSrcA) ? A : PC;
	assign aluInput2Mux = (ALUSrcB[1]) ? immOut : ((ALUSrcB[0]) ? 16'b1 : B);
	assign writeDataMux = (MemtoReg) ? MDR : ALUOut;

	// Data input and output control
	assign data = (writeM) ? B : `WORD_SIZE'bz;
	assign address = addressMux;

	// modules 
	REGISTER U_REGISTER (reset_n, readReg1, readReg2, writeReg, writeDataMux, readData1, readData2, RegWrite);
	ALUCONTROL U_ALUCONTROL (IR, aluOpcode, STATE);
	ALU U_ALU (aluInput1Mux, aluInput2Mux, aluOpcode, aluResult, bcond);
	IMMGEN U_IMMGEN (IR, immOut);

	// change state
	always @(posedge clk) begin
		if (!reset_n) begin
			STATE <= 0;
		end
		else begin
			case (STATE)
				// IR <- PC
				8'd00 : begin
					if ((IR[15:12]==8'd15 && IR[5:0]==8'd26) || (IR[15:12]==8'd10)) STATE <= 8'd02;	// JAL, JRL
					else if (IR[15:12]==8'd15 && IR[5:0]==8'd29) STATE <= 8'd15;					// HLT
					else STATE <= 8'd01;
				end
				// A, B <- IR
				8'd01 : begin
					if (IR[15:12]==8'd15 && IR[5:0]==8'd28) STATE <= 8'd10;							// WWD
					else if (IR[15:12]==8'd15 && IR[5:3]==0) STATE <= 8'd04;						// R-type Arithmetric
					else if (IR[15:14]==0) STATE <= 8'd05;											// Branch
					else STATE <= 8'd03;
				end
				// A, B <- IR / ALUOut <- PC
				8'd02 : STATE <= 8'd06;
				// ALUOut <- A, Imm
				8'd03 : begin
					if ((IR[15:12]==8'd15 && IR[5:0]==8'd25) || (IR[15:12]==8'd09)) STATE <= 8'd14;	// JMP, JPR
					else if (IR[15:12]==8'd07) STATE <= 8'd08;										// LWD
					else if (IR[15:12]==8'd08) STATE <= 8'd07;										// SWD
					else STATE <= 8'd06;
				end
				// ALUOut <- A, B
				8'd04 : STATE <= 8'd06;
				// Branchout <- A, B
				8'd05 : begin
					if (BranchOut) STATE <= 8'd11;													// Branchout = 1
					else STATE <= 8'd12;															// Branchout = 0
				end
				// Reg <- ALUOut
				8'd06 : begin
					if ((IR[15:12]==8'd15 && IR[5:0]==8'd26) || (IR[15:12]==8'd10)) STATE <= 8'd13; // JAL, JRL
					else STATE <= 8'd12;
				end
				// MEM <- B, ALUOut
				8'd07 : STATE <= 8'd12;
				// MDR <- B, ALUOut
				8'd08 : STATE <= 8'd09;
				// Reg <- MDR
				8'd09 : STATE <= 8'd12;
				// output_port <- A
				8'd10 : STATE <= 8'd12;
				// ALUOut <- PC+Imm
				8'd11 : STATE <= 8'd14;
				// ALUOut <- PC+1
				8'd12 : STATE <= 8'd14;
				// ALUOut <- A, Imm
				8'd13 : STATE <= 8'd14;
				// PC <- ALUOut
				8'd14 : STATE <= 8'd00;
				// is_halted <- 1
				8'd15 : STATE <= 8'd15;
			endcase
			
		end
	end

	// update control bit
	always @(*) begin
		if (!reset_n) begin
			Controller <= 0;
			num_inst <= 0;
			output_port <= 0;
		end
		else begin
			// Controller
			// ALUSrcA, ALUSrcB[1], ALUSrcB[0], IorD, MemtoReg, RegWrite
			// PCWrite, IRWrite, MDRWrite, ABWrite, ALUWrite, BranchWrite
			// readM, writeM, is_halted
			case (STATE)
				// IR <- PC
				8'd00 : Controller = 15'b000000010000100;
				// A, B <- IR
				8'd01 : begin
					Controller = 15'b000000000100000;
					if (IR[15:12]==8'd15 && IR[5:3]==0) writeReg = IR[7:6];		// R-type arithmetric
					else if (IR[15:12]==8'd15) writeReg = 2'b10;				// Jump instruction
					else writeReg = IR[9:8];									// otherwise
				end
				// A, B <- IR / ALUOut <- PC
				8'd02 : begin
					Controller = 15'b001000000110000;
					writeReg = 2'b10;
				end
				// ALUOut <- A, Imm
				8'd03 : Controller = 15'b110000000010000;
				// ALUOut <- A, B
				8'd04 : Controller = 15'b100000000010000;
				// Branchout <- A, B
				8'd05 : Controller = 15'b100000000001000;
				// Reg <- ALUOut
				8'd06 : Controller = 15'b000001000000000;
				// MEM <- B, ALUOut
				8'd07 : Controller = 15'b000100000000010;
				// MDR <- B, ALUOut
				8'd08 : Controller = 15'b000100001000100;
				// Reg <- MDR
				8'd09 : Controller = 15'b000011000000000;
				// output_port <- A
				8'd10 : begin
					Controller = 15'b000000000000000;
					output_port = A;
				end
				// ALUOut <- PC+Imm
				8'd11 : Controller = 15'b010000000010000;
				// ALUOut <- PC+1
				8'd12 : Controller = 15'b001000000010000;
				// ALUOut <- A, Imm
				8'd13 : Controller = 15'b110000000010000;
				// PC <- ALUOut
				8'd14 : begin
					Controller = 15'b000000100000000;
					num_inst = num_inst + 1;
				end
				// is_halted <- 1
				8'd15 : begin
					Controller = 15'b000000000000000;
					num_inst = num_inst + 1;
				end
			endcase
		end
	end

	// update storage unit
	always @(*) begin
		if (!reset_n) begin
			PC <= 0;
			IR <= 0;
			MDR <= 0;
			A <= 0;
			B <= 0;
			ALUOut <= 0;
			BranchOut <= 0;
			writeReg <= 0;
		end
		else begin
			if (PCWrite) PC = ALUOut;
			if (IRWrite) IR = data;
			if (MDRWrite) MDR = data;
			if (ABWrite) begin
				A = readData1;
				B = readData2;
			end
			if (ALUWrite) ALUOut = aluResult;
			if (BranchWrite) BranchOut = bcond;
		end
	end
endmodule

// register module
module REGISTER(reset_n, readReg1, readReg2, writeReg, writeData, readData1, readData2, RegWrite);

	// reset
	input reset_n;

	// register address
	input [1:0] readReg1;
	input [1:0] readReg2;
	input [1:0] writeReg;

	// register data
	input [`WORD_SIZE-1:0] writeData;
	output wire [`WORD_SIZE-1:0] readData1;
	output wire [`WORD_SIZE-1:0] readData2;

	// write control
	input RegWrite;

	// register storage
	reg [`WORD_SIZE-1:0] registers [0:3];

	// read register
	assign readData1 = registers[readReg1];
	assign readData2 = registers[readReg2];

	always @(*) begin
		if (!reset_n) begin
			registers[0] <= 0;
			registers[1] <= 0;
			registers[2] <= 0;
			registers[3] <= 0;
		end
		else begin
			// write register
			if (RegWrite) registers[writeReg] = writeData;
		end
	end
endmodule

// alu module
module ALU(aluInput1, aluInput2, aluOpcode, aluResult, bcond);

	// ALU data
	input [`WORD_SIZE-1:0] aluInput1;
	input [`WORD_SIZE-1:0] aluInput2;
	output reg [`WORD_SIZE-1:0] aluResult;

	// ALUOp
	input [3:0] aluOpcode;

	// Branch Condition
	output reg bcond;

	always @(*) begin
		case (aluOpcode)
			// basic arithmetric
			4'b0000 : aluResult = aluInput1 + aluInput2;
			4'b0001 : aluResult = aluInput1 + (~aluInput2) + 1;
			4'b0010 : aluResult = aluInput1 & aluInput2;
			4'b0011 : aluResult = aluInput1 | aluInput2;
			4'b0100 : aluResult = ~aluInput1;
			4'b0101 : aluResult = (~aluInput1) + 1;
			4'b0110 : aluResult = aluInput1 << 1;
			4'b0111 : aluResult = (aluInput1[`WORD_SIZE-1] << (`WORD_SIZE-1)) + (aluInput1 >> 1);

			// LHI
			4'b1000 : aluResult = aluInput2 << 8;

			// Identity
			4'b1001 : aluResult = aluInput1;
			4'b1010 : aluResult = aluInput2;

			// more instruction for branch
			4'b1011 : aluResult = aluInput1 + aluInput2 + 1;
			4'b1100 : bcond = (aluInput1 != aluInput2);
			4'b1101 : bcond = (aluInput1 == aluInput2);
			4'b1110 : bcond = ((~aluInput1[15]) && (aluInput1 != 0));
			4'b1111 : bcond = (aluInput1[15]);
		endcase
	end
endmodule

// alu control module
module ALUCONTROL(IR, aluOpcode, STATE);

	// instruction and state
	input [`WORD_SIZE-1:0] IR;
	input [`WORD_SIZE-1:0] STATE;

	// ALUOp
	output reg [3:0] aluOpcode;

	always @(*) begin
		case (IR[15:12])
			4'b1111 : begin
				// R-type arithmetric
				if (IR[5:3]==0) begin
					if (STATE == 8'd4) aluOpcode = IR[3:0];
					else if (STATE == 8'd12) aluOpcode = 4'b0000;
				end
				// JPR
				else if (IR[5:0] == 25) begin
					if (STATE == 8'd3) aluOpcode = 4'b1001;
				end
				// JRL
				else if (IR[5:0] == 26) begin
					if (STATE == 8'd2) aluOpcode = 4'b0000;
					else if (STATE == 8'd13) aluOpcode = 4'b1001;
				end
				// WWD
				else if (IR[5:0] == 28) begin
					if (STATE == 8'd12) aluOpcode = 4'b0000;
				end
			end
			// JMP
			4'b1001 : begin
				if (STATE == 8'd3) aluOpcode = 4'b1010;
			end
			// JAL
			4'b1010 : begin
				if (STATE == 8'd2) aluOpcode = 4'b0000;
				else if (STATE == 8'd13) aluOpcode = 4'b1010;
			end
			// ADI
			4'b0100 : begin
				if (STATE == 8'd3) aluOpcode = 4'b0000;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// ORI
			4'b0101 : begin
				if (STATE == 8'd3) aluOpcode = 4'b0011;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// LHI
			4'b0110 : begin
				if (STATE == 8'd3) aluOpcode = 4'b1000;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// LWD
			4'b0111 : begin
				if (STATE == 8'd3) aluOpcode = 4'b0000;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// SWD
			4'b1000 : begin
				if (STATE == 8'd3) aluOpcode = 4'b0000;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// BNE
			4'b0000 : begin
				if (STATE == 8'd5) aluOpcode = 4'b1100;
				else if (STATE == 8'd11) aluOpcode = 4'b1011;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// BEQ
			4'b0001 : begin
				if (STATE == 8'd5) aluOpcode = 4'b1101;
				else if (STATE == 8'd11) aluOpcode = 4'b1011;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// BGZ
			4'b0010 : begin
				if (STATE == 8'd5) aluOpcode = 4'b1110;
				else if (STATE == 8'd11) aluOpcode = 4'b1011;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
			// BLZ
			4'b0011 : begin
				if (STATE == 8'd5) aluOpcode = 4'b1111;
				else if (STATE == 8'd11) aluOpcode = 4'b1011;
				else if (STATE == 8'd12) aluOpcode = 4'b0000;
			end
		endcase
	end


endmodule

// imm generator module
module IMMGEN(IR, immOut);

	// instruciton
	input [`WORD_SIZE-1:0] IR;

	// output
	output reg [`WORD_SIZE-1:0] immOut;

	always @(*) begin
		// if : J-type, else : R-type or I-type
		if (IR[15:12]==8'd9 || IR[15:12]==8'd10) immOut = (IR[11]) ? {4'b1111,IR[11:0]} : IR[11:0];
		else immOut = (IR[7]) ? {8'b11111111,IR[7:0]} : IR[7:0];
	end

endmodule