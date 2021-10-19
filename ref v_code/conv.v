`timescale 1ns / 1ps
`define INPUT_M_SIZE 320
`define INPUT_K_SIZE 200
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/02 18:21:32
// Design Name: 
// Module Name: conv
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


module conv_5(
	input clk,
	input rst, 
	input conv_i_valid, 
	input [1:0] pos, 
	input [127:0] input_part_b,
	input [`INPUT_M_SIZE - 1:0] in_map, 
	input [`INPUT_K_SIZE - 1:0] k, 
	output reg conv_o_valid, 
	output reg [255:0] conv_r, 
	output reg [127:0] conv_r_add, 
	//output reg [127:0] conv_part_f, 
	output reg [127:0] conv_part_b,
	output reg [1:0] mod
    );
	reg [2:0] CS;
	reg signed [31:0] r [0:7];
	reg signed [31:0] r_add [0:3];
	reg signed [31:0] part_f [0:3];
	reg signed [31:0] part_b [0:3];
	reg [5:0] cnt_k;
	reg [3:0] cnt_r;
	reg [1:0] cnt_r_part;
	reg [5:0] cnt_data;
	reg [4:0] offset_column;
	reg [3:0] slide;
	reg [2:0] cnt_left;
	//reg [1:0] mod;                   //0:no zero padding, 1:zero padding on the left, 2:zero padding on the right, 3:zero padding on both sides
	reg [`INPUT_M_SIZE - 1:0] in_map_reg;
	reg [`INPUT_K_SIZE - 1:0] k_reg;
	reg [127:0] input_part_b_reg;
	reg signed [8:0] input_1 [0:39];
	reg signed [8:0] k_1 [0:24];
	reg signed [31:0] in_part_b [0:3];
	wire load_done;
	reg conv_done;
	integer i;

	parameter IDLE = 0;
	parameter LOAD = 1;
	parameter CONV = 2;
	parameter FIN  = 3;

	assign load_done = (cnt_data == 39) ? 1 : 0;

	// assign input_1 = in_map[63:0];
	// assign input_2 = in_map[127:64];
	// assign input_3 = in_map[191:128];
	// assign input_4 = in_map[255:192];
	// assign input_5 = in_map[319:256];
	// assign k_1 = k[39:0];
	// assign k_2 = k[79:40];
	// assign k_3 = k[119:80];
	// assign k_4 = k[159:120];
	// assign k_5 = k[199:160];
	// assign conv_r[31:0] = r[0];
	// assign conv_r[63:32] = r[1];
	// assign conv_r[95:64] = r[2];
	// assign conv_r[127:96] = r[3];
	// assign conv_r[159:128] = r[4];
	// assign conv_r[191:160] = r[5];
	// assign conv_r[223:192] = r[6];
	// assign conv_r[255:224] = r[7];
	// assign conv_r[287:256] = r[8];
	// assign conv_r[319:288] = r[9];
	// assign conv_r[351:320] = r[10];
	// assign conv_r[383:352] = r[11];

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			// reset
			CS <= 0;
		end
		else begin
			case (CS)
				IDLE:	if (conv_i_valid) begin
							CS <= LOAD;   
						end
						else begin
							CS <= IDLE;
						end

				LOAD:	if (load_done) begin
							CS <= CONV;   
						end
						else begin
							CS <= LOAD;
						end

				CONV:	if (conv_done) begin
							CS <= FIN;   
						end
						else begin
							CS <= CONV;
						end

				FIN:	if (conv_o_valid) begin
							CS <= IDLE;   
						end
						else begin
							CS <= FIN;
						end
			endcase
		end
	end

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			// reset
			cnt_k <= 0;
			mod <= 0;
			cnt_data <= 0;
			cnt_left <= 0;
			slide <= 0;
			cnt_r <= 0;
			cnt_r_part <= 0;
			conv_done <= 0;
			offset_column <= 0;
		end
		else begin
			case (CS)
				IDLE:	if (conv_i_valid) begin
							mod <= pos;
						end
						else begin
							mod <= mod;
							cnt_data <= 0;
                            cnt_k <= 0;
                            cnt_data <= 0;
                            offset_column <= 0;
                            slide <= 0;
                            cnt_left <= 0;
                            cnt_r_part <= 0;
                            cnt_r <= 0;
                            conv_done <= 0;
						end
						
						
						

				LOAD:	if (cnt_data < 39) begin
							cnt_data <= cnt_data + 1;
						end
						else begin
							cnt_data <= 0;
						end
				
				CONV:	if (mod == 1) begin
							// if (cnt_left == 0) begin
							// 	if (cnt_k == 22) begin
							// 		cnt_k <= 0;
							// 		offset_column <= 0;
							// 		slide <= slide + 1;
							// 		cnt_left <= cnt_left + 1;
							// 		cnt_r <= cnt_r + 1;
							// 	end
							// 	else if (cnt_k%5 == 2) begin
							// 		cnt_k <= cnt_k + 3;
							// 		offset_column <= offset_column + 3;
							// 	end
							// 	else begin
							// 		cnt_k <= cnt_k + 1;
							// 	end
							// end
							// else if (cnt_left == 1) begin
							// 	if (cnt_k == 23) begin
							// 		cnt_k <= 0;
							// 		offset_column <= 0;
							// 		slide <= 0;
							// 		cnt_left <= cnt_left + 1;
							// 		cnt_r <= cnt_r + 1;
							// 	end
							// 	else if (cnt_k%5 == 3) begin
							// 		cnt_k <= cnt_k + 2;
							// 		offset_column <= offset_column + 3;
							// 	end
							// 	else begin
							// 		cnt_k <= cnt_k + 1;
							// 	end
							// end
							if (cnt_left < 2) begin
								if (cnt_k == 22+cnt_left) begin
									if (cnt_left == 1) begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= 0;
										cnt_left <= cnt_left + 1;
										cnt_r <= cnt_r + 1;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_left <= cnt_left + 1;
										cnt_r <= cnt_r + 1;
									end
								end
								else if (cnt_k%5 == 2+cnt_left) begin
									cnt_k <= cnt_k + 3 - cnt_left;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else if (slide > 3) begin
								if (cnt_k == 27-slide) begin
									if (slide == 7) begin
										conv_done <= 1;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_r_part <= cnt_r_part + 1;
									end
								end
								else if (cnt_k%5 == 7-slide) begin
									cnt_k <= cnt_k + slide - 2;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else begin
								if (cnt_k == 24) begin
									cnt_k <= 0;
									offset_column <= 0;
									slide <= slide + 1;
									cnt_r <= cnt_r + 1;
								end
								else if (cnt_k%5 == 4) begin
									cnt_k <= cnt_k + 1;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
						end
						else if (mod == 2) begin
							// if (cnt_left == 0) begin
							// 	if (cnt_k == 20) begin
							// 		cnt_k <= 0;
							// 		offset_column <= 0;
							// 		slide <= slide + 1;
							// 		cnt_r_part <= cnt_r_part + 1;
							// 		cnt_left <= cnt_left + 1;
							// 	end
							// 	else begin
							// 		cnt_k <= cnt_k + 5;
							// 		offset_column <= offset_column + 3;
							// 	end
							// end
							// else if (cnt_left == 1) begin
							// 	if (cnt_k == 21) begin
							// 		cnt_k <= 0;
							// 		offset_column <= 0;
							// 		slide <= slide + 1;
							// 		cnt_r_part <= cnt_r_part + 1;
							// 		cnt_left <= cnt_left + 1;
							// 	end
							// 	else if (cnt_k%5 == 1) begin
							// 		cnt_k <= cnt_k + 4;
							// 		offset_column <= offset_column + 3;
							// 	end
							// 	else begin
							// 		cnt_k <= cnt_k + 1;
							// 	end
							// end
							// else if (cnt_left == 2) begin
							// 	if (cnt_k == 22) begin
							// 		cnt_k <= 0;
							// 		offset_column <= 0;
							// 		slide <= slide + 1;
							// 		cnt_r_part <= cnt_r_part + 1;
							// 		cnt_left <= cnt_left + 1;
							// 	end
							// 	else if (cnt_k%5 == 2) begin
							// 		cnt_k <= cnt_k + 3;
							// 		offset_column <= offset_column + 3;
							// 	end
							// 	else begin
							// 		cnt_k <= cnt_k + 1;
							// 	end
							// end
							// else if (cnt_left == 3) begin
							// 	if (cnt_k == 23) begin
							// 		cnt_k <= 0;
							// 		offset_column <= 0;
							// 		slide <= 0;
							// 		cnt_r_part <= cnt_r_part + 1;
							// 		cnt_left <= cnt_left + 1;
							// 	end
							// 	else if (cnt_k%5 == 3) begin
							// 		cnt_k <= cnt_k + 2;
							// 		offset_column <= offset_column + 3;
							// 	end
							// 	else begin
							// 		cnt_k <= cnt_k + 1;
							// 	end
							// end
							if (cnt_left < 4) begin
								if (cnt_k == 20+cnt_left) begin
									if (cnt_left == 3) begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= 0;
										cnt_left <= cnt_left + 1;
										cnt_r_part <= cnt_r_part + 1;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_left <= cnt_left + 1;
										cnt_r_part <= cnt_r_part + 1;
									end
								end
								else if (cnt_k%5 == cnt_left) begin
									cnt_k <= cnt_k + 5 - cnt_left;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else if (slide > 3) begin
								if (cnt_k == 27-slide) begin
									if (slide == 5) begin
										conv_done <= 1;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_r <= cnt_r + 1;
									end
								end
								else if (cnt_k%5 == 7-slide) begin
									cnt_k <= cnt_k + slide - 2;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else begin
								if (cnt_k == 24) begin
									cnt_k <= 0;
									offset_column <= 0;
									slide <= slide + 1;
									cnt_r <= cnt_r + 1;
								end
								else if (cnt_k%5 == 4) begin
									cnt_k <= cnt_k + 1;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
						end
						else if (mod == 3) begin
							if (cnt_left < 2) begin
								if (cnt_k == 22+cnt_left) begin
									if (cnt_left == 1) begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= 0;
										cnt_left <= cnt_left + 1;
										cnt_r <= cnt_r + 1;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_left <= cnt_left + 1;
										cnt_r <= cnt_r + 1;
									end
								end
								else if (cnt_k%5 == 2+cnt_left) begin
									cnt_k <= cnt_k + 3 - cnt_left;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else if (slide > 3) begin
								if (cnt_k == 27-slide) begin
									if (slide == 5) begin
										conv_done <= 1;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_r <= cnt_r + 1;
									end
								end
								else if (cnt_k%5 == 7-slide) begin
									cnt_k <= cnt_k + slide - 2;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else begin
								if (cnt_k == 24) begin
									cnt_k <= 0;
									offset_column <= 0;
									slide <= slide + 1;
									cnt_r <= cnt_r + 1;
								end
								else if (cnt_k%5 == 4) begin
									cnt_k <= cnt_k + 1;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
						end
						else begin
							if (cnt_left < 4) begin
								if (cnt_k == 20+cnt_left) begin
									if (cnt_left == 3) begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= 0;
										cnt_left <= cnt_left + 1;
										cnt_r_part <= 0;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_left <= cnt_left + 1;
										cnt_r_part <= cnt_r_part + 1;
									end
								end
								else if (cnt_k%5 == cnt_left) begin
									cnt_k <= cnt_k + 5 - cnt_left;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else if (slide > 3) begin
								if (cnt_k == 27-slide) begin
									if (slide == 7) begin
										conv_done <= 1;
									end
									else begin
										cnt_k <= 0;
										offset_column <= 0;
										slide <= slide + 1;
										cnt_r_part <= cnt_r_part + 1;
									end
								end
								else if (cnt_k%5 == 7-slide) begin
									cnt_k <= cnt_k + slide - 2;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
							else begin
								if (cnt_k == 24) begin
									cnt_k <= 0;
									offset_column <= 0;
									slide <= slide + 1;
									cnt_r <= cnt_r + 1;
								end
								else if (cnt_k%5 == 4) begin
									cnt_k <= cnt_k + 1;
									offset_column <= offset_column + 3;
								end
								else begin
									cnt_k <= cnt_k + 1;
								end
							end
						end

				FIN:	if (cnt_data < 2) begin
							cnt_data <= cnt_data + 1;
						end
						else begin
							cnt_data <= 0;
							mod <= 0;
							cnt_k <= 0;
							cnt_data <= 0;
							offset_column <= 0;
							slide <= 0;
							cnt_left <= 0;
							cnt_r_part <= 0;
							cnt_r <= 0;
							conv_done <= 0;
						end
			endcase
		end
	end

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			// reset
			for (i=0; i<10; i=i+1) begin
				r[i] <= 0;
			end
			for (i=0; i<4; i=i+1) begin
				part_f[i] <= 0;
				part_b[i] <= 0;
				in_part_b[i] <= 0;
			end
			for (i=0; i<40; i=i+1) begin
				input_1[i] <= 0;
			end
			for (i=0; i<25; i=i+1) begin
				k_1[i] <= 0;
			end
			in_map_reg <= 0;
			k_reg <= 0;
			conv_o_valid <= 0;
			conv_r <= 0;
			conv_r_add <= 0;
			//conv_part_f <= 0;
			conv_part_b <= 0;
		end
		else begin
			case (CS)
				IDLE:	if (conv_i_valid) begin
							in_map_reg <= in_map;
							k_reg <= k;
							input_part_b_reg <= input_part_b;
						end
						else begin
							in_map_reg <= in_map_reg;
							k_reg <= k_reg;
							input_part_b_reg <= input_part_b_reg;
							r[0] <= 0;
							r[1] <= 0;
							r[2] <= 0;
							r[3] <= 0;
							r[4] <= 0;
							r[5] <= 0;
							r[6] <= 0;
							r[7] <= 0;
							r_add[0] <= 0;
							r_add[1] <= 0;
							r_add[2] <= 0;
							r_add[3] <= 0;
							part_f[0] <= 0;
							part_f[1] <= 0;
							part_f[2] <= 0;
							part_f[3] <= 0;
							part_b[0] <= 0;
							part_b[1] <= 0;
							part_b[2] <= 0;
							part_b[3] <= 0;
						end

				LOAD:	if (cnt_data < 4) begin
							input_1[cnt_data] <= in_map_reg[319:312];
							in_map_reg <= in_map_reg << 8;
							k_1[cnt_data] <= k_reg[199:192] - 128;
							k_reg <= k_reg << 8;
							in_part_b[cnt_data] <= input_part_b_reg[127:96];
							input_part_b_reg <= input_part_b_reg << 32;
						end
						else if (cnt_data < 25) begin
							input_1[cnt_data] <= in_map_reg[319:312];
							in_map_reg <= in_map_reg << 8;
							k_1[cnt_data] <= k_reg[199:192] - 128;
							k_reg <= k_reg << 8;
						end
						else begin
							input_1[cnt_data] <= in_map_reg[319:312];
							in_map_reg <= in_map_reg << 8;
						end
				// LOAD:	begin
							// //load input
							// input_1[0] <= in_map[7:0];
							// input_1[1] <= in_map[15:8];
							// input_1[2] <= in_map[23:16];
							// input_1[3] <= in_map[31:24];
							// input_1[4] <= in_map[39:32];
							// input_1[5] <= in_map[47:40];
							// input_1[6] <= in_map[55:48];
							// input_1[7] <= in_map[63:56];

							// input_2[0] <= in_map[71:64];
							// input_2[1] <= in_map[79:72];
							// input_2[2] <= in_map[87:80];
							// input_2[3] <= in_map[95:88];
							// input_2[4] <= in_map[103:96];
							// input_2[5] <= in_map[111:104];
							// input_2[6] <= in_map[119:112];
							// input_2[7] <= in_map[127:120];

							// input_3[0] <= in_map[135:128];
							// input_3[1] <= in_map[143:136];
							// input_3[2] <= in_map[151:144];
							// input_3[3] <= in_map[159:152];
							// input_3[4] <= in_map[167:160];
							// input_3[5] <= in_map[175:168];
							// input_3[6] <= in_map[183:176];
							// input_3[7] <= in_map[191:184];

							// input_4[0] <= in_map[199:192];
							// input_4[1] <= in_map[207:200];
							// input_4[2] <= in_map[215:208];
							// input_4[3] <= in_map[223:216];
							// input_4[4] <= in_map[231:224];
							// input_4[5] <= in_map[239:232];
							// input_4[6] <= in_map[247:240];
							// input_4[7] <= in_map[255:248];

							// input_5[0] <= in_map[263:256];
							// input_5[1] <= in_map[271:264];
							// input_5[2] <= in_map[279:272];
							// input_5[3] <= in_map[287:280];
							// input_5[4] <= in_map[295:288];
							// input_5[5] <= in_map[303:296];
							// input_5[6] <= in_map[311:304];
							// input_5[7] <= in_map[319:312];
							// //load input
							// //load weight
							// k_1[0] <= k[7:0];
							// k_1[1] <= k[15:8];
							// k_1[2] <= k[23:16];
							// k_1[3] <= k[31:24];
							// k_1[4] <= k[39:32];

							// k_2[0] <= k[47:40];
							// k_2[1] <= k[55:48];
							// k_2[2] <= k[63:56];
							// k_2[3] <= k[71:64];
							// k_2[4] <= k[79:72];

							// k_3[0] <= k[87:80];
							// k_3[1] <= k[95:88];
							// k_3[2] <= k[103:96];
							// k_3[3] <= k[111:104];
							// k_3[4] <= k[119:112];

							// k_4[0] <= k[127:120];
							// k_4[1] <= k[135:128];
							// k_4[2] <= k[143:136];
							// k_4[3] <= k[151:144];
							// k_4[4] <= k[159:152];

							// k_5[0] <= k[167:160];
							// k_5[1] <= k[175:168];
							// k_5[2] <= k[183:176];
							// k_5[3] <= k[191:184];
							// k_5[4] <= k[199:192];
							// //load weight
						// end

				CONV:	if (mod == 1) begin
							if (cnt_left < 2) begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column] * k_1[cnt_k + 2 - slide]);
							end
							else if (conv_done) begin
								part_b[cnt_r_part] <= part_b[cnt_r_part];
							end
							else if (slide > 3) begin
								part_b[cnt_r_part] <= part_b[cnt_r_part] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end
							else begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end

						end
						else if (mod == 2) begin
							if (cnt_left < 4) begin
								part_f[cnt_r_part] <= part_f[cnt_r_part] + (input_1[cnt_k + offset_column] * k_1[cnt_k + 4 - slide]);
								//if (cnt_k == 20+cnt_left) begin
									//r_add[cnt_r_part] <= part_f[cnt_r_part] + in_part_b[cnt_r_part];
								//end
								//else begin
									//r_add[cnt_r_part] <= r_add[cnt_r_part];
								//end
							end
							else if (conv_done) begin
								r[cnt_r] <= r[cnt_r];
							end
							else if (slide > 3) begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end
							else begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end
						end
						else if (mod == 3) begin
							if (cnt_left < 2) begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column] * k_1[cnt_k + 2 - slide]);
							end
							else if (conv_done) begin
								r[cnt_r] <= r[cnt_r];
							end
							else if (slide > 3) begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end
							else begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end
						end
						else begin
							if (cnt_left < 4) begin
								part_f[cnt_r_part] <= part_f[cnt_r_part] + (input_1[cnt_k + offset_column] * k_1[cnt_k + 4 - slide]);
								//if (cnt_k == 20+cnt_left) begin
									//r_add[cnt_r_part] <= part_f[cnt_r_part] + in_part_b[cnt_r_part];
								//end
								//else begin
									//r_add[cnt_r_part] <= r_add[cnt_r_part];
								//end
							end
							else if (conv_done) begin
								part_b[cnt_r_part] <= part_b[cnt_r_part];
							end
							else if (slide > 3) begin
								part_b[cnt_r_part] <= part_b[cnt_r_part] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end
							else begin
								r[cnt_r] <= r[cnt_r] + (input_1[cnt_k + offset_column + slide] * k_1[cnt_k]);
							end
						end
				FIN:	if (cnt_data == 0) begin
							conv_r[255:224]      <= r[0];
							conv_r[223:192]      <= r[1];
							conv_r[191:160]      <= r[2];
							conv_r[159:128]      <= r[3];
							conv_r[127:96]       <= r[4];
							conv_r[95:64]        <= r[5];
							conv_r[63:32]        <= r[6];
							conv_r[31:0]         <= r[7];
							conv_r_add[127:96]   <= part_f[0] + in_part_b[0] ;
                            conv_r_add[95:64]    <= part_f[1] + in_part_b[1] ;
                            conv_r_add[63:32]    <= part_f[2] + in_part_b[2] ;
                            conv_r_add[31:0]     <= part_f[3] + in_part_b[3] ;
							//conv_part_f[127:96]  <= part_f[0];
							//conv_part_f[95:64]   <= part_f[1];
							//conv_part_f[63:32]   <= part_f[2];
							//conv_part_f[31:0]    <= part_f[3];
							conv_part_b[127:96]  <= part_b[0];
							conv_part_b[95:64]   <= part_b[1];
							conv_part_b[63:32]   <= part_b[2];
							conv_part_b[31:0]    <= part_b[3];
						end
						else if (cnt_data == 1) begin
							conv_o_valid <= 1;
						end
						else begin
							conv_o_valid <= 0;
						end
			endcase
		end
	end

endmodule
