// Edited By SeungJae Yoo (2020.04.19)
`include "opcodes.v"

module alucontrol(Instruction, aluCode, reset_n);
    input [`WORD_SIZE-1:0] Instruction; // Instruction from memory
    output reg [3:0] aluCode;           // Code of ALU

    input reset_n;                      // Reset Bit

    // Reset
    always @(negedge reset_n) begin
        aluCode <= 0;
    end

    // ALU Control Design
    always @(*)
        case (Instruction[15:12])
            `ALU_OP : begin
                if (Instruction[5:3] == 0) aluCode <= Instruction[3:0]; // ALU_OP
                else aluCode <= 4'b1010;                                // JPR_OP, JRL_OP
            end

            // Arithmetic
            `ADI_OP : aluCode <= 4'b0000;
            `ORI_OP : aluCode <= 4'b0011;
            `LHI_OP : aluCode <= 4'b1000;

            // Load and Store
            `LWD_OP : aluCode <= 4'b0000;
            `SWD_OP : aluCode <= 4'b0000;

            // Branch
            `BNE_OP : aluCode <= 4'b0001;
            `BEQ_OP : aluCode <= 4'b0001;
            `BGZ_OP : aluCode <= 4'b1001;
            `BLZ_OP : aluCode <= 4'b1001;

            // Jump
            `JMP_OP : aluCode <= 4'b1010;
            `JAL_OP : aluCode <= 4'b1010;
        endcase
endmodule