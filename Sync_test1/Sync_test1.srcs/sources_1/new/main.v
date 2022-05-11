`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: AUToronto
// Engineer: Francisco Granda
// 
// Create Date: 01/05/2022 03:14:10 PM
// Design Name: Sync Trigger Signal Generator
// Module Name: main
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


module main(
    input clk_125, //125 MHz internal clock
    input PPS_in, // 1 Hz external PPS 
    input rst2, // Reset
    output reg led_test,
    output PPS_in_out,
    output trig_sig, // 20Hz trigger signal
    output reg led_PPS, // Led for Input PPS
    output reg led_PPS2, // Led for output PPS
    output reg led_lock, // Led Lock
    output trig_1,
    output trig_2,
    output trig_3,
    output trig_4,
    output trig_5,
    output trig_6,
    output trig_7,
    output trig_8    
    );
// Local Signals
wire lock;
wire out1;
wire out2;
wire PPS_out_sync;
integer start =0;
reg lock_1 = 0;
integer locked = 0;
reg rst3;
assign PPS_in_out = PPS_in;
assign trig_1 = trig_sig;
assign trig_2 = trig_sig;
assign trig_3 = trig_sig;
assign trig_4 = trig_sig;
assign trig_5 = trig_sig;
assign trig_6 = trig_sig;
assign trig_7 = trig_sig;
assign trig_8 = trig_sig;

// Launch Sequence
always @ (posedge clk_125)
begin
     if(rst2 == 0 && PPS_in == 1 && start == 0)
        begin
            start = 1;
        end
        else
        begin
             
      end
      if(start == 1)
        begin
            led_test <= 1'b1;
            rst3 <= 1'b0;
        end
        else
        begin
            led_test <= 1'b0;
            rst3 <= 1'b1;
       end
	   if(locked == 0 && lock == 1)
	       begin
	       locked = 1;
	   end
	   if(locked == 1)
	       begin
	       lock_1 <= 1;
	   end
end

// Switch case for Locked clock and internal clock
reg [1:0] select = 2'b00;
always @(posedge clk_125)
begin
    if (lock == 0)begin
        //DIV = 28'd6_250_000;
        select = 2'b00;

        end
    else if (lock == 1)begin
        //DIV = 28'd12_500_000;
        select = 2'b01;

        end
    else begin
        select = select;
    end
end
 
// DPLL SYNC MODULE
DPLL  uut (
            .Rst(rst3), 
            .Clk(clk_125), 
            .xPPS_In(PPS_in),  
            .NCO_Out(NCO_Out),
            .Lock(lock)
        );  
              
// CREATE 20 HZ SIGNAL FROM 10 MHZ NCO_Out
divider_tog  div1(
             .clock_in(NCO_Out),
             .on(lock_1),
             .clock_out(out1)
        );
        
divider_tog #(
        .DIVISOR(28'd6_250_000)

        ) div2(
             .clock_in(clk_125),
             .on(1'b1),
             .clock_out(out2)
        );
        
// CREATE 1 HZ SIGNAL
divider_tog #(
        .DIVISOR(28'd10_000_000)

        ) div_PPS_out(
             .clock_in(NCO_Out ),
             .on(lock_1),
             .clock_out(PPS_out_sync)
        );

// MUX for signal selection
mux_test mux1(
    .sig1(out1),
    .sig2(out2),
    .sel(select),
    .sig_out(trig_sig)
    
    );          
             
// Visualize input PPS signal        
always @ (posedge clk_125)
begin
    if(PPS_in == 0)
    begin
        led_PPS <= 1'b0;
    end
    else
    begin
        led_PPS <= 1'b1;
    end
end

// Visualize output PPS signal
always @ (posedge clk_125)
begin
    if(PPS_out_sync == 0)
    begin
        led_PPS2 <= 1'b0;
    end
    else
    begin
        led_PPS2 <= 1'b1;
    end
end

// Visualize Lock Status
always @ (posedge clk_125)
begin
    if(lock == 0)
    begin
        led_lock <= 1'b0;
    end
    else
    begin
        led_lock <= 1'b1;
    end
end  
endmodule
