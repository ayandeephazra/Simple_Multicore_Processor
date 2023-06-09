module alu(clk,src0,src1,shamt,func,dst,dst_EX_DM,ov,zr,neg);
///////////////////////////////////////////////////////////
// ALU.  Performs ADD, SUB, AND, NOR, SLL, SRL, or SRA  //
// based on func input.  Provides OV and ZR outputs.   //
// Arithmetic is saturating.                          //
///////////////////////////////////////////////////////
// Encoding of func[2:0] is as follows: //
// 000 ==> ADD
// 001 ==> SUB
// 010 ==> AND
// 011 ==> NOR
// 100 ==> SLL
// 101 ==> SRL
// 110 ==> SRA
// 111 ==> reserved

//////////////////////
// include defines //
////////////////////
`include "common_params.inc"

input clk;
input [15:0] src0,src1;
input [4:0] func;			// selects function to perform
input [3:0] shamt;			// shift amount

output [15:0] dst;			// ID_EX version for branch/jump targets
output reg [15:0] dst_EX_DM;
output ov,zr,neg;

wire [15:0] sum;		// output of adder
wire [15:0] sum_sat;	// saturated sum
wire [15:0] src0_2s_cmp;
wire cin;
wire [15:0] shft_l1,shft_l2,shft_l4,shft_l;		// intermediates for shift left
wire [15:0] shft_r1,shft_r2,shft_r4,shft_r;		// intermediates for shift right

/////////////////////////////////////////////////
// Implement 2s complement logic for subtract //
///////////////////////////////////////////////
assign src0_2s_cmp = (func==SUB) ? ~src0 : src0;	// use 2's comp for sub
assign cin = (func==SUB) ? 1 : 0;					// which is invert and add 1
//////////////////////
// Implement adder //
////////////////////
assign sum = src1 + src0_2s_cmp + cin;
///////////////////////////////
// Now for saturation logic //
/////////////////////////////
assign sat_neg = (src1[15] && src0_2s_cmp[15] && ~sum[15]) ? 1 : 0;
assign sat_pos = (~src1[15] && !src0_2s_cmp[15] && sum[15]) ? 1 : 0;
assign sum_sat = (sat_pos) ? 16'h7fff :
                 (sat_neg) ? 16'h8000 :
				 sum;
				 
assign ov = sat_pos | sat_neg;


///////////////////////////
// Now for signed multpl//
/////////////////////////
wire signed [7:0] smul0 = src0[7:0];
wire signed [7:0] smul1 = src1[7:0];
wire signed [15:0] smul_res;

assign smul_res = smul0 * smul1;


//////////////////////////////////
// Now for constrained u multpl//
////////////////////////////////
wire [7:0] umulc0 = src0[7:0];
wire [7:0] umulc1 = src1[7:0];
wire [15:0] umulc_res;

assign umulc_res = umulc0 * umulc1;


///////////////////////////
// Now for signed divi  //
/////////////////////////
wire [15:0] sdiv0 = src0[15:0];
wire [15:0] sdiv1 = src1[15:0];
wire [15:0] sdiv_res;
wire [15:0] sdiv_corr;


wire diff_sign;
wire [1:0] toptwo;
assign toptwo = {src0[15], src1[15]};
assign diff_sign = (toptwo == 2'b00)? 0:
					(toptwo == 2'b01)? 1:
					(toptwo == 2'b10)? 1: 0;
					//(toptwo == 2'b11)? 0;
wire [15:0] sdiv0_mod = (sdiv0[15])? ~sdiv0 + 1: sdiv0;
wire [15:0] sdiv1_mod = (sdiv1[15])? ~sdiv1 + 1: sdiv1;
assign sdiv_res = sdiv1_mod / sdiv0_mod;

assign sdiv_corr = (diff_sign)? ~sdiv_res + 1: sdiv_res;
				 
///////////////////////////
// Now for left shifter //
/////////////////////////
assign shft_l1 = (shamt[0]) ? {src1[14:0],1'b0} : src1;
assign shft_l2 = (shamt[1]) ? {shft_l1[13:0],2'b00} : shft_l1;
assign shft_l4 = (shamt[2]) ? {shft_l2[11:0],4'h0} : shft_l2;
assign shft_l = (shamt[3]) ? {shft_l4[7:0],8'h00} : shft_l4;

////////////////////////////
// Now for right shifter //
//////////////////////////
assign shft_in = (func==SRA) ? src1[15] : 0;
assign shft_r1 = (shamt[0]) ? {shft_in,src1[15:1]} : src1;
assign shft_r2 = (shamt[1]) ? {{2{shft_in}},shft_r1[15:2]} : shft_r1;
assign shft_r4 = (shamt[2]) ? {{4{shft_in}},shft_r2[15:4]} : shft_r2;
assign shft_r = (shamt[3]) ? {{8{shft_in}},shft_r4[15:8]} : shft_r4;

///////////////////////////////////////////
// Now for multiplexing function of ALU //
/////////////////////////////////////////
assign dst = (func == AND) ? src1 & src0 :
			 (func == NOR) ? ~(src1 | src0) :
			 (func == SLL) ? shft_l :
			 ((func == SRL) || (func == SRA)) ? shft_r :
			 (func == LHB) ? {src1[7:0],src0[7:0]} : 
			 (func == NAND) ? ~(src1 & src0):
			 (func == OR) ? src1 | src0:
			 (func == NOT) ? ~src0: 
			 (func == XOR) ? (src1 ^ src0):
			 (func == XNOR) ? ~(src1 ^ src0):
			 (func == UMULO) ? src0 * src1 :
			 (func == UMULC) ? umulc_res:
			 (func == SMUL) ? smul_res: 
			 (func == DIV) ? (src1 / src0) : 
			 (func == SDIV) ? sdiv_corr : sum_sat;	 
			 
assign zr = ~|dst;
assign neg = dst[15];

//////////////////////////
// Flop the ALU result //
////////////////////////
always @(posedge clk)
  dst_EX_DM <= dst;

endmodule
