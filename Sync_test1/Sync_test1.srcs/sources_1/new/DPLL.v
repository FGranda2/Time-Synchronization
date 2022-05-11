`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: AUToronto
// Engineer: Francisco Granda
// 
// Create Date: 01/05/2022 03:14:10 PM
// Design Name: Sync Trigger Signal Generator
// Module Name: DPLLv2
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

module DPLL #(
    parameter pPhRefCnt           = 24'd10_000_000, // #cycles in interval
    parameter pMissingPPS_Cnt     = 24'd15_000_000, // #cyles for missing PPS
    parameter pBasePhaseIncrement = 32'h147A_E148,  // 10MHz@100MHz

    parameter pRefScaleFactor = 1,                  // Frequency Scale Factor
    parameter pPosFreqPhiBase = 32'h0000_0022,     // 1 cycle, 1@100 MHz
    parameter pNegFreqPhiBase = 32'hFFFF_FFDE,     //-1 cycle, 1@100 MHz
    parameter pAlpha       = 1,                     // NCO Filter Time Constant
    parameter pErrCntrLen  = 6                      // Phase Error Counter Len
)(
    input   Rst,                // System Reset
    input   Clk,                // System Clock, DDS Reference
    output  reg DPLL_En,        // DPLL Enable - enables xPPS_Input processing
    input   xPPS_In,            // External Unsynchronized 1PPS Input
    output  xPPS_Out,           // Synchronized External 1PPS Input
    output  iPPS_Out,           // Internal 1PPS Output
    output  reg CE_NCO,         // NCO Output Clock Enable Out
    output  NCO_Out,            // NCO Output Frequency
    output  reg xPPS_TFF,       // xPPS Toggle FF output
    output  reg iPPS_TFF,       // Internal PPS Toggle FF output
    output  reg PPSGate,        // PPS Select Gate
    output  reg Lock,           // DPLL Lock Indicator

    output  reg [23:0] MissingPlsCntr,  // Missing Pulse Counter
    output  reg xPPS_Missing,           // xPPS Missing Pulse FF
    
    output  reg [23:0] iPPS_Cntr,       // Internal PPS Counter

    output  reg Up,             // Phase/Frequency Detector (PFD) Up FF
    output  reg Dn,             // PFD Dn FF
    output  reg [31:0] Err,     // PFD Phase Error Correction Value
    output  reg [31:0] PhiErr,  // PFD Phase Adjustment Value

    output  reg [(pErrCntrLen - 1):0] ErrCntr,  // Phase Error Counter
    output  reg ErrLim,         // Allowable Phase Error Limit FF
    output  reg [3:0] LockCntr, // DPLL Lock Delay Cntr
    
    output  [31:0] Kphi,        // NCO Frequency Control Word (FCW)
    output  [31:0] NCODrv,      // NCO Loop Filter Output
    output  reg [31:0] NCO      // NCO Phase Register
);
    // Local Signals
    reg     [1:0] dxPPS_In;             // xPPS_In sampled with CE10M_DDS
    reg     xPPS;                       // External synchronized 1PPS pulse

    wire    CE_DPLL_En;                 // DPLL Enable - Clock Enable

    wire    Rst_MissingPlsCntr;         // Missing Pulse Counter Control Signals
    wire    CE_MissingPlsCntr;

    wire    Rst_iPPS_Cntr;              // Reset iPPS Counter
    wire    TC_iPPS_Cntr;               // Terminal Count - iPPS Counter

    reg     iPPS;                       // iPPS pulse FF

    wire    [31:0] Sum;                 // DDS External Summer
    wire    iCE_NCO;                    // CE_NCO FF input signal
    
    wire    Rst_LockCntr;               // DPLL Lock Delay Cntr Control Signals
    wire    CE_LockCntr;
    wire    Dec_LockCntr;
    wire    TC_LockCntr;                // DPLL Lock Delay Cntr Terminal Count

always @(posedge Clk)
begin
    if(Rst)
        dxPPS_In <= #1 0;
    else if(CE_NCO)
        dxPPS_In <= #1 {dxPPS_In[0], xPPS_In};
end

// For rising edge detection
always @(posedge Clk)
begin
    if(Rst)
        xPPS <= #1 0;
    else
        xPPS <= #1 iCE_NCO & (dxPPS_In[0] & ~dxPPS_In[1]);
end

assign xPPS_Out = xPPS; 
assign CE_DPLL_En = (xPPS | xPPS_Missing | (Lock & Rst_LockCntr));

always @(posedge Clk)
begin
    if(Rst)
        DPLL_En <= #1 0;
    else if(CE_DPLL_En)
        DPLL_En <= #1 xPPS;
end

// For missing signal scenario
assign Rst_MissingPlsCntr = Rst | xPPS | xPPS_Missing;
assign CE_MissingPlsCntr  = CE_NCO & DPLL_En;

always  @(posedge Clk)
begin
    if(Rst_MissingPlsCntr)
        MissingPlsCntr <= #1 (pMissingPPS_Cnt - 1);
    else if(CE_MissingPlsCntr)
        MissingPlsCntr <= #1 MissingPlsCntr - 1;
end

always @(posedge Clk)
begin
    if(Rst)
        xPPS_Missing <= #1 0;
    else if(CE_NCO)
        xPPS_Missing <= #1 ~|MissingPlsCntr;
end

// For local 1PPS signal
assign Rst_iPPS_Cntr = (Rst | ((DPLL_En & ~PPSGate) ? CE_LockCntr : iPPS));

always @(posedge Clk)
begin
    if(Rst_iPPS_Cntr)
        iPPS_Cntr <= #1 (pPhRefCnt - 1);
    else if(CE_NCO)
        iPPS_Cntr <= #1 (iPPS_Cntr - 1);
end

assign TC_iPPS_Cntr = ~|iPPS_Cntr;

always @(posedge Clk)
begin
    if(Rst)
        iPPS <= #1 0;
    else
        iPPS <= #1 iCE_NCO & TC_iPPS_Cntr;
end

assign iPPS_Out = iPPS;

// For Phase/Freq detection stage
always @(posedge Clk)
begin
    if(Rst | ~DPLL_En)
        {Up, Dn} <= #1 {(xPPS & PPSGate), 1'b0};
    else if(DPLL_En)
        case({Up, Dn, xPPS, iPPS})
            4'b0000 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b0001 : {Up, Dn} <= #1 {1'b0, 1'b1};
            4'b0010 : {Up, Dn} <= #1 {1'b1, 1'b0};
            4'b0011 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b0100 : {Up, Dn} <= #1 {1'b0, 1'b1};
            4'b0101 : {Up, Dn} <= #1 {1'b0, 1'b1};
            4'b0110 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b0111 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b1000 : {Up, Dn} <= #1 {1'b1, 1'b0};
            4'b1001 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b1010 : {Up, Dn} <= #1 {1'b1, 1'b0};
            4'b1011 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b1100 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b1101 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b1110 : {Up, Dn} <= #1 {1'b0, 1'b0};
            4'b1111 : {Up, Dn} <= #1 {1'b0, 1'b0};
        endcase
end

assign Rst_Err = (Rst | ~DPLL_En | (xPPS & Dn) | (iPPS & Up));
//assign CE_Err  = (CE_NCO & ~ErrLim & ((xPPS | Up) | (iPPS | Dn)));
assign CE_Err  = (CE_NCO & ((xPPS | Up) | (iPPS | Dn)));
always @(posedge Clk)
begin
    if(Rst_Err)
        Err <= #1 0;
    else if(CE_Err)
        Err <= #1 Err + ((xPPS | Up) ? pPosFreqPhiBase
                                     : (iPPS | Dn) ? pNegFreqPhiBase : 0);
end

//assign CE_PhiErr = (CE_NCO & ~ErrLim & ((xPPS & Dn) | (iPPS & Up)));
assign CE_PhiErr = (CE_NCO & ((xPPS & Dn) | (iPPS & Up)));

always @(posedge Clk)
begin
    if(Rst)
        PhiErr <= #1 0;
    else if(CE_PhiErr)
        PhiErr <= #1 PhiErr + Err;
end
assign Kphi = pBasePhaseIncrement + PhiErr;
assign CE_NCODrv = CE_NCO;

// Instantiation of NCO module
NCO  #(
                    .pDefaultValue(pBasePhaseIncrement),
                    .pAlpha(pAlpha)
                ) NCODrv1 (
                    .Rst(Rst),
                    .Clk(Clk),
                    .CE(CE_NCODrv),
                    .In(Kphi),
                    .Out(NCODrv)
                );

assign Sum = NCO + NCODrv;

always @(posedge Clk)
begin
    if(Rst)
        NCO <= #1 0;
    else
        NCO <= #1 Sum;
end

assign iCE_NCO = (NCO[31] & ~Sum[31]);

always @(posedge Clk)
begin
    if(Rst)
        CE_NCO <= #1 0;
    else
        CE_NCO <= #1 iCE_NCO;
end

assign NCO_Out = ~NCO[31];   // Frequency equal to MSB of NCO Accumulator

//Lock logic
assign Rst_ErrCntr = (Rst | ~DPLL_En | (xPPS & iPPS));
assign Ld_ErrCntr  = (CE_NCO & (xPPS ^ iPPS) & (~Up & ~Dn));
//assign CE_ErrCntr  = (CE_NCO & ~ErrLim & ((~xPPS & ~iPPS) & (Dn | Up)));
assign CE_ErrCntr  = (CE_NCO & ((~xPPS & ~iPPS) & (Dn | Up)));

always @(posedge Clk)
begin
    if(Rst_ErrCntr)
        ErrCntr <= #1 0;
    else if(Ld_ErrCntr)
        ErrCntr <= #1 1;
    else if(CE_ErrCntr)
        ErrCntr <= #1 (ErrCntr + 1);
end

assign Rst_ErrLim = Rst | Ld_ErrCntr;
assign CE_ErrLim  = (Up | Dn);

always @(posedge Clk)
begin
    if(Rst_ErrLim)
        ErrLim <= #1 0;
    else if(CE_ErrLim)
        ErrLim <= #1 &ErrCntr;
end

assign Rst_LockCntr = Rst | ~DPLL_En | (|ErrCntr[(pErrCntrLen - 1):4]);
assign CE_LockCntr  = ((xPPS & Dn) | (iPPS & Up) | (xPPS & iPPS));
//assign Dec_LockCntr = ~ErrLim & ~TC_LockCntr & (~|ErrCntr[(pErrCntrLen - 1):4]);
assign Dec_LockCntr = ~TC_LockCntr & (~|ErrCntr[(pErrCntrLen - 1):4]);

always @(posedge Clk)
begin
    if(Rst_LockCntr)
        LockCntr <= #1 ~0;
    else if(CE_LockCntr)
        LockCntr <= #1 ((Dec_LockCntr) ? (LockCntr - 1) : LockCntr);
end

assign TC_LockCntr = ~|LockCntr;

always @(posedge Clk)
begin
    if(Rst_LockCntr)
        Lock <= #1 0;
    else if(CE_LockCntr)
        Lock <= #1 TC_LockCntr;
end

assign Rst_PPSGate = Rst | (xPPS & ~DPLL_En);
assign CE_PPSGate  = CE_LockCntr & TC_LockCntr;

always @(posedge Clk)
begin
    if(Rst_PPSGate)
        PPSGate <= #1 0;
    else if(CE_PPSGate)
        PPSGate <= #1 1;
end

always @(posedge Clk)
begin
    if(Rst | (xPPS & ~DPLL_En))
        xPPS_TFF <= #1 1;
    else if(xPPS & DPLL_En)
        xPPS_TFF <= #1 ~xPPS_TFF;
end

always @(posedge Clk)
begin
    if(Rst)
        iPPS_TFF <= #1 1;
    else if(iPPS_Out)
        iPPS_TFF <= #1 ~iPPS_TFF;
end
endmodule
