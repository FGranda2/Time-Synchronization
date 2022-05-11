`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: AUToronto
// Engineer: Francisco Granda
// 
// Create Date: 01/05/2022 03:14:10 PM
// Design Name: Sync Trigger Signal Generator
// Module Name: divider_tog
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

module divider_tog #(
    parameter DIVISOR = 28'd500_000,
    parameter DUTY = 28'd50
    // 6250 microseconds is DUTY = 28'd8
    // 1000 microseconds is DUTY = 28'd50
    // 12500 microseconds is DUTY = 28'd4

    )(
	input wire clock_in,
	input wire on,
	output reg clock_out
);
reg[27:0] counter=28'd0;
//parameter DIVISOR = 28'd2;

integer start =0;

always @(posedge clock_in)
begin
if (on == 1)begin
     counter <= counter + 28'd1;
     if(counter>=(DIVISOR-1))
      counter <= 28'd0;
     clock_out <= (counter<DIVISOR/DUTY)?1'b1:1'b0;
    end
end

endmodule