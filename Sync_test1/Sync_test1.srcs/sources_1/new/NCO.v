`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: AUToronto
// Engineer: Francisco Granda
// 
// Create Date: 01/05/2022 03:14:10 PM
// Design Name: Sync Trigger Signal Generator
// Module Name: VCODriveFilter
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


module NCO (Rst, Clk, CE, In, Out);
// Local Signals and parameters
parameter pWidth = 32;
parameter pAlpha = 4;
parameter pDefaultValue = 32'h5000_0000;  // 10MHz@32MHz

    input  Rst;
    input  Clk;
    input  CE;
    input  [(pWidth - 1):0] In;
    output [(pWidth - 1):0] Out;
    wire    Hold;
    wire    [(pWidth + pAlpha):0] A, B, C;
    wire    [(pWidth + pAlpha):0] Sum;
    wire    CY, OV, UV;
    wire    [(pWidth + pAlpha - 1):0] rYIn;
    reg     [(pWidth + pAlpha - 1):0] rY;

assign Hold = ~|In;
assign A = {{(pAlpha+1){In[(pWidth-1)]}}, In}; 
assign B = {rY[(pWidth+pAlpha-1)], rY};      
assign C = {{(pAlpha+1){rY[(pWidth+pAlpha-1)]}}, rY[(pWidth+pAlpha-1):pAlpha]};
assign Sum = A + B - C;
assign CY = Sum[(pWidth + pAlpha)];
assign OV = ~CY & Sum[(pWidth + pAlpha - 1)];
assign UV =  CY & Sum[(pWidth + pAlpha - 1)]; 
assign rYIn = ((UV) ? (0) : ((OV) ? ((1 << (pWidth + pAlpha - 1)) - 1)
                                  : Sum));

always @(posedge Clk)
begin
    if(Rst)
        #1 rY <= #1 {pDefaultValue, {(pAlpha){1'b0}}};
    else if(CE & ~Hold)
        #1 rY <= #1 rYIn[(pWidth + pAlpha - 1):0];
end
assign Out = rY[(pWidth + pAlpha - 1):pAlpha];
endmodule
