`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.02.2026 16:42:34
// Design Name: 
// Module Name: Simple_Counter_64
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Simple_Counter_64(
    input wire resetn,
    input wire enable,
    output reg [63:0] value = 64'b0,
    input wire clk
    );
    
   
    always @(posedge clk)
    begin
        if (!resetn) 
        begin
            value <= 64'b0;
        end 
        else 
            if (enable)
            begin
                value <= value + 64'b1; 
            end
    end
endmodule
