// Edited By SeungJae Yoo (2020.04.19)
`include "opcodes.v"
`include "register.v"
`include "alu.v"
`include "alucontrol.v"

module cpu (readM, writeM, address, data, ackOutput, inputReady, reset_n, clk);

    // default input and output
	output reg readM;			        						
	output reg writeM;								
	output reg [`WORD_SIZE-1:0] address;	
	inout [`WORD_SIZE-1:0] data;		
	input ackOutput;								
	input inputReady;								
	input reset_n;									
	input clk;

    // Memory Variables
    wire [3:0] opcode;
    wire [`WORD_SIZE-1:0] dataSaved;
	reg loadStore1, loadStore2;

    // Control Bits
    reg RegWrite, ALUSrc, MemtoReg, Branch, PCtoReg, JMP, JAL, JWrite;

    // Register Variables
    wire [1:0] readReg1, readReg2, writeReg;
    wire [`WORD_SIZE-1:0] readReg1Data, readReg2Data, writeRegData;
    reg regReadReady, regWriteReady;
	wire regReadComplete, regWriteComplete;

    // ALU Variables
    wire [`WORD_SIZE-1:0] ALUInput1, ALUInput2, ALUResult;
    wire [3:0] aluCode;
    reg bcond;
	reg aluReady;
	wire aluComplete;

    // Program Counter
    reg [`WORD_SIZE-1:0] PC;
    wire [`WORD_SIZE-1:0] PC4, PCImm;

    // Immediate Generator
    wire [`WORD_SIZE-1:0] ImmGen;

    // Multiplexer
    wire [`WORD_SIZE-1:0] ALUMux, PCMux0, PCMux1, MemMux;
    wire PCSrc;

    // Assign Memory Variables
    assign data = (loadStore2) ? readReg2Data : 16'bz;
	assign dataSaved = (loadStore1) ? data : dataSaved;

    // Assign Register Variables
    assign opcode = dataSaved[15:12];
    assign readReg1 = dataSaved[11:10];
    assign readReg2 = (JAL) ? dataSaved[11:10] : dataSaved[9:8];
    assign writeReg = (JWrite) ? 2'b10 : ((opcode == 4'd15) ? dataSaved[7:6] : dataSaved[9:8]);
    assign writeRegData = MemMux;

    // Assign ALU Variables
    assign ALUInput1 = readReg1Data;
    assign ALUInput2 = ALUMux;

    // Assign PC Adder
    assign PC4 = address + 1;
    assign PCImm = address + ImmGen + 1;

    // Assign Immediate Generator
    assign ImmGen = (dataSaved[7]) ? {8'b11111111, dataSaved[7:0]} : {dataSaved[7:0]};

    // Assign Multiplexer
    assign PCSrc = (Branch & bcond) | JMP | JAL;
    assign ALUMux = (ALUSrc) ? ImmGen : readReg2Data;
    assign PCMux0 = (PCtoReg) ? PC4 : MemMux;
    assign PCMux1 = (PCSrc) ? PCImm : PC4;
    assign MemMux = (MemtoReg) ? data : ALUResult;

    // Register Module
    register R (
        .readReg1(readReg1), 
        .readReg2(readReg2), 
        .writeReg(writeReg), 
        .readReg1Data(readReg1Data), 
        .readReg2Data(readReg2Data),
        .writeRegData(writeRegData),  
        .regReadReady(regReadReady),
        .regWriteReady(regWriteReady), 
        .regReadComplete(regReadComplete),
        .regWriteComplete(regWriteComplete),
        .reset_n(reset_n)
    );

    // ALU Module
    ALU A (
        .A(ALUInput1), 
        .B(ALUInput2), 
        .C(ALUResult),
        .aluCode(aluCode), 
		.aluReady(aluReady),
		.aluComplete(aluComplete),
        .reset_n(reset_n)
    );

    // ALU Control Module
    alucontrol AC (
        .Instruction(dataSaved),
        .aluCode(aluCode),
        .reset_n(reset_n)
    );

    // Reset
    always @(negedge reset_n) begin

        // Default Output
        readM <= 0;
        writeM <= 0;
        address <= 0;

        // Memory Variables
		loadStore1 <= 1;
		loadStore2 <= 0;

        // Control Bits
        RegWrite <= 0;
        ALUSrc <= 0;
        MemtoReg <= 0;
        Branch <= 0;
        PCtoReg <= 0;
        JMP <= 0;
		JAL <= 0;
		JWrite <= 0;

        // Register Variables
		regReadReady <= 0;
		regWriteReady <= 0;

        // ALU Variables
        bcond <= 0;
		aluReady <= 0;

        // Program Counter
        PC <= 0;

    end

    // Datapath of CPU
    always @(posedge clk) begin

        // Read Instruction
        readM <= 1;
		wait (inputReady);
		readM <= 0;

        // Set Control Bit
		if ((opcode[3:2] != 0) && (opcode != 4'd8)) RegWrite <= 1;
        if ((opcode != 4'd15) && (opcode[3:2] != 0)) ALUSrc <= 1;
        if ((opcode == 4'd7)) MemtoReg <= 1;
        if ((opcode[3:2] == 0)) Branch <= 1;
		if ((opcode == 4'd9) || (opcode == 4'd10)) JMP <= 1;
		if ((opcode == 4'd15) && (dataSaved[5] == 1'b1)) JAL <= 1;
		if ((opcode == 4'd10) || ((opcode == 4'd15) && (dataSaved[5:0] == 4'd26))) JWrite <= 1;

        // Read Register
        regReadReady <= 1;
        wait (regReadComplete);
        regReadReady <= 0;

        // ALU
		aluReady <= 1;
		wait (aluComplete);
		if (Branch) begin
			if (opcode == 4'd0 && ALUResult != 0) bcond <= 1;
			if (opcode == 4'd1 && ALUResult == 0) bcond <= 1;
			if (opcode == 4'd2 && ALUResult != 0 && ALUResult[`WORD_SIZE-1] == 1) bcond <= 1;
			if (opcode == 4'd3 && ALUResult != 0 && ALUResult[`WORD_SIZE-1] == 0) bcond <= 1;
		end
		aluReady <= 0;
		wait (!aluComplete);

        // PC Save
		if (JMP | JAL) PC <= ImmGen;
		else PC <= PCMux1;

        // Set Address for Load and Store
		address <= ALUResult;
		loadStore1 <= 0;

        // negedge clk
		wait(!clk);

        // Read Memory
		if (opcode == 4'd7) begin
			readM <= 1;
			wait(inputReady);
			readM <= 0;
		end

        // Write Memory
		else if (opcode == 4'd8) begin
			loadStore2 <= 1;
			wait (data == readReg2Data);
			writeM <= 1;
			wait (ackOutput);
			writeM <= 0;
			loadStore2 <= 0;
		end
        
        // Write Register
        if ((RegWrite && !JMP && !JAL) || JWrite) begin
            regWriteReady <= 1;
            wait (regWriteComplete);
            regWriteReady <= 0;
        end

        // Set Address for new instruction
		address <= PC;

        // Reset Bits
		loadStore1 <= 1;
		loadStore2 <= 0;
        RegWrite <= 0;
        ALUSrc <= 0;
        MemtoReg <= 0;
        Branch <= 0;
        PCtoReg <= 0;
        JMP <= 0;
		JAL <= 0;
		JWrite <= 0;
		regReadReady <= 0;
		regWriteReady <= 0;
        bcond <= 0;
		aluReady <= 0;

    end

endmodule							  																		  