`define WORD_SIZE 16
module external_device(Clk, Reset_N, Interrupt, data, signal);

    input Clk;
    input Reset_N;

    inout wire [1:0] Interrupt;
    inout wire [`WORD_SIZE*4-1:0] data;

    input wire [`WORD_SIZE-1:0] signal;

    reg [`WORD_SIZE-1:0] storage [0:11];

    reg [`WORD_SIZE-1:0] clkcounter;
    reg DMAstart;

    reg [`WORD_SIZE*4-1:0] outputdata;
    assign Interrupt = (DMAstart) ? 2'b10 : 2'bz;
    assign data = (signal == 16'hffff) ? 64'bz : outputdata;

    always @(negedge Clk) begin
        if (!Reset_N) begin
            storage[16'h0] <= 16'h0000;
            storage[16'h1] <= 16'h1111;
            storage[16'h2] <= 16'h2222;
            storage[16'h3] <= 16'h3333;
            storage[16'h4] <= 16'h4444;
            storage[16'h5] <= 16'h5555;
            storage[16'h6] <= 16'h6666;
            storage[16'h7] <= 16'h7777;
            storage[16'h8] <= 16'h8888;
            storage[16'h9] <= 16'h9999;
            storage[16'ha] <= 16'haaaa;
            storage[16'hb] <= 16'hbbbb;

            clkcounter <= 0;
            DMAstart <= 0;
            outputdata <= 0;
        end
        else begin
            clkcounter <= clkcounter + 1;
            if (clkcounter == 500 || clkcounter == 501) DMAstart <= 1;
            else DMAstart <= 0;

            if (signal != 16'hffff) outputdata <= {storage[signal+3],storage[signal+2],storage[signal+1],storage[signal]};
        end
    end
endmodule

