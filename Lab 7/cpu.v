`timescale 1ns/1ns
`define WORD_SIZE 16    // data and address word size

module cpu(Clk, Reset_N, kreadM1, kaddress1, data1, kreadM2, kwriteM2, kaddress2, data2, num_inst, output_port, is_halted, kchk1, kchk2, kchk3, BG, BR, Interrupt, length);
	input Clk;
	wire Clk;
	input Reset_N;
	wire Reset_N;

	output [`WORD_SIZE-1:0] num_inst;
	wire [`WORD_SIZE-1:0] num_inst;
	output [`WORD_SIZE-1:0] output_port;
	wire [`WORD_SIZE-1:0] output_port;
	output is_halted;
	wire is_halted;

	///////
	input wire BR;
	output reg BG;
	input wire [1:0] Interrupt;
	wire block;
	assign block = BR || (Interrupt === 2'b10);
	output wire [`WORD_SIZE-1:0] length;
	assign length = (Interrupt === 2'b10 || BR) ? 12 : 0;

	///////
	inout wire kreadM1;
	reg readM1;
	inout wire [`WORD_SIZE-1:0] kaddress1;
	wire [`WORD_SIZE-1:0] address1;
	inout wire kreadM2;
	reg readM2;
	inout wire kwriteM2;
	reg writeM2;
	inout wire [`WORD_SIZE-1:0] kaddress2;
	wire [`WORD_SIZE-1:0] address2;

	///////
	assign kreadM1 = (block) ? 1'bz : readM1;
	assign kreadM2 = (block) ? 1'bz : readM2;
	assign kwriteM2 = (block) ? 1'bz : writeM2;
	assign kaddress1 = (block) ? 16'bz : address1;
	assign kaddress2 = (block) ? ((BR) ? 16'bz : 16'hd0) : address2;

	input [`WORD_SIZE*4-1:0] data1;
	wire [`WORD_SIZE*4-1:0] data1;
	inout [`WORD_SIZE*4-1:0] data2;
	wire [`WORD_SIZE*4-1:0] data2;

	///////
	input wire kchk1;
	wire chk1;
	input wire kchk2;
	wire chk2;
	input wire kchk3;
	wire chk3;

	///////
	assign chk1 = (block) ? 1 : kchk1;
	assign chk2 = (block) ? 1 : kchk2;
	assign chk3 = (block) ? 1 : kchk3;

	wire vreadM1;
	wire vreadM2;
	wire vwriteM2;
	reg [`WORD_SIZE-1:0] vdata1;
	wire [`WORD_SIZE-1:0] vdata2;

	reg vchk1;
	reg vchk2;

	wire [12:0] tag1;
	wire [12:0] tag2;
	wire [2:0] entry1;
	wire [2:0] entry2;
	wire [1:0] bitpos1;
	wire [1:0] bitpos2;

	wire [`WORD_SIZE-1:0] data10, data11, data12, data13, data20, data21, data22, data23;

	reg [3:0] lru;							// least recently used
	reg [7:0] valid;						// is line valid
	reg [12:0] tag [7:0];					// cache tag
	reg [`WORD_SIZE-1:0] cdata [31:0];		// cache data

	reg [`WORD_SIZE-1:0] inputvdata2;
	reg [`WORD_SIZE*4-1:0] outputdata2;

	assign tag1 = address1[15:3];
	assign tag2 = address2[15:3];
	assign entry1 = address1[2];
	assign entry2 = address2[2] + 8'd2;
	assign bitpos1 = address1[1:0];
	assign bitpos2 = address2[1:0];

	assign data13 = data1[`WORD_SIZE*3+15:`WORD_SIZE*3];
	assign data12 = data1[`WORD_SIZE*2+15:`WORD_SIZE*2];
	assign data11 = data1[`WORD_SIZE+15:`WORD_SIZE];
	assign data10 = data1[15:0];
	assign data23 = data2[`WORD_SIZE*3+15:`WORD_SIZE*3];
	assign data22 = data2[`WORD_SIZE*2+15:`WORD_SIZE*2];
	assign data21 = data2[`WORD_SIZE+15:`WORD_SIZE];
	assign data20 = data2[15:0];

	///////
	assign vdata2 = (vreadM2) ? inputvdata2 : `WORD_SIZE'bz;
	assign data2 = (writeM2 && (!block)) ? outputdata2 : 64'bz;

	reg [`WORD_SIZE-1:0] hit1, hit2, access1, access2;
	reg printed;

	cpuinside c (Clk, Reset_N, vreadM1, address1, vdata1, vreadM2, vwriteM2, address2, vdata2, num_inst, output_port, is_halted, vchk1, vchk2);

	always @(negedge Clk) begin
		if (!Reset_N) begin
			lru <= 0;
			valid <= 0;
			readM1 <= 0;
			readM2 <= 0;
			writeM2 <= 0;
			vchk1 <= 1;
			vchk2 <= 1;
			vdata1 <= 0;

			tag[0] <= 0;
			tag[1] <= 0;
			tag[2] <= 0;
			tag[3] <= 0;
			tag[4] <= 0;
			tag[5] <= 0;
			tag[6] <= 0;
			tag[7] <= 0;
			
			hit1 <= 0;
			hit2 <= 0;
			access1 <= 0;
			access2 <= 0;
			printed <= 0;
		end
		else begin
			///////
			if (BR) BG <= 1;
			else BG <= 0;

			if (vreadM1) begin
				if (valid[entry1*2] && (tag1 == tag[entry1*2])) begin
					vdata1 <= cdata[entry1*8+bitpos1];
					readM1 <= 0;
					lru[entry1] <= 1;
					vchk1 <= 0;
					hit1 <= hit1 + 1;
					access1 <= access1 + 1;
				end
				else if (valid[entry1*2+1] && (tag1 == tag[entry1*2+1])) begin
					vdata1 <= cdata[entry1*8+4+bitpos1];
					readM1 <= 0;
					lru[entry1] <= 0;
					vchk1 <= 0;
					hit1 <= hit1 + 1;
					access1 <= access1 + 1;
				end
				else begin
					if (readM1 && !chk1) begin
						case (bitpos1)
							3 : vdata1 <= data13;
							2 : vdata1 <= data12;
							1 : vdata1 <= data11;
							0 : vdata1 <= data10;
						endcase
						cdata[entry1*8+lru[entry1]*4+3] <= data13;
						cdata[entry1*8+lru[entry1]*4+2] <= data12;
						cdata[entry1*8+lru[entry1]*4+1] <= data11;
						cdata[entry1*8+lru[entry1]*4] <= data10;
						valid[entry1*2+lru[entry1]] <= 1;
						tag[entry1*2+lru[entry1]] <= tag1;
						readM1 <= 0;
						vchk1 <= 0;
						lru[entry1] <= !(lru[entry1]);
						access1 <= access1 + 1;
					end
					else begin
						readM1 <= 1;
						vchk1 <= 1;
					end
				end
			end
			if (vreadM2) begin
				if (valid[entry2*2] && (tag2 == tag[entry2*2])) begin
					inputvdata2 <= cdata[entry2*8+bitpos2];
					readM2 <= 0;
					writeM2 <= 0;
					lru[entry2] <= 1;
					vchk2 <= 0;
					hit2 <= hit2 + 1;
					access2 <= access2 + 1;
				end
				else if (valid[entry2*2+1] && (tag2 == tag[entry2*2+1])) begin
					inputvdata2 <= cdata[entry2*8+4+bitpos2];
					readM2 <= 0;
					writeM2 <= 0;
					lru[entry2] <= 0;
					vchk2 <= 0;
					hit2 <= hit2 + 1;
					access2 <= access2 + 1;
				end
				else begin
					if (readM2 && !chk2) begin
						case (bitpos2)
							3 : inputvdata2 <= data23;
							2 : inputvdata2 <= data22;
							1 : inputvdata2 <= data21;
							0 : inputvdata2 <= data20;
						endcase
						cdata[entry2*8+lru[entry2]*4+3] <= data23;
						cdata[entry2*8+lru[entry2]*4+2] <= data22;
						cdata[entry2*8+lru[entry2]*4+1] <= data21;
						cdata[entry2*8+lru[entry2]*4] <= data20;
						valid[entry2*2+lru[entry2]] <= 1;
						tag[entry2*2+lru[entry2]] <= tag2;
						readM2 <= 0;
						writeM2 <= 0;
						vchk2 <= 0;
						lru[entry2] <= !(lru[entry2]);
						access2 <= access2 + 1;
					end
					else if (!chk3) begin
						if (writeM2) outputdata2 <= {cdata[entry2*8+lru[entry2]*4+3], cdata[entry2*8+lru[entry2]*4+2], cdata[entry2*8+lru[entry2]*4+1], cdata[entry2*8+lru[entry2]*4]};
						readM2 <= 1;
						writeM2 <= 0;
						vchk2 <= 1;
					end
					else begin
						readM2 <= 0;
						if (valid[entry2*2+lru[entry2]]) writeM2 <= 1;
						vchk2 <= 1;
					end
				end
			end
			if (vwriteM2) begin
				if (valid[entry2*2] && (tag2 == tag[entry2*2])) begin
					cdata[entry2*8+bitpos2] <= vdata2;
					readM2 <= 0;
					writeM2 <= 0;
					lru[entry2] <= 1;
					vchk2 <= 0;
					hit2 <= hit2 + 1;
					access2 <= access2 + 1;
				end
				else if (valid[entry2*2+1] && (tag2 == tag[entry2*2+1])) begin
					cdata[entry2*8+4+bitpos2] <= vdata2;
					readM2 <= 0;
					writeM2 <= 0;
					lru[entry2] <= 0;
					vchk2 <= 0;
					hit2 <= hit2 + 1;
					access2 <= access2 + 1;
				end
				else begin
					if (readM2 && !chk2) begin
						case (bitpos2)
							3 : begin
								cdata[entry2*8+lru[entry2]*4+3] <= vdata2;
								cdata[entry2*8+lru[entry2]*4+2] <= data22;
								cdata[entry2*8+lru[entry2]*4+1] <= data21;
								cdata[entry2*8+lru[entry2]*4] <= data20;
							end
							2 : begin
								cdata[entry2*8+lru[entry2]*4+3] <= data23;
								cdata[entry2*8+lru[entry2]*4+2] <= vdata2;
								cdata[entry2*8+lru[entry2]*4+1] <= data21;
								cdata[entry2*8+lru[entry2]*4] <= data20;
							end
							1 : begin
								cdata[entry2*8+lru[entry2]*4+3] <= data23;
								cdata[entry2*8+lru[entry2]*4+2] <= data22;
								cdata[entry2*8+lru[entry2]*4+1] <= vdata2;
								cdata[entry2*8+lru[entry2]*4] <= data20;
							end
							0 : begin
								cdata[entry2*8+lru[entry2]*4+3] <= data23;
								cdata[entry2*8+lru[entry2]*4+2] <= data22;
								cdata[entry2*8+lru[entry2]*4+1] <= data21;
								cdata[entry2*8+lru[entry2]*4] <= vdata2;
							end
						endcase
						valid[entry2*2+lru[entry2]] <= 1;
						tag[entry2*2+lru[entry2]] <= tag2;
						readM2 <= 0;
						writeM2 <= 0;
						vchk2 <= 0;
						lru[entry2] <= !(lru[entry2]);
						access2 <= access2 + 1;
					end
					else if (!chk3) begin
						if (writeM2) outputdata2 <= {cdata[entry2*8+lru[entry2]*4+3], cdata[entry2*8+lru[entry2]*4+2], cdata[entry2*8+lru[entry2]*4+1], cdata[entry2*8+lru[entry2]*4]};
						readM2 <= 1;
						writeM2 <= 0;
						vchk2 <= 1;
					end
					else begin
						readM2 <= 0;
						if (valid[entry2*2+lru[entry2]]) writeM2 <= 1;
						vchk2 <= 1;
					end
				end
			end
			if (is_halted && !printed) begin
				$display ("hit ratio #%d /%d", hit1+hit2, access1+access2);
				printed <= 1;
			end
		end
	end

endmodule
