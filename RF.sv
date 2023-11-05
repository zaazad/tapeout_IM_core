`timescale 1ns/10ps
module RF #(
    parameter numRow = 16,
    parameter numBit = 8,
    parameter numRowAddr = 4
)
(
    input CLK,
    input CEB, //~chip enable
    input WEB,
    input [numRowAddr-1:0] A,
    input [numBit-1:0] D, 
    input [numBit-1:0] BWEB,
    output logic [numBit-1:0] Q
);

logic [numBit-1:0] mem [0:numRow-1];

always @(posedge CLK)
begin
    if(~WEB)
    begin
        mem[A] <= D[numBit-1:0];
    end
end

assign Q = mem[A];

endmodule;
