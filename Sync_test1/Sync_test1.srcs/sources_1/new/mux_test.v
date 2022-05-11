`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: AUToronto
// Engineer: Francisco Granda
// 
// Create Date: 01/05/2022 03:14:10 PM
// Design Name: Sync Trigger Signal Generator
// Module Name: mux_test
// Project Name: Sync Board
// Target Devices: Arty-Z7-20
// Tool Versions: Vivado 2021.2
// Description: Generation of 20 Hz (variable freq) 
// square signal for camera system.
// 
// Dependencies: DPLLv2.v
//               VCODriveFilter.v
//               divider.v
//               const.xdc
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module mux_test(input sig1,
           input sig2,
           input [1:0] sel,
           output reg sig_out

    );
    
always @(sel)begin
case (sel)
        2'b00: sig_out <= sig2;
        2'b01: sig_out <= sig1;        
    endcase

end
endmodule