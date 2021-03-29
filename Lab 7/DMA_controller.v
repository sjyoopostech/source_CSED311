`define WORD_SIZE 16
module DMA_controller(Clk, Reset_N, BG, BR, Interrupt, address, write, chk, signal, length);

    input wire Clk;
    input wire Reset_N;

    input wire BG;
    output reg BR;
    inout wire [1:0] Interrupt;
    inout wire [`WORD_SIZE-1:0] address;
    input wire [`WORD_SIZE-1:0] length;

    inout wire write;
    reg writes;
    assign write = (BG) ? writes : 1'bz;
    input wire chk;
    output reg [`WORD_SIZE-1:0] signal;
    reg DMAstop;
    reg record;

    reg [`WORD_SIZE-1:0] outputaddr;
    assign Interrupt = (DMAstop) ? 2'b11 : 2'bz;
    assign address = (BG) ? (outputaddr + signal) : 16'bz;

    always @(negedge Clk) begin
        if (!Reset_N) begin
            BR <= 0;
            DMAstop <= 0;
            outputaddr <= 0;
            signal <= 16'hffff;
            record <= 0;
        end
        else begin
            if (length != 0 && !BR) begin
                outputaddr <= address;
                BR <= 1;
            end
            if (BG && BR) begin
                writes <= 1;
                if (signal == 16'hffff) signal <= 0;
                if (writes && !chk) begin
                    if (signal < 8) signal <= signal + 4;
                    else begin
                        BR <= 0;
                        writes <= 0;
                        signal <= 16'hffff;
                        record <= 1;
                    end
                end
            end
            if (record && !BG) begin
                DMAstop <= 1;
                record <= 0;
            end
            else DMAstop <= 0;
        end
    end
endmodule