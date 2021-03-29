`timescale 1ns/1ns
`define WORD_SIZE 16    // data and address word size

module cpuinside(Clk, Reset_N, readM1, address1, data1, readM2, writeM2, address2, data2, num_inst, output_port, is_halted, chk1, chk2);
	input Clk;
	wire Clk;
	input Reset_N;
	wire Reset_N;

	output readM1;
	wire readM1;
	output [`WORD_SIZE-1:0] address1;
	wire [`WORD_SIZE-1:0] address1;
	output readM2;
	wire readM2;
	output writeM2;
	wire writeM2;
	output [`WORD_SIZE-1:0] address2;
	wire [`WORD_SIZE-1:0] address2;

	input [`WORD_SIZE-1:0] data1;
	wire [`WORD_SIZE-1:0] data1;
	inout [`WORD_SIZE-1:0] data2;
	wire [`WORD_SIZE-1:0] data2;

	output [`WORD_SIZE-1:0] num_inst;
	wire [`WORD_SIZE-1:0] num_inst;
	output [`WORD_SIZE-1:0] output_port;
	wire [`WORD_SIZE-1:0] output_port;
	output is_halted;
	wire is_halted;

	input chk1;
	input chk2;
	// TODO : Implement your pipelined CPU!

	reg IMstall, DMstall;
	reg [`WORD_SIZE-1:0] oldPC, oldMEM_IR;
	reg IMchanged, DMchanged;

	reg [3:0] oldflush, flush, stall, oldstall;
	wire use1, use2;
	reg OutputWrite;

	reg PCWrite, IFIDWrite, IDEXWrite, EXMEMWrite, MEMWBWrite;
	reg [`WORD_SIZE-1:0] numinst, newinst;
	reg [`WORD_SIZE-1:0] outputport;

	reg [1:0] PCSrc;
	wire ALUSrc;
	wire MemtoReg;
	wire RegWrite;
	wire PCorReg;

	reg [`WORD_SIZE-1:0] PC;
	wire [`WORD_SIZE-1:0] PC1;
	wire [`WORD_SIZE-1:0] PC_next;
	wire [`WORD_SIZE-1:0] ID_PC, ID_IR;

	wire [`WORD_SIZE-1:0] ID_immOut;
	wire [`WORD_SIZE-1:0] PCimm;
	wire [1:0] ID_rReg1, ID_rReg2, ID_wReg;
	wire [`WORD_SIZE-1:0] ID_rRegData1, ID_rRegData2;
	wire [`WORD_SIZE-1:0] ID_PCreg;
	wire bcond;

	wire [`WORD_SIZE-1:0] EX_rRegData1, EX_rRegData2, EX_immOut, EX_IR;
	wire [1:0] EX_wReg;
	wire [`WORD_SIZE-1:0] EX_aluOut;
	wire [`WORD_SIZE-1:0] aluInput2;
	wire [3:0] aluOpcode;

	wire [`WORD_SIZE-1:0] MEM_aluOut, MEM_data, MEM_IR;
	wire [1:0] MEM_wReg;

	wire [`WORD_SIZE-1:0] WB_aluOut, WB_data, WB_IR;
	wire [1:0] WB_wReg;
	wire [`WORD_SIZE-1:0] WB_wRegData;

	assign num_inst = numinst;

	assign use1 = ~(ID_IR[15:12] == 8'd6 || ID_IR[15:12] == 8'd9 || ID_IR[15:12] == 8'd10 || (ID_IR[15:12] == 8'd15 && ID_IR[5:0] == 8'd29));
	assign use2 = ~(ID_IR[15:14] == 8'd1 || ID_IR[15:12] == 8'd9 || ID_IR[15:12] == 8'd10 || (ID_IR[15:12] == 8'd15 && ID_IR[5:0] == 8'd29));


	// IF
	assign address1 = PC;
	assign PC1 = PC + 1;
	assign readM1 = 1;

	Mux_2bit Mux_PC (PCSrc, PC1, ID_rRegData1, ID_immOut, PCimm, PC_next);
	Pipe_IFID pipe1 (IFIDWrite, Clk, Reset_N, PC1, data1, ID_PC, ID_IR);

	// ID
	assign PCimm = ID_PC + ID_immOut;
	assign PCorReg = ((ID_IR[15:12] == 8'd15 && ID_IR[5:0] == 8'd26) || ID_IR[15:12] == 8'd10) ? 1 : 0;

	ImmGen imms (ID_IR, ID_immOut);
	Reg_select regss (ID_IR, ID_rReg1, ID_rReg2, ID_wReg);
	Registers regs (Clk, Reset_N, ID_rReg1, ID_rReg2, WB_wReg, ID_rRegData1, ID_rRegData2, WB_wRegData, RegWrite);
	Branch_cond bconds (ID_IR, ID_rRegData1, ID_rRegData2, ID_bcond);
	Mux_1bit MUX_IDPCreg(PCorReg, ID_rRegData1, ID_PC, ID_PCreg);
	Pipe_IDEX pipe2 (IDEXWrite, Clk, Reset_N, ID_PCreg, ID_rRegData2, ID_immOut, ID_wReg, ID_IR, EX_rRegData1, EX_rRegData2, EX_immOut, EX_wReg, EX_IR);

	// EX
	assign ALUSrc = (EX_IR[15:12] == 8'd15 && EX_IR[5:3] == 0) ? 0 : 1;

	Mux_1bit Mux_Aluinput2 (ALUSrc, EX_rRegData2, EX_immOut, aluInput2);
	alucontrol alucs (EX_IR, aluOpcode);
	alu alus (EX_rRegData1, aluInput2, aluOpcode, EX_aluOut);
	Pipe_EXMEM pipe3 (EXMEMWrite, Clk, Reset_N, EX_aluOut, EX_rRegData2, EX_wReg, EX_IR, MEM_aluOut, MEM_data, MEM_wReg, MEM_IR);

	// MEM
	assign address2 = MEM_aluOut;
	assign data2 = (writeM2) ? MEM_data : `WORD_SIZE'bz;
	assign readM2 = (MEM_IR[15:12] == 8'd7) ? 1 : 0;
	assign writeM2 = (MEM_IR[15:12] == 8'd8) ? 1 : 0;
	assign output_port = outputport;

	Pipe_MEMWB pipe4 (MEMWBWrite, Clk, Reset_N, MEM_aluOut, data2, MEM_wReg, MEM_IR, WB_aluOut, WB_data, WB_wReg, WB_IR);

	// WB
	assign MemtoReg = (WB_IR[15:12] == 8'd7) ? 1 : 0;
	assign RegWrite = ((WB_IR[15:14] == 8'd0 || WB_IR[15:13] == 8'd4 || (WB_IR[15:12] == 15 && WB_IR[5:3] != 0 && WB_IR[5:0] != 8'd26)) || ID_IR == WB_IR) ? 0 : 1;
	assign is_halted = (WB_IR[15:12] == 8'd15 && WB_IR[5:0] == 8'd29) ? 1 : 0;

	Mux_1bit Mux_writedata (MemtoReg, WB_aluOut, WB_data, WB_wRegData);

	// State Update
	always @(posedge Clk) begin
		if (!Reset_N) begin
			oldPC <= 1;
			PC <= 0;
			numinst <= 0;
			newinst <= 0;
			outputport <= 0;
			flush <= 0;
			oldflush <= 0;
			stall <= 0;
			OutputWrite <= 0;

			PCWrite <= 1;
			IFIDWrite <= 1;
			IDEXWrite <= 1;
			EXMEMWrite <= 1;
			MEMWBWrite <= 1;

			IMstall <= 0;
			DMstall <= 0;		
		end
		else begin
			oldPC <= PC;
			oldMEM_IR <= MEM_IR;
			if (OutputWrite) outputport <= MEM_aluOut;
			if (IMstall == 0) oldflush <= flush;
			if (PCWrite) PC <= PC_next;
			if (DMstall == 0) begin
				numinst <= newinst;
				oldstall <= stall;
				if (stall != 0) stall <= stall - 1;
			end
		end
	end

	// Control Stall, Flush, Write bits
	always @(*) begin
		// PCSrc
		if (oldflush) PCSrc = 2'b00;
		else if (ID_IR[15:14] == 8'd0 && ID_bcond == 1) PCSrc = 2'b11;
		else if (ID_IR[15:12] == 8'd9 || ID_IR[15:12] == 8'd10) PCSrc = 2'b10;
		else if (ID_IR[15:12] == 8'd15 && (ID_IR[5:0] == 8'd25 || ID_IR[5:0] == 8'd26)) PCSrc = 2'b01;
		else PCSrc = 2'b00;


		if (oldPC != PC && chk1 == 1) IMchanged = 0;
		else if (chk1 == 0) IMchanged = 1;
		if (oldMEM_IR != MEM_IR && chk2 == 1) DMchanged = 0;
		else if (chk2 == 0) DMchanged = 1;

		if ((readM2 || writeM2) && !DMchanged) DMstall = 1;
		else DMstall = 0;
		if (readM1 && !IMchanged) IMstall = 1;
		else IMstall = 0;

		if (PCSrc != 0 && (stall == 0 && !IMstall && !DMstall)) flush = 1;
		else flush = 0;

		if (oldstall == 0) begin
			if ((EX_wReg == ID_rReg1) && (~(EX_IR[15:14] == 8'd0 || EX_IR[15:13] == 8'd4 || (EX_IR[15:12] == 15 && EX_IR[5:3] != 0 && EX_IR[5:0] != 8'd26))) && use1) stall = 8'd2;
			else if ((EX_wReg == ID_rReg2) && (~(EX_IR[15:14] == 8'd0 || EX_IR[15:13] == 8'd4 || (EX_IR[15:12] == 15 && EX_IR[5:3] != 0 && EX_IR[5:0] != 8'd26))) && use2) stall = 8'd2;
			else if ((MEM_wReg == ID_rReg1) && (~(MEM_IR[15:14] == 8'd0 || MEM_IR[15:13] == 8'd4 || (MEM_IR[15:12] == 15 && MEM_IR[5:3] != 0 && MEM_IR[5:0] != 8'd26))) && use1) stall = 8'd1;
			else if ((MEM_wReg == ID_rReg2) && (~(MEM_IR[15:14] == 8'd0 || MEM_IR[15:13] == 8'd4 || (MEM_IR[15:12] == 15 && MEM_IR[5:3] != 0 && MEM_IR[5:0] != 8'd26))) && use2) stall = 8'd1;
			else stall = 0;
		end
		


		if (((stall != 0 || IMstall || DMstall) && !flush)) PCWrite = 0;
		else PCWrite = 1;
		if (flush || stall != 0 || IMstall || DMstall) IFIDWrite = 0;
		else IFIDWrite = 1;
		if ((stall != 0) || DMstall) IDEXWrite = 0;
		else IDEXWrite = 1;
		if (DMstall) EXMEMWrite = 0;
		else EXMEMWrite = 1;
		if (DMstall) MEMWBWrite = 0;
		else MEMWBWrite = 1;

		if (MEM_IR[15:12] == 8'd15 && MEM_IR[5:0] == 8'd28) OutputWrite = 1;
		else OutputWrite = 0;
		
		if (oldMEM_IR != MEM_IR) newinst = numinst + 1;
	end
endmodule

// Multiplexer 1 bit
module Mux_1bit(control, in0, in1, out);
	
	input control;

	input [`WORD_SIZE-1:0] in0;
	input [`WORD_SIZE-1:0] in1;
	output wire [`WORD_SIZE-1:0] out;

	assign out = (control) ? in1 : in0;

endmodule

// Multiplexer 2 bit
module Mux_2bit(control, in0, in1, in2, in3, out);
	
	input [1:0] control;

	input [`WORD_SIZE-1:0] in0;
	input [`WORD_SIZE-1:0] in1;
	input [`WORD_SIZE-1:0] in2;
	input [`WORD_SIZE-1:0] in3;
	output wire [`WORD_SIZE-1:0] out;

	assign out = (control[1]) ? ((control[0]) ? in3 : in2) : ((control[0]) ? in1 : in0);

endmodule

// ImmGen
module ImmGen(IR, immOut);

	input [`WORD_SIZE-1:0] IR;

	output reg [`WORD_SIZE-1:0] immOut;

	always @(*) begin
		if (IR[15:12]==8'd9 || IR[15:12]==8'd10) immOut = (IR[11]) ? {4'b1111,IR[11:0]} : IR[11:0];
		else immOut = (IR[7]) ? {8'b11111111,IR[7:0]} : IR[7:0];
	end

endmodule

// Register Address Selector
module Reg_select(IR, rReg1, rReg2, wReg);

	input [`WORD_SIZE-1:0] IR;
	output reg [1:0] rReg1;
	output reg [1:0] rReg2;
	output reg [1:0] wReg;	

	always @(*) begin
		if (IR[15:12] == 8'd15) begin
			rReg1 = IR[11:10];
			rReg2 = IR[9:8];
			if (IR[5:3] == 8'd0) wReg = IR[7:6];
			else wReg = 8'd2;
		end
		else begin
			rReg1 = IR[11:10];
			rReg2 = IR[9:8];
			if (IR[15:12] == 8'd10) wReg = 8'd2;
			else wReg = IR[9:8];
		end
	end
endmodule

// Register
module Registers(Clk, Reset_N, rReg1, rReg2, wReg, rRegData1, rRegData2, wRegData, RegWrite);

	input Clk;
	input Reset_N;

	input [1:0] rReg1;
	input [1:0] rReg2;
	input [1:0] wReg;	

	output wire [`WORD_SIZE-1:0] rRegData1;
	output wire [`WORD_SIZE-1:0] rRegData2;
	input [`WORD_SIZE-1:0] wRegData;

	input RegWrite;

	reg [`WORD_SIZE-1:0] regs [0:3];

	assign rRegData1 = (RegWrite && (wReg == rReg1)) ? wRegData : regs[rReg1];
	assign rRegData2 = (RegWrite && (wReg == rReg2)) ? wRegData : regs[rReg2];

	always @(posedge Clk) begin
		if (!Reset_N) begin
			regs[0] <= 0;
			regs[1] <= 0;
			regs[2] <= 0;
			regs[3] <= 0;
		end
		else if (RegWrite) regs[wReg] <= wRegData;
	end
endmodule

// Branch Condition Calculator
module Branch_cond(IR, data1, data2, bcond);

	input [`WORD_SIZE-1:0] IR;
	input [`WORD_SIZE-1:0] data1;
	input [`WORD_SIZE-1:0] data2;

	output reg bcond;

	always @(*) begin
		if ((IR[15:12] == 8'd0) && (data1 != data2)) bcond = 1;
		else if ((IR[15:12] == 8'd1) && (data1 == data2)) bcond = 1;
		else if ((IR[15:12] == 8'd2) && (data1[15] == 0) && (data1 != 0)) bcond = 1;
		else if ((IR[15:12] == 8'd3) && (data1[15] == 1)) bcond = 1;
		else bcond = 0;
	end
endmodule

// ALU Controller
module alucontrol(IR, aluOpcode);

	input [`WORD_SIZE-1:0] IR;
	output reg [3:0] aluOpcode;

	always @(*) begin
		if (IR[15:12] == 8'd15 && IR[5:3] == 0) aluOpcode = IR[3:0];
		else if (IR[15:12] == 8'd4) aluOpcode = 4'b0000;
		else if (IR[15:12] == 8'd5) aluOpcode = 4'b0011;
		else if (IR[15:12] == 8'd6) aluOpcode = 4'b1000;
		else if (IR[15:12] == 8'd7) aluOpcode = 4'b0000;
		else if (IR[15:12] == 8'd8) aluOpcode = 4'b0000;
		else aluOpcode = 4'b1001;
	end

endmodule

// ALU
module alu(aluInput1, aluInput2, aluOpcode, aluResult);

	input [`WORD_SIZE-1:0] aluInput1;
	input [`WORD_SIZE-1:0] aluInput2;
	output reg [`WORD_SIZE-1:0] aluResult;

	input [3:0] aluOpcode;

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
		endcase
	end
endmodule

// IF/ID pipe
module Pipe_IFID(IFIDWrite, Clk, Reset_N, IF_PC, IF_IR, ID_PC, ID_IR);

	input IFIDWrite;

	input Clk;
	input Reset_N;

	input [`WORD_SIZE-1:0] IF_PC;
	input [`WORD_SIZE-1:0] IF_IR;

	output reg [`WORD_SIZE-1:0] ID_PC;
	output reg [`WORD_SIZE-1:0] ID_IR;


	always @(posedge Clk) begin
		if (!Reset_N) begin
			ID_PC <= 0;
			ID_IR <= 0;
		end
		else if (IFIDWrite) begin
			ID_PC <= IF_PC;
			ID_IR <= IF_IR;
		end
	end
endmodule

// ID/EX pipe
module Pipe_IDEX(IDEXWrite, Clk, Reset_N, ID_rRegData1, ID_rRegData2, ID_immOut, ID_wReg, ID_IR, EX_rRegData1, EX_rRegData2, EX_immOut, EX_wReg, EX_IR);

	input IDEXWrite;

	input Clk;
	input Reset_N;

	input [`WORD_SIZE-1:0] ID_rRegData1;
	input [`WORD_SIZE-1:0] ID_rRegData2;
	input [`WORD_SIZE-1:0] ID_immOut;
	input [1:0] ID_wReg;
	input [`WORD_SIZE-1:0] ID_IR;

	output reg [`WORD_SIZE-1:0] EX_rRegData1;
	output reg [`WORD_SIZE-1:0] EX_rRegData2;
	output reg [`WORD_SIZE-1:0] EX_immOut;
	output reg [1:0] EX_wReg;
	output reg [`WORD_SIZE-1:0] EX_IR;

	always @(posedge Clk) begin
		if (!Reset_N) begin
			EX_rRegData1 <= 0;
			EX_rRegData2 <= 0;
			EX_immOut <= 0;
			EX_wReg <= 0;
			EX_IR <= 0;
		end
		else if (IDEXWrite) begin
			EX_rRegData1 <= ID_rRegData1;
			EX_rRegData2 <= ID_rRegData2;
			EX_immOut <= ID_immOut;
			EX_wReg <= ID_wReg;
			EX_IR <= ID_IR;

		end
	end
endmodule

// EX/MEM pipe
module Pipe_EXMEM(EXMEMWrite, Clk, Reset_N, EX_aluOut, EX_data, EX_wReg, EX_IR, MEM_aluOut, MEM_data, MEM_wReg, MEM_IR);

	input EXMEMWrite;

	input Clk;
	input Reset_N;

	input [`WORD_SIZE-1:0] EX_aluOut;
	input [`WORD_SIZE-1:0] EX_data;
	input [1:0] EX_wReg;
	input [`WORD_SIZE-1:0] EX_IR;


	output reg [`WORD_SIZE-1:0] MEM_aluOut;
	output reg [`WORD_SIZE-1:0] MEM_data;
	output reg [1:0] MEM_wReg;
	output reg [`WORD_SIZE-1:0] MEM_IR;

	always @(posedge Clk) begin
		if (!Reset_N) begin
			MEM_aluOut <= 0;
			MEM_data <= 0;
			MEM_wReg <= 0;
			MEM_IR <= 0;
		end
		else if (EXMEMWrite) begin
			MEM_aluOut <= EX_aluOut;
			MEM_data <= EX_data;
			MEM_wReg <= EX_wReg;
			MEM_IR <= EX_IR;
		end
	end
endmodule

// MEM/WB pipe
module Pipe_MEMWB(MEMWBWrite, Clk, Reset_N, MEM_aluOut, MEM_data, MEM_wReg, MEM_IR, WB_aluOut, WB_data, WB_wReg, WB_IR);

	input MEMWBWrite;

	input Clk;
	input Reset_N;
	
	input [`WORD_SIZE-1:0] MEM_aluOut;
	input [`WORD_SIZE-1:0] MEM_data;
	input [1:0] MEM_wReg;
	input [`WORD_SIZE-1:0] MEM_IR;

	output reg [`WORD_SIZE-1:0] WB_aluOut;
	output reg [`WORD_SIZE-1:0] WB_data;
	output reg [1:0] WB_wReg;
	output reg [`WORD_SIZE-1:0] WB_IR;

	always @(posedge Clk) begin
		if (!Reset_N) begin
			WB_aluOut <= 0;
			WB_data <= 0;
			WB_wReg <= 0;
			WB_IR <= 0;
		end
		else if (MEMWBWrite) begin
			WB_aluOut <= MEM_aluOut;
			WB_data <= MEM_data;
			WB_wReg <= MEM_wReg;
			WB_IR <= MEM_IR;
		end
	end
endmodule
