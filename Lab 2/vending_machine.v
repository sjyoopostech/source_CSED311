// Title         : vending_machine.v
// Author      : Jae-Eon Jo (Jojaeeon@postech.ac.kr) 
//					   Dongup Kwon (nankdu7@postech.ac.kr) (2015.03.30)

`include "vending_machine_def.v"

module vending_machine (

	clk,							// Clock signal
	reset_n,						// Reset signal (active-low)
	
	i_input_coin,				// coin is inserted.
	i_select_item,				// item is selected.
	i_trigger_return,			// change-return is triggered 
	
	o_available_item,			// Sign of the item availability
	o_output_item,			// Sign of the item withdrawal
	o_return_coin				// Sign of the coin return
);

	// Ports Declaration
	// Do not modify the module interface
	input clk;
	input reset_n;
	
	input [`kNumCoins-1:0] i_input_coin;
	input [`kNumItems-1:0] i_select_item;
	input i_trigger_return;
		
	output [`kNumItems-1:0] o_available_item;
	output [`kNumItems-1:0] o_output_item;
	output [`kNumCoins-1:0] o_return_coin;
 
	// Normally, every output is register,
	//   so that it can provide stable value to the outside.
	reg [`kNumItems-1:0] o_available_item;
	reg [`kNumItems-1:0] o_output_item;
	reg [`kNumCoins-1:0] o_return_coin;
	
	// Net constant values (prefix kk & CamelCase)
	// Please refer the wikepedia webpate to know the CamelCase practive of writing.
	// http://en.wikipedia.org/wiki/CamelCase
	// Do not modify the values.
	wire [31:0] kkItemPrice [`kNumItems-1:0];	// Price of each item
	wire [31:0] kkCoinValue [`kNumCoins-1:0];	// Value of each coin
	assign kkItemPrice[0] = 400;
	assign kkItemPrice[1] = 500;
	assign kkItemPrice[2] = 1000;
	assign kkItemPrice[3] = 2000;
	assign kkCoinValue[0] = 100;
	assign kkCoinValue[1] = 500;
	assign kkCoinValue[2] = 1000;


	// NOTE: integer will never be used other than special usages.
	// Only used for loop iteration.
	// You may add more integer variables for loop iteration.
	integer i, j, k;

	// Internal states. You may add your own net & reg variables.
	reg [`kTotalBits-1:0] current_total;
	
	// Next internal states. You may add your own net and reg variables.
	reg [`kTotalBits-1:0] current_total_nxt;
	
	// Variables. You may add more your own registers.
	reg [`kTotalBits-1:0] input_total, output_total, return_total;
	reg [31:0] waitTime;

	// initiate values
	initial begin
		// TODO: initiate values

		// Set Output
		o_available_item <= 0;
		o_output_item <= 0;
		o_return_coin <= 0;

		// Set State
		current_total <= 4'b0001;
		current_total_nxt <= 4'b0001;

		// Set Variable
		input_total <= 0;
		output_total <= 0;
		return_total <= 0;

	end

	
	// Combinational logic for the next states
	always @(posedge clk) begin
		// TODO: current_total_nxt
		// You don't have to worry about concurrent activations in each input vector (or array).

		// Calculate the next current_total state.

		case (current_total)
		
			// Insert Coin & Select Item
			4'b0001 : begin

				// Waiting Time
				waitTime = waitTime + 1;
				if (waitTime > `kWaitTime || i_trigger_return) begin
					current_total_nxt = 4'b0011;
				end	
				else begin

					// Insert Coin
					case (i_input_coin)
						3'b100 : begin
							input_total = input_total + kkCoinValue[2];
							current_total_nxt = 4'b0010;
						end
						3'b010 : begin
							input_total = input_total + kkCoinValue[1];
							current_total_nxt = 4'b0010;
						end
						3'b001 : begin
							input_total = input_total + kkCoinValue[0];
							current_total_nxt = 4'b0010;
						end
	
						// Select Item
						default : begin							
							case (i_select_item)
								4'b1000 : begin
									if (input_total >= kkItemPrice[3]) begin
										input_total = input_total - kkItemPrice[3];
										output_total[3] = 1;
										current_total_nxt = 4'b0010;
									end
									else current_total_nxt = 4'b0001;
								end
								4'b0100 : begin
									if (input_total >= kkItemPrice[2]) begin
										input_total = input_total - kkItemPrice[2];
										output_total[2] = 1;
										current_total_nxt = 4'b0010;
									end
									else current_total_nxt = 4'b0001;
								end
								4'b0010 : begin
									if (input_total >= kkItemPrice[1]) begin
										input_total = input_total - kkItemPrice[1];
										output_total[1] = 1;
										current_total_nxt = 4'b0010;
									end
									else current_total_nxt = 4'b0001;
								end
								4'b0001 : begin
									if (input_total >= kkItemPrice[0]) begin
										input_total = input_total - kkItemPrice[0];
										output_total[0] = 1;
										current_total_nxt = 4'b0010;
									end
									else current_total_nxt = 4'b0001;
								end
								default : begin
									current_total_nxt = 4'b0001;
								end
							endcase
						end

					endcase

				end
			end
	
			// Reset Waiting Time
			4'b0010 : begin
				waitTime = 0;
				current_total_nxt = 4'b0001;
			end

			// Return Coin
			4'b0011 : begin
				if (input_total >= kkCoinValue[2]) begin
					input_total = input_total - kkCoinValue[2];
					return_total[2] = 1;
					current_total_nxt = 4'b0011;
				end
				if (input_total >= kkCoinValue[1]) begin
					input_total = input_total - kkCoinValue[1];
					return_total[1] = 1;
					current_total_nxt = 4'b0011;
				end
				if (input_total >= kkCoinValue[0]) begin
					input_total = input_total - kkCoinValue[0];
					return_total[0] = 1;
					current_total_nxt = 4'b0011;
				end
				if (return_total == 0) begin
					current_total_nxt = 4'b0001;
					waitTime = 0;
				end
			end

		endcase

		// You may add more next states.
	end

	
	
	// Combinational logic for the outputs
	always @(*) begin

		// TODO: o_available_item
		o_available_item = 4'b0000;
		if (input_total >= kkItemPrice[3]) o_available_item[3] = 1;
		if (input_total >= kkItemPrice[2]) o_available_item[2] = 1;
		if (input_total >= kkItemPrice[1]) o_available_item[1] = 1;
		if (input_total >= kkItemPrice[0]) o_available_item[0] = 1;

		// TODO: o_output_item
		o_output_item = output_total[`kNumItems-1:0];
		output_total = 0;

		// TODO: o_return_coin
		o_return_coin = return_total[`kNumCoins-1:0];
		return_total = 0;

	end
	
	// Sequential circuit to reset or update the states
	always @(posedge clk) begin
		if (!reset_n) begin
			// TODO: reset all states.
			// Reset Output
			o_available_item <= 0;
			o_output_item <= 0;
			o_return_coin <= 0;

			// Reset State
			current_total <= 4'b0001;
			current_total_nxt <= 4'b0001;

			// Reset Variable
			input_total <= 0;
			output_total <= 0;
			return_total <= 0;

		end
		else begin
			// TODO: update all states.
			current_total <= current_total_nxt;
			
		end
	end

endmodule
