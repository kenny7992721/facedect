// ============================================================================
// Copyright (C) 2019 NARLabs TSRI. All rights reserved.
//
// Designer : Liu Yi-Jun
// Date     : 2019.10.31
// Ver      : 1.2
// Module   : yolo_core
// Func     : 
//            1.) Bypass  
//            2.) adder: incoming every two operand, output one result
//
//
// ============================================================================
`timescale 1 ns / 1 ps

module yolo_core #(
        parameter TBITS = 64 ,
        parameter TBYTE = 4
) (

        //
        input  wire [TBITS-1:0] isif_data_dout ,  // {last,user,strb,data}
        input  wire [TBYTE-1:0] isif_strb_dout ,
        input  wire [1 - 1:0]   isif_last_dout ,  // 
        input  wire [1 - 1:0]   isif_user_dout ,  // 
        input  wire             isif_empty_n ,
        output wire             isif_read ,

        //
        output wire [TBITS-1:0] osif_data_din ,
        output wire [TBYTE-1:0] osif_strb_din ,
        output wire [1 - 1:0]   osif_last_din ,
        output wire [1 - 1:0]   osif_user_din ,
        input  wire             osif_full_n ,
        output wire             osif_write ,
        
        output reg [12:0] addr_mem_1 , 
        output reg [12:0] addr_mem_2 , 
        output reg [12:0] addr_weight , 
        output reg [12:0] addr_bias ,
        
        output reg [TBITS-1:0] din_mem_1 ,
        output reg [TBITS-1:0] din_mem_2 ,
        output reg [TBITS-1:0] din_weight ,
        output reg [TBITS-1:0] din_bias ,
        
        output reg wen_mem_1 ,
        output reg wen_mem_2 ,
        output reg wen_weight ,
        output reg wen_bias ,
         
        output wire [TBITS-1:0] dout_mem_1 , 
        output wire [TBITS-1:0] dout_mem_2 , 
        output wire [TBITS-1:0] dout_weight ,
        output wire [TBITS-1:0] dout_bias ,
        
        output reg [4:0] cs,
        //
        input  wire             rst ,
        input  wire             clk
);  // filter_core
// ============================================================================
// local signal

parameter IDLE              =5'd0;
parameter OP_RD_IFMAP       =5'd1;
//CONV1
parameter OP_RD_BIAS1       =5'd2;
parameter OP_RD_WEIGHT1     =5'd3;
parameter OP_CONV1          =5'd4;
parameter OP_EP1            =5'd24; //empty state
parameter OP_MAX1           =5'd5;
//CONV2
parameter OP_RD_BIAS2       =5'd6;
parameter OP_RD_WEIGHT2	    =5'd7;
parameter OP_CONV2          =5'd8;
parameter OP_EP2            =5'd22; //empty state
parameter OP_AVER2           =5'd9;
//CONV3
parameter OP_RD_BIAS3       =5'd10;
parameter OP_RD_WEIGHT3	    =5'd11;
parameter OP_CONV3          =5'd12;
parameter OP_EP3            =5'd23; //empty state 
parameter OP_AVER3           =5'd13;
//DENSE1
parameter OP_RD_FULLY_B1    =5'd14;
parameter OP_RD_FULLY1      =5'd15;
parameter OP_FULLY1         =5'd16;
//DENSE2
parameter OP_RD_FULLY_B2    =5'd17;
parameter OP_RD_FULLY2      =5'd18;
parameter OP_FULLY2         =5'd19;

parameter OP_RD_M0          =5'd25;

parameter  OP_WB            =5'd20;
parameter  DONE             =5'd21;

wire empty_n;
reg read;

assign isif_read = read;
assign empty_n = isif_empty_n;
//assign osif_data_din = op_data;
assign osif_strb_din = 'hff;
//assign osif_last_din = last ;
assign osif_user_din = 0 ; //no sure why
//assign osif_write = write;

//-----start-----
//reg [4:0] cs,ns;
reg [4:0] ns;
reg [10:0]	read_cnt1, read_cnt2, read_cnt3,read_cnt4;
/*
reg [12:0] addr_mem_1, addr_mem_2, addr_weight, addr_bias;
reg [TBITS-1:0] din_mem_1, din_mem_2, din_weight, din_bias;
wire [TBITS-1:0] dout_mem_1, dout_mem_2, dout_weight, dout_bias;
reg wen_mem_1, wen_mem_2, wen_weight, wen_bias;
*/

reg [31:0] M0[0:4];
reg [4:0] exponent[0:4];
wire [9:0] ker_addr;
reg [6:0] ker_cnt;
wire [9:0] conv_addr, aver_addr, fully_addr;
reg [9:0] fully_we_addr;
wire [12:0] conv_o_addr,pool_addr;
wire [319:0] conv_i;
wire [199:0] ker_i;
wire [255:0] conv_o_r;
wire [127:0] conv_o_r_add,conv_i_part_b,conv_o_part_b;
wire [1:0] pos_wire;
wire [TBITS-1:0] conv_o, max_o, aver_o, fully_o;
reg  conv_i_vaild_reg;
wire [1:0] conv_mod,conv_mod_c;
wire conv_i_vaild, conv_o_vaild,conv_wr_vaild, conv_finish;
reg conv_layer_vaild;
reg max_o_valid, max_layer_vaild;
wire max_finish;
reg fully_o_vaild , fully_layer_vaild; 
wire fully_finish;

reg [3:0] wb_cnt, wb_cnt_dly1, wb_cnt_dly2, wb_cnt_dly3;
integer i;

reg [7:0] cnt_x,cnt_z,cnt_z_dly1,ker;
reg [6:0] cnt_ker_f;
reg [8:0] fully_b_addr;

//state
always @(posedge clk or posedge rst)begin
    if(rst)begin
        cs <= IDLE;
    end 
	else begin
        cs <= ns;
    end
end

//FSM
always @(*)begin
    case(cs)
		IDLE         :ns<=(empty_n) ? OP_RD_IFMAP : IDLE;
        OP_RD_IFMAP  :ns<=(read_cnt1>=383) ? OP_RD_M0 : OP_RD_IFMAP; //32*4*3
        OP_RD_M0     :ns<=(read_cnt4>=4) ? OP_RD_BIAS1 : OP_RD_M0;
        OP_RD_BIAS1  :ns<=(read_cnt2>=31) ? OP_RD_WEIGHT1 : OP_RD_BIAS1;
		OP_RD_WEIGHT1:ns<=(read_cnt3>=479) ? OP_CONV1 : OP_RD_WEIGHT1; //480?  32*5*3
		OP_CONV1	 :begin	if(conv_finish) begin			//finish CONV1(32 feature maps)
							    ns<=OP_EP1;
							end
							else begin
								ns<=OP_CONV1;
							end
					  end
		OP_EP1       :ns<=OP_MAX1;
		OP_MAX1	   	 :ns<=(max_finish) ? OP_RD_BIAS2 : OP_MAX1;		//finish MAX1(32feature maps)16/8*16*32=1024
		OP_RD_BIAS2	 :ns<=(read_cnt2>=31) ? OP_RD_WEIGHT2	: OP_RD_BIAS2;	//bias 1:32 2:32 3:64
		OP_RD_WEIGHT2:ns<=(read_cnt3>=159) ? OP_CONV2 : OP_RD_WEIGHT2;//3*3*32=288  5*32=160
		OP_CONV2	 :begin if(conv_finish) begin			//finish CONV2(32 feature maps)
							    ns<=OP_EP2;
							end
							else if(conv_layer_vaild) begin					//finish one feature map(16*16=256pixels) 32feature map
							    ns<=OP_RD_WEIGHT2;	
							end
							else begin 
							    ns<=OP_CONV2;
							end
						end
		OP_EP2		 :ns<=OP_AVER2;
		OP_AVER2	     :ns<=(max_finish) ? OP_RD_BIAS3 : OP_AVER2;		//finish AVER2(32feature maps)8*8*32=2048
		OP_RD_BIAS3	 :ns<=(read_cnt2>=63) ?	OP_RD_WEIGHT3 : OP_RD_BIAS3;	//bias 1:32 2:32 3:64
		OP_RD_WEIGHT3:ns<=(read_cnt3>=159) ? OP_CONV3 : OP_RD_WEIGHT3;//3*3*32=288
		OP_CONV3	 :begin	if(conv_finish) begin			//finish CONV3(64 feature maps)
					            ns<=OP_EP3;
							end
							else if(conv_layer_vaild)begin					//finish one feature map(8*8=64pixels)
								ns<=OP_RD_WEIGHT3;		
							end
							else begin 
								ns<=OP_CONV3;
							end
					  end	
		OP_EP3		  :ns<=OP_AVER3;
		OP_AVER3       :ns<=(max_finish) ? OP_RD_FULLY_B1 : OP_AVER3;	//finish MAX3(64feature maps)4*4*64=1024	
		OP_RD_FULLY_B1:ns<=(read_cnt2>=63) ? OP_RD_FULLY1 : OP_RD_FULLY_B1;	//bias:63
		OP_RD_FULLY1  :ns<=(read_cnt3>=127) ? OP_FULLY1 : OP_RD_FULLY1;
		OP_FULLY1	  :begin if(fully_finish) begin		//finish DENSE1(64 outputs)
						        ns<=OP_RD_FULLY_B2;
							end
							else if(fully_layer_vaild)begin				//finish one 
								ns<=OP_RD_FULLY1;		
							end
							else begin 
								ns<=OP_FULLY1;
							end
					   end
		OP_RD_FULLY_B2:ns<=(read_cnt2>=3)  ? OP_RD_FULLY2 : OP_RD_FULLY_B2;	//bias:4
		OP_RD_FULLY2  :ns<=(read_cnt3>=31) ? OP_FULLY2 : OP_RD_FULLY2;
		OP_FULLY2     :begin if(fully_finish) begin			//finish DENSE2(4 outputs)
								ns<=OP_WB;
							end
							else if(fully_layer_vaild)begin				//finish one
								ns<=OP_RD_FULLY2;		
							end
							else begin 
								ns<=OP_FULLY2;
							end
						end
		OP_WB       :ns<=(wb_cnt_dly3>=3) ? DONE : OP_WB;  //Write		
		DONE        :ns<=DONE;
        default     :ns<=IDLE;
    endcase
end

//read
always @(posedge clk or posedge rst)begin
    if(rst)begin
        read <= 0;
    end 
	else begin
		if(ns==OP_RD_IFMAP || ns==OP_RD_BIAS1 || ns==OP_RD_BIAS2 || ns==OP_RD_BIAS3 || 
		  ns==OP_RD_WEIGHT1 || ns==OP_RD_WEIGHT2 || ns==OP_RD_WEIGHT3 || 
		  ns==OP_RD_FULLY_B1 || ns==OP_RD_FULLY_B2 || ns==OP_RD_FULLY1 || ns==OP_RD_FULLY2 || ns==OP_RD_M0) begin				
			read <= 1;		//load data
        end
		else begin
            read <= 0;
        end
    end
end

//read_cnt1 for read ifmap
always@(posedge clk or posedge rst) begin
    if(rst) begin
        read_cnt1 <= 0;
    end
	else begin
        if(cs==OP_RD_IFMAP && read) begin
			read_cnt1 <= read_cnt1 + 1;		//+2cause one clk two pixels
        end
		else begin
            read_cnt1 <= 0;
        end
    end
end

//read_cnt4 for read M0
always@(posedge clk or posedge rst) begin
    if(rst) begin
        read_cnt4 <= 0;
    end
	else begin
        if(cs==OP_RD_M0 && read) begin
			read_cnt4 <= read_cnt4 + 1;		//+2cause one clk two pixels
        end
		else begin
            read_cnt4 <= 0;
        end
    end
end

//read_cnt2 for read conv_bias and dense_bias
always@(posedge clk or posedge rst) begin
    if(rst) begin
        read_cnt2 <= 0;
    end
	else begin
        if((cs==OP_RD_BIAS1 || cs==OP_RD_BIAS2 ||cs==OP_RD_BIAS3 || cs==OP_RD_FULLY_B1 || cs==OP_RD_FULLY_B2) && read) begin
			read_cnt2 <= read_cnt2 + 1;		//+2cause one clk two bias data
        end
		else begin
            read_cnt2 <= 0;
        end
    end
end

//read_cnt3 for read weight
always@(posedge clk or posedge rst) begin
    if(rst) begin
        read_cnt3 <= 0;
    end
	else begin
        if((cs==OP_RD_WEIGHT1 || cs==OP_RD_WEIGHT2 ||cs==OP_RD_WEIGHT3 || cs == OP_RD_WEIGHT3 || cs == OP_RD_WEIGHT3 || cs == OP_RD_FULLY1 || cs == OP_RD_FULLY2) && read) begin
			read_cnt3 <= read_cnt3 + 1;		//+2cause one clk two weight data
        end
		else begin
            read_cnt3 <= 0;
        end
    end
end

conv_5 conv(
.clk(clk),
.rst(rst),
.conv_i_valid(conv_i_vaild),
.pos(pos_wire),
.input_part_b(conv_i_part_b),
.in_map(conv_i),
.k(ker_i),
.conv_o_valid(conv_o_vaild),
.conv_r(conv_o_r),
.conv_r_add(conv_o_r_add),
.conv_part_b(conv_o_part_b),
.mod(conv_mod_c)
);

mem_1 memory_1(
.addra(addr_mem_1),
.clka(clk),
.dina(din_mem_1),
.douta(dout_mem_1),
.wea(wen_mem_1)
);

mem_1 memory_2(
.addra(addr_mem_2),
.clka(clk),
.dina(din_mem_2),
.douta(dout_mem_2),
.wea(wen_mem_2)
);

mem_weight memory_weight(
.addra(addr_weight),
.clka(clk),
.dina(din_weight),
.douta(dout_weight),
.wea(wen_weight)
);

mem_bias memory_bias(
.addra(addr_bias),
.clka(clk),
.dina(din_bias),
.douta(dout_bias),
.wea(wen_bias)
);

//m0
always@(posedge clk or posedge rst) begin
	if(rst) begin
		for(i=0;i<5;i=i+1) begin
			M0[i] <= 0;
			exponent[i] <= 0;
		end
	end
	else begin
		if(cs==OP_RD_M0 && read)begin
			M0[read_cnt4] <= isif_data_dout[63:32];  //here is data input
			exponent[read_cnt4] <= isif_data_dout[4:0];
		end
	end
end

//mem1 data control
always@(posedge clk or posedge rst) begin
	if(rst) begin
	    addr_mem_1 <= -1;
		din_mem_1  <= 0;
		wen_mem_1 <= 0;
	end
	else begin
		if(cs==OP_CONV1 || cs==OP_CONV2 || cs==OP_CONV3) begin    //conv write part
			if(conv_wr_vaild) begin   //right data write to mem1
				addr_mem_1	<= conv_o_addr;
				din_mem_1	<= conv_o;
				wen_mem_1	<= 1;
			end
			else begin   //wrong data
				addr_mem_1	<= addr_mem_1;
				din_mem_1	<= din_mem_1;
				wen_mem_1	<= 0;
			end
        end	
		else if(cs == OP_FULLY1) begin //dense1 write
			if( fully_o_vaild == 1) begin //right data write to mem1
				addr_mem_1	<= fully_b_addr;
				din_mem_1	<= fully_o;
				wen_mem_1	<= 1;
			end
			else begin //wrong data
				addr_mem_1	<= addr_mem_1;
				din_mem_1	<= din_mem_1;
				wen_mem_1	<= 0;
			end
        end
		else if(cs==OP_FULLY2) begin //dense1 read
			addr_mem_1	<= fully_addr;
			din_mem_1	<= 0;
			wen_mem_1	<= 0;
        end
        else if(cs==OP_RD_WEIGHT1 || cs==OP_RD_WEIGHT2 || cs==OP_RD_WEIGHT3 ||cs==OP_RD_FULLY1 ||  cs==OP_RD_FULLY2) begin //weight stay
            addr_mem_1	<= addr_mem_1;
            din_mem_1	<= din_mem_1;
            wen_mem_1	<= 0;
        end
		else if(cs==OP_MAX1 || OP_AVER2 || OP_AVER3) begin //maxpool read
			addr_mem_1	<= pool_addr;
			din_mem_1	<= 0;
			wen_mem_1	<= 0;
		end
		else begin
			addr_mem_1	<= -1;
			din_mem_1	<= 0;
			wen_mem_1	<= 0;
		end
    end
end

//mem2 data control
always@(posedge clk or posedge rst) begin
    if(rst) begin
		addr_mem_2    <=-1;
		din_mem_2     <= 0;
		wen_mem_2     <= 0;
    end
	else begin	
		if(cs==OP_RD_IFMAP && read)begin
		    addr_mem_2    <= addr_mem_2+1;
            din_mem_2     <= isif_data_dout;  //here is data input
            wen_mem_2     <= 1;
		end
		else if(cs==OP_CONV1 || cs==OP_CONV2 || cs==OP_CONV3)begin
		    addr_mem_2    <= conv_addr;
            din_mem_2     <= 0;
            wen_mem_2     <= 0;
		end
        else if(cs==OP_MAX1) begin
            if(max_o_valid) begin //write right data to mem2
                addr_mem_2    <= addr_mem_2+1;
                din_mem_2     <= max_o;
                wen_mem_2     <= 1;       
            end
            else begin //wrong data
                addr_mem_2    <= addr_mem_2;
                din_mem_2     <= din_mem_2;
                wen_mem_2     <= 0;       
            end
        end
		else if(cs==OP_AVER2 || cs==OP_AVER3) begin
            if(max_o_valid) begin //write right data to mem2
                addr_mem_2    <= addr_mem_2+1;
                din_mem_2     <= aver_o;
                wen_mem_2     <= 1;       
            end
            else begin //wrong data
                addr_mem_2    <= addr_mem_2;
                din_mem_2     <= din_mem_2;
                wen_mem_2     <= 0;       
            end
        end
		else if(cs==OP_RD_WEIGHT2 || cs==OP_RD_WEIGHT3 || cs==OP_RD_FULLY1 || cs==OP_RD_FULLY2)begin //weight stay
            addr_mem_2    <= addr_mem_2;
            din_mem_2     <= din_mem_2;
            wen_mem_2     <= 0;                      
        end
		else if(cs==OP_FULLY2)begin
			if(fully_o_vaild) begin //write right data to mem2
				addr_mem_2    <= fully_b_addr;
                din_mem_2     <= fully_o;
                wen_mem_2     <= 1; 		
			end
			else begin //wrong data
				addr_mem_2    <= addr_mem_2;
                din_mem_2     <= din_mem_2;
                wen_mem_2     <= 0;			
			end
        end
		else if(cs==OP_FULLY1)begin // read part
		    addr_mem_2    <= fully_addr;
            din_mem_2     <= 0;
            wen_mem_2     <= 0; 
        end	
		else if(cs==OP_WB)begin
		    addr_mem_2    <= wb_cnt;
            din_mem_2     <= 0;
            wen_mem_2     <= 0; 
		end	
		else begin
			addr_mem_2    <= -1;
            din_mem_2     <= 0;
            wen_mem_2     <= 0; 		
		end
    end
end

//mem3 weight
always@(posedge clk or posedge rst) begin
    if(rst) begin
		addr_weight   <= -1;
		din_weight    <= 0;
		wen_weight    <= 0;
    end
	else begin
		if((cs==OP_RD_WEIGHT1 || cs==OP_RD_WEIGHT2 || cs==OP_RD_WEIGHT3 || cs==OP_RD_FULLY1 || cs==OP_RD_FULLY2) && read)begin
			addr_weight   <= addr_weight+1;
            din_weight    <= isif_data_dout; //here is weight in
            wen_weight    <= 1;
		end
		else if(cs==OP_CONV1 || cs==OP_CONV2 || cs==OP_CONV3)begin
			if(conv_layer_vaild == 1) begin
				addr_weight <= -1;
			end
			else begin
				addr_weight   <= ker_addr;
				din_weight    <= 0;
				wen_weight    <= 0;
			end
		end
		else if(cs==OP_FULLY1 || cs==OP_FULLY2)begin
			if(fully_layer_vaild == 1) begin
				addr_weight <= -1;
			end
			else begin
				addr_weight   <= fully_we_addr;
				din_weight    <= 0;
				wen_weight    <= 0;
			end
		end		
		else begin
			addr_weight   <= -1;
            din_weight    <= 0;
            wen_weight    <= 0;		
		end
    end
end

//mem4 bias
always@(posedge clk or posedge rst) begin
    if(rst) begin
		addr_bias <= -1;
		din_bias  <= 0;
		wen_bias  <= 0;
    end
	else begin	
		if((cs==OP_RD_BIAS1 || cs==OP_RD_BIAS2 || cs==OP_RD_BIAS3 || cs==OP_RD_FULLY_B1 || cs==OP_RD_FULLY_B2) && read)begin
			addr_bias <= addr_bias+1;
            din_bias  <= isif_data_dout; //here is bias in
            wen_bias  <= 1;
		end
		else if(cs==OP_CONV1)begin
		    addr_bias <= ker;
            din_bias  <= 0;
            wen_bias  <= 0;
		end
		else if(cs==OP_CONV2 || cs==OP_CONV3)begin
		    addr_bias <= cnt_ker_f;
            din_bias  <= 0;
            wen_bias  <= 0;
		end
		else if(cs==OP_FULLY1 || cs==OP_FULLY2)begin
			addr_bias <= fully_b_addr;
            din_bias  <= 0;
            wen_bias  <= 0;
		end
		else if(cs==OP_FULLY2)begin
			addr_bias <= fully_b_addr + 64;
            din_bias  <= 0;
            wen_bias  <= 0;
		end
		else begin
			addr_bias <= -1; //-1
            din_bias  <= 0;
            wen_bias  <= 0;			
		end
    end
end

//WB
always@(posedge clk or posedge rst) begin
	if(rst) begin
		wb_cnt <= 0;
	end
	else if(cs == OP_WB)begin
		wb_cnt<= wb_cnt + 1 ;
	end
	else wb_cnt <= 0;
end
assign osif_data_din = (cs==OP_WB) ? dout_mem_2 : 0 ;
assign osif_last_din = (wb_cnt_dly3==3) ? 1 : 0;
assign osif_write = (wb_cnt_dly2>0 && wb_cnt_dly2<5) ? 1 : 0;

//wb delay
always@(posedge clk or posedge rst) begin
	if(rst) begin
		wb_cnt_dly1 <= 0;
		wb_cnt_dly2 <= 0;
		wb_cnt_dly3 <= 0;
	end
	else if(cs == OP_WB)begin
		wb_cnt_dly1 <= wb_cnt;
		wb_cnt_dly2 <= wb_cnt_dly1;
		wb_cnt_dly3 <= wb_cnt_dly2;
	end
	else begin
		wb_cnt_dly1 <= 0;
		wb_cnt_dly2 <= 0;
		wb_cnt_dly3 <= 0;
	end
end

//CONV
reg [TBITS-1:0] conv_i_data[0:4];
reg [39:0] ker_data[0:4];
reg [5:0] ker_x,ker_y,ker_z;
reg [5:0] ker_y_dly1,ker_y_dly2,ker_y_dly3;
reg [2:0] ker_shift_y,ker_shift_y_dly1,ker_shift_y_dly2,ker_shift_y_dly3;
reg [1:0] pos;
reg [1:0] pos_dly1,pos_dly2,pos_dly3;
reg conv_flag;

reg signed [31:0] conv_r1[0:31];
reg signed [31:0] conv_acc[0:31];
reg signed [31:0] conv_bias;
wire [31:0] conv_relu;
reg [63:0] conv_m0;
reg conv_ch_valid,conv_ker_valid;
reg [7:0]cnt_num;
reg ker_flag;
//conv cnt
always@(posedge clk or posedge rst) begin
	if(rst) begin
		ker_x <= 0; //0~3
		ker_y <= 0; //0~31
		ker_z <= 0; //0~2
		ker_shift_y <= 0; //0~4
		ker_cnt <= 0; // CONV1:0~31 
		ker_flag <= 0;
	end
	else if(cs == OP_CONV1) begin
	   if(conv_flag == 1) begin
	       ker_x <= ker_x; //0~3
           ker_y <= ker_y; //0~31
           ker_z <= ker_z; //0~2
           ker_shift_y <= ker_shift_y; //0~4
           ker_cnt <= ker_cnt; // CONV1:0~31
	   end
	   else if(ker_y == 31 && ker_z == 2 && ker_x == 3 && ker_shift_y == 4) begin
            ker_shift_y <= 0;
            ker_x <= 0;
            ker_z <= 0;
            ker_y <= 0;
            ker_cnt <= ker_cnt +1;
       end
	   else if(ker_z == 2 && ker_x == 3 && ker_shift_y == 4) begin
		  ker_shift_y <= 0;
	      ker_x <= 0;
		  ker_z <= 0;
		  ker_y <= ker_y+1;		 
		end
		else if(ker_x == 3 && ker_shift_y == 4) begin
		  ker_shift_y <= 0;
		  ker_x <= 0;
		  ker_z <= ker_z+1;
		end
		else if(ker_shift_y == 4) begin
		  ker_shift_y <= 0;
		  ker_x <= ker_x+1;
		end		
		else begin 
			ker_shift_y <= ker_shift_y+1;
		end
	end
	else if(cs == OP_CONV2) begin
	   if(conv_flag == 1) begin
	       ker_x <= ker_x; //0~1
           ker_y <= ker_y; //0~15
           ker_z <= ker_z; //0~31
           ker_shift_y <= ker_shift_y; //0~4
           ker_cnt <= ker_cnt; // CONV2:0~31
           ker_flag <= ker_flag;
	   end
	   else if(ker_y == 15 && ker_z == 31 && ker_x == 1 && ker_shift_y == 4) begin
            ker_shift_y <= 0;
            ker_x <= 0;
            ker_z <= 0;
            ker_y <= 0;
            ker_cnt <= ker_cnt +1;
            ker_flag <= 1;
       end
	   else if(ker_z == 31 && ker_x == 1 && ker_shift_y == 4) begin
		  ker_shift_y <= 0;
	      ker_x <= 0;
		  ker_z <= 0;
		  ker_y <= ker_y+1;		 
		end
		else if(ker_x == 1 && ker_shift_y == 4) begin
		  ker_shift_y <= 0;
		  ker_x <= 0;
		  ker_z <= ker_z+1;
		end
		else if(ker_shift_y == 4) begin
		  ker_shift_y <= 0;
		  ker_x <= ker_x+1;
		end		
		else begin 
			ker_shift_y <= ker_shift_y+1;
		end
	end
	else if(cs == OP_CONV3) begin
	   if(conv_flag == 1) begin
           ker_y <= ker_y; //0~7
           ker_z <= ker_z; //0~31
           ker_shift_y <= ker_shift_y; //0~4
           ker_cnt <= ker_cnt; // CONV3:0~63
           ker_flag <= ker_flag;
	   end
	   else if(ker_y == 7 && ker_z == 31 && ker_shift_y == 4) begin
            ker_shift_y <= 0;
            ker_z <= 0;
            ker_y <= 0;
            ker_cnt <= ker_cnt +1;
            ker_flag <= 1;
       end
	   else if(ker_z == 31 && ker_shift_y == 4) begin
		  ker_shift_y <= 0;
		  ker_z <= 0;
		  ker_y <= ker_y+1;		 
		end
		else if(ker_shift_y == 4) begin
		  ker_shift_y <= 0;
		  ker_z <= ker_z+1;
		end
		else begin 
			ker_shift_y <= ker_shift_y+1;
		end
	end
	else if(cs == OP_RD_WEIGHT2 || cs == OP_RD_WEIGHT3) begin
		ker_x <= 0;
		ker_y <= 0; 
		ker_z <= 0; 
		ker_shift_y <= 0; 
		ker_cnt <= ker_cnt; 
		ker_flag <= 0;
	end
	else begin
		ker_x <= 0; 
		ker_y <= 0; 
		ker_z <= 0; 
		ker_shift_y <= 0; 
		ker_cnt <= 0; 
		ker_flag <= 0;
	end
end

assign conv_addr = (cs==OP_CONV1) ? ker_x + (ker_y+ker_shift_y - 2)*4 + ker_z*128 : (cs==OP_CONV2) ? ker_x + (ker_y+ker_shift_y - 2)*2 + ker_z*32 : (cs==OP_CONV3) ? (ker_y+ker_shift_y - 2) + ker_z*8 : 0;
assign ker_addr = (cs==OP_CONV1) ? ker_cnt*15 + ker_z*5 + ker_shift_y : (cs==OP_CONV2 || cs==OP_CONV3) ?  ker_z*5 + ker_shift_y : 0;

//conv input data
always@(posedge clk or posedge rst) begin
	if(rst) begin
		conv_i_data[0] <= 0;
		conv_i_data[1] <= 0;
		conv_i_data[2] <= 0;
		conv_i_data[3] <= 0;
		conv_i_data[4] <= 0;
	end
	else if(cs == OP_CONV1) begin
		if( (ker_y_dly3 + ker_shift_y_dly3 )<2 || (ker_y_dly3 + ker_shift_y_dly3 )>33) begin
			conv_i_data[ker_shift_y_dly3] <= 0;
		end
		else begin
			conv_i_data[ker_shift_y_dly3] <= dout_mem_2; //data in
		end	
	end
	else if(cs == OP_CONV2) begin
		if( (ker_y_dly3 + ker_shift_y_dly3 )<2 || (ker_y_dly3 + ker_shift_y_dly3 )>17) begin
			conv_i_data[ker_shift_y_dly3] <= 0;
		end
		else begin
			conv_i_data[ker_shift_y_dly3] <= dout_mem_2; //data in
		end	
	end
	else if(cs == OP_CONV3) begin
		if( (ker_y_dly3 + ker_shift_y_dly3 )<2 || (ker_y_dly3 + ker_shift_y_dly3 )>9) begin
			conv_i_data[ker_shift_y_dly3] <= 0;
		end
		else begin
			conv_i_data[ker_shift_y_dly3] <= dout_mem_2; //data in
		end	
	end
	else begin
		conv_i_data[0] <= 0;
		conv_i_data[1] <= 0;
		conv_i_data[2] <= 0;
		conv_i_data[3] <= 0;
		conv_i_data[4] <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		conv_i_vaild_reg <= 0;
	end
	else if(cs == OP_CONV1) begin
	   if(ker_shift_y_dly3 == 4 && conv_flag == 0) begin
		  conv_i_vaild_reg <= 1;
	   end
	   else conv_i_vaild_reg <= 0;
	end
	else if(cs == OP_CONV2 || cs == OP_CONV3) begin
	   if(ker_flag == 0 && ker_shift_y_dly3 == 4 && conv_flag == 0) begin //
          conv_i_vaild_reg <= 1;
       end
       else conv_i_vaild_reg <= 0;
	end
	else conv_i_vaild_reg <= 0;
end

assign conv_i_vaild = conv_i_vaild_reg;

always@(posedge clk or posedge rst) begin
    if(rst) begin
        conv_flag <= 0;
    end
	else if(cs == OP_CONV1 || cs == OP_CONV2 || cs == OP_CONV3) begin
		if(conv_i_vaild_reg == 1) begin
			conv_flag <= 1;
		end
		else if(conv_o_vaild == 1) begin
			conv_flag <= 0;
		end
		else conv_flag <= conv_flag;
	end
	else conv_flag <= 0;
end

assign conv_i[319:256] = conv_i_data[0];
assign conv_i[255:192] = conv_i_data[1];
assign conv_i[191:128] = conv_i_data[2];
assign conv_i[127:64] = conv_i_data[3];
assign conv_i[63:0] = conv_i_data[4];

//conv input weights
always@(posedge clk or posedge rst) begin
	if(rst) begin
		ker_data[0] <= 0;
		ker_data[1] <= 0;
		ker_data[2] <= 0;
		ker_data[3] <= 0;
		ker_data[4] <= 0;
	end
	else if(cs == OP_CONV1 || cs == OP_CONV2 || cs == OP_CONV3) begin
		ker_data[ker_shift_y_dly3] <= dout_weight[63:24]; 
	end
	else begin
	    ker_data[0] <= 0;
        ker_data[1] <= 0;
        ker_data[2] <= 0;
        ker_data[3] <= 0;
        ker_data[4] <= 0;
	end
end

assign ker_i[199:160] = ker_data[0];
assign ker_i[159:120] = ker_data[1];
assign ker_i[119:80] = ker_data[2];
assign ker_i[79:40] = ker_data[3];
assign ker_i[39:0] = ker_data[4];

always@(posedge clk or posedge rst) begin
	if(rst) begin
		pos <= 0;
	end
	else if(cs == OP_CONV1) begin
		if(ker_x == 0)begin
		  pos <= 1;
		end
		else if(ker_x == 3) begin
		  pos <= 2;
		end
		else pos <= 0;
	end
	else if(cs == OP_CONV2) begin
		if(ker_x == 0)begin
		  pos <= 1;
		end
		else if(ker_x == 1) begin
		  pos <= 2;
		end
		else pos <= 0;
	end
	else if(cs == OP_CONV3) begin
		pos <= 3;
	end
	else pos <= 0;
end

assign conv_i_part_b = conv_o_part_b;

assign conv_mod = (cs== OP_CONV1 || cs== OP_CONV2 || cs== OP_CONV3) ? conv_mod_c : 0;
always@(posedge clk or posedge rst) begin
    if(rst) begin
        cnt_x <= 0; 	//0~31
		cnt_z <= 0; 	//0~2
		//cnt_ker <= 0; 	//0~31
    end
	else if(cs == OP_CONV1) begin
		if(conv_o_vaild && cnt_x==22 && cnt_z==2) begin
			cnt_x <= 0;
			cnt_z <= 0;
		end
		else if(conv_o_vaild && cnt_x==22) begin
			cnt_x <= 0;
			cnt_z <= cnt_z +1;
		end
		else if(conv_o_vaild) begin
			if(conv_mod == 1)
				cnt_x <= cnt_x+6;
			else if(conv_mod == 2)
				cnt_x <= cnt_x+10;
			else if(conv_mod == 3)
				cnt_x <= cnt_x+8;
			else cnt_x <= cnt_x+8;
		end
		else begin
			cnt_x <= cnt_x;
			cnt_z <= cnt_z;
		end
	end 
	else if(cs == OP_CONV2) begin
		if(conv_o_vaild && cnt_x==6 && cnt_z==31) begin
			cnt_x <= 0;
			cnt_z <= 0;
		end
		else if(conv_o_vaild) begin
			if(conv_mod == 1)
				cnt_x <= cnt_x+6;
			else if(conv_mod == 2) begin
				cnt_x <= 0;
				cnt_z <= cnt_z +1;
			end
			else cnt_x <= cnt_x;
		end
		else begin
			cnt_x <= cnt_x;
			cnt_z <= cnt_z;
		end
	end
	else if(cs == OP_CONV3) begin
		if(conv_o_vaild && cnt_z==31) begin
			cnt_z <= 0;
		end
		else if(conv_o_vaild) begin
			cnt_z <= cnt_z +1;
		end
		else begin
			cnt_z <= cnt_z;
		end
	end
	else begin
		cnt_x <= 0; 
	    cnt_z <= 0; 
	end
end

always@(posedge clk or posedge rst) begin
    if(rst) begin
		conv_ch_valid <= 0;
    end
	else if(cs == OP_CONV1) begin
		if(conv_o_vaild && cnt_x==22) begin
			conv_ch_valid <= 1;
		end
		else  conv_ch_valid <= 0;
	end
	else if(cs == OP_CONV2) begin
		if(conv_o_vaild && cnt_x==6) begin
			conv_ch_valid <= 1;
		end
		else  conv_ch_valid <= 0;
	end
	else if(cs == OP_CONV3) begin
		if(conv_o_vaild) begin
			conv_ch_valid <= 1;
		end
		else  conv_ch_valid <= 0;
	end
    else  conv_ch_valid <= 0;
end

always@(posedge clk or posedge rst) begin
    if(rst) begin
		conv_ker_valid <= 0;
    end
	else if(cs==OP_CONV1) begin
		if(conv_ch_valid && cnt_z_dly1==2) begin
			conv_ker_valid <= 1;
		end
		else begin
			conv_ker_valid <= 0;
		end
	end
	else if(cs==OP_CONV2) begin
		if(conv_ch_valid && cnt_z_dly1==31) begin
			conv_ker_valid <= 1;
		end
		else begin
			conv_ker_valid <= 0;
		end
	end
	else if(cs==OP_CONV3) begin
		if(conv_ch_valid && cnt_z_dly1==31) begin
			conv_ker_valid <= 1;
		end
		else begin
			conv_ker_valid <= 0;
		end
	end
	else conv_ker_valid <= 0;
end


always@(posedge clk or posedge rst) begin
    if(rst) begin
		for(i=0;i<32;i=i+1)
            conv_r1[i] <= 0;
    end
    else if(cs==OP_CONV1 || cs==OP_CONV2 || cs==OP_CONV3)begin
        if(conv_mod == 1) begin
            conv_r1[cnt_x] <= conv_o_r[255:224];
            conv_r1[cnt_x+1] <= conv_o_r[223:192];
            conv_r1[cnt_x+2] <= conv_o_r[191:160];
            conv_r1[cnt_x+3] <= conv_o_r[159:128];
            conv_r1[cnt_x+4] <= conv_o_r[127:96];
            conv_r1[cnt_x+5] <= conv_o_r[95:64];
		
        end
        else if(conv_mod == 2) begin
            conv_r1[cnt_x] <= conv_o_r_add[127:96];
            conv_r1[cnt_x+1] <= conv_o_r_add[95:64];
            conv_r1[cnt_x+2] <= conv_o_r_add[63:32];
            conv_r1[cnt_x+3] <= conv_o_r_add[31:0];
            conv_r1[cnt_x+4] <= conv_o_r[255:224];
            conv_r1[cnt_x+5] <= conv_o_r[223:192];
			conv_r1[cnt_x+6] <= conv_o_r[191:160];
			conv_r1[cnt_x+7] <= conv_o_r[159:128];
			conv_r1[cnt_x+8] <= conv_o_r[127:96];
			conv_r1[cnt_x+9] <= conv_o_r[95:64];
        end
		else if(conv_mod == 3) begin
			conv_r1[cnt_x] <= conv_o_r[255:224];
			conv_r1[cnt_x+1] <= conv_o_r[223:192];
			conv_r1[cnt_x+2] <= conv_o_r[191:160];
			conv_r1[cnt_x+3] <= conv_o_r[159:128];
			conv_r1[cnt_x+4] <= conv_o_r[127:96];
			conv_r1[cnt_x+5] <= conv_o_r[95:64];
			conv_r1[cnt_x+6] <= conv_o_r[63:32];
			conv_r1[cnt_x+7] <= conv_o_r[31:0];
		end
		else begin
			conv_r1[cnt_x] <= conv_o_r_add[127:96];
			conv_r1[cnt_x+1] <= conv_o_r_add[95:64];
			conv_r1[cnt_x+2] <= conv_o_r_add[63:32];
			conv_r1[cnt_x+3] <= conv_o_r_add[31:0];
			conv_r1[cnt_x+4] <= conv_o_r[255:224];
			conv_r1[cnt_x+5] <= conv_o_r[223:192];
			conv_r1[cnt_x+6] <= conv_o_r[191:160];
			conv_r1[cnt_x+7] <= conv_o_r[159:128];			
		end
    end
	else begin
		for(i=0;i<32;i=i+1)
            conv_r1[i] <= 0;
	end
end


//acc
always@(posedge clk or posedge rst) begin
    if(rst) begin
		for(i=0;i<32;i=i+1)
            conv_acc[i] <= 0;
    end
	else if(cs == OP_CONV1) begin
		if(conv_ch_valid) begin
			if(cnt_z_dly1 == 0) begin
				for(i=0;i<32;i=i+1)
					conv_acc[i] <= conv_r1[i];	
			end
			else begin
				for(i=0;i<32;i=i+1)
					conv_acc[i] <= conv_acc[i] + conv_r1[i];		
			end
		end
		else begin
			for(i=0;i<32;i=i+1)
				conv_acc[i] <= conv_acc[i];
		end
	end
	else if(cs == OP_CONV2) begin
		if(conv_ch_valid) begin
			if(cnt_z_dly1 == 0) begin
				for(i=0;i<16;i=i+1)
					conv_acc[i] <= conv_r1[i];	
			end
			else begin
				for(i=0;i<16;i=i+1)
					conv_acc[i] <= conv_acc[i] + conv_r1[i];		
			end
		end
		else begin
			for(i=0;i<16;i=i+1)
				conv_acc[i] <= conv_acc[i];
		end
	end
	else if(cs == OP_CONV3) begin
		if(conv_ch_valid) begin
			if(cnt_z_dly1 == 0) begin
				for(i=0;i<8;i=i+1)
					conv_acc[i] <= conv_r1[i];	
			end
			else begin
				for(i=0;i<8;i=i+1)
					conv_acc[i] <= conv_acc[i] + conv_r1[i];		
			end
		end
		else begin
			for(i=0;i<8;i=i+1)
				conv_acc[i] <= conv_acc[i];
		end
	end
	else begin
		for(i=0;i<32;i=i+1)
            conv_acc[i] <= 0;
	end
end

//
reg [7:0] cnt32,cnt32_dly1,cnt32_dly2,cnt32_dly3,cnt32_y;
reg conv_32to8_valid,conv_32to8_valid_dly1,conv_32to8_valid_dly2,conv_32to8_valid_dly3;

always@(posedge clk or posedge rst) begin
    if(rst) begin
		cnt32 <= 0;
		cnt_num <= 0;
		cnt32_y <= -1;
		ker <= 0;
    end
	else if(cs == OP_CONV1) begin
		if(conv_ker_valid && cnt32_y == 31) begin
			cnt_num <= 35;
			cnt32_y <= 0;
			ker <= ker+1;
		end
		else if(conv_ker_valid) begin
			cnt_num <= 35;
			cnt32_y <= cnt32_y +1;
		end
		else if(cnt_num == 0) begin
			cnt32 <= 0;
		end
		else begin 
			cnt32 <= cnt32 + 1;
			cnt_num <= cnt_num - 1;
		end
	end
	else if(cs == OP_CONV2) begin
		if(conv_ker_valid && cnt32_y == 15) begin
	    	cnt_num <= 19;
	    	cnt32_y <= 0;
	    	ker <= ker+1;
	    end
	    else if(conv_ker_valid) begin
	    	cnt_num <= 19;
	    	cnt32_y <= cnt32_y +1;
	    end
	    else if(cnt_num == 0) begin
	    	cnt32 <= 0;
	    end
	    else begin 
	    	cnt32 <= cnt32 + 1;
	    	cnt_num <= cnt_num - 1;
		end 
	end
	else if(cs == OP_CONV3) begin
		if(conv_ker_valid && cnt32_y == 7) begin
	    	cnt_num <= 11;
	    	cnt32_y <= 0;
	    	ker <= ker+1;
	    end
	    else if(conv_ker_valid) begin
	    	cnt_num <= 11;
	    	cnt32_y <= cnt32_y +1;
	    end
	    else if(cnt_num == 0) begin
	    	cnt32 <= 0;
	    end
	    else begin 
	    	cnt32 <= cnt32 + 1;
	    	cnt_num <= cnt_num - 1;
		end 
	end
	else if(cs == OP_RD_WEIGHT2 || cs == OP_RD_WEIGHT3) begin
		cnt32 <= 0;
		cnt_num <= 0;
		cnt32_y <= -1;
		ker <= ker;
	end
	else begin
		cnt32 <= 0;
		cnt_num <= 0;
		cnt32_y <= -1;
		ker <= 0;
	end
end



always@(posedge clk or posedge rst) begin
    if(rst) begin
        conv_32to8_valid <= 0;
    end
	else if(cs == OP_CONV1) begin
		if(cnt_num>0 && cnt_num<33) begin
			conv_32to8_valid <= 1;
		end
		else conv_32to8_valid <= 0;
	end
	else if(cs == OP_CONV2) begin
		if(cnt_num>0 && cnt_num<17) begin
			conv_32to8_valid <= 1;
		end
		else conv_32to8_valid <= 0;
	end
	else if(cs == OP_CONV3) begin
		if(cnt_num>0 && cnt_num<9) begin
			conv_32to8_valid <= 1;
		end
		else conv_32to8_valid <= 0;
	end
	else conv_32to8_valid <= 0;
end

always@(posedge clk or posedge rst) begin
    if(rst) begin
        conv_bias <= 0;
    end
	else if(cs == OP_CONV1) begin
		if(cnt_num>0 && cnt_num<33) begin
			conv_bias <= conv_acc[cnt32_dly3] + dout_bias;
		end
		else conv_bias <= 0;
	end
	else if(cs == OP_CONV2) begin
		if(cnt_num>0 && cnt_num<17) begin
			conv_bias <= conv_acc[cnt32_dly3] + dout_bias;
		end
		else conv_bias <= 0;
	end
	else if(cs == OP_CONV3) begin
		if(cnt_num>0 && cnt_num<9) begin
			conv_bias <= conv_acc[cnt32_dly3] + dout_bias;
		end
		else conv_bias <= 0;
	end
	else conv_bias <= 0;
end

assign conv_relu = conv_bias[31] ? 0 : conv_bias ;

//mul m0
always@(posedge clk or posedge rst) begin
    if(rst) begin
        conv_m0 <= 0;
    end
	else if(cs == OP_CONV1) begin
		conv_m0 <= conv_relu * M0[0];
	end
	else if(cs == OP_CONV2) begin
		conv_m0 <= conv_relu * M0[1];
	end
	else if(cs == OP_CONV3) begin
		conv_m0 <= conv_relu * M0[2];
	end
	else conv_m0 <= 0;
end

//32to8

wire [63:0] Img1;
wire [31:0] remainder;
reg [7:0]exp;
reg [10:0]outputImg_reg;
wire [7:0] outputImg;
reg [63:0] outputImg_64;
reg [63:0] outputImg_conv;
wire [3:0] cnt8;
reg [3:0] cnt8_dly1;
reg signed [8:0] cnt_pixel;


always@(*) begin
    case(cs)
		OP_CONV1 : exp <= exponent[0];
		OP_CONV2 : exp <= exponent[1];
		OP_CONV3 : exp <= exponent[2];
		OP_FULLY1 : exp <= exponent[3];
		OP_FULLY2 : exp <= exponent[4];	
		default : exp <= 0;
	endcase
end
//assign exp = (cs== OP_CONV1) ? exponent[0] : (cs==OP_CONV2)
assign Img1 = (conv_m0[30])? conv_m0[63:31] +1 : conv_m0[63:31] ;
assign remainder = Img1 & ((1<<exp)-1);

always@(posedge clk, posedge rst) begin
    if(rst) begin
        outputImg_reg <= 0;
    end
    else if (remainder[exp-1]) begin
        outputImg_reg <=  (Img1>>exp) +1;
    end
    else outputImg_reg <= (Img1>>exp);
end
assign outputImg = (outputImg_reg>255) ? 255 : outputImg_reg ;
assign cnt8 = (cnt32_dly3 - 3)%8;

always@(posedge clk, posedge rst) begin
    if(rst) begin
        outputImg_64 <= 0;
    end
	else if(conv_32to8_valid_dly2 && cnt8==0 ) begin
		outputImg_64[7:0] <= outputImg;
	end
	else if(conv_32to8_valid_dly2) begin
		outputImg_64 <= outputImg_64<<8;
		outputImg_64[7:0] <= outputImg;
	end
	else outputImg_64 <= 0;
end

always@(posedge clk, posedge rst) begin
    if(rst) begin
        cnt_pixel <= -1;
		cnt_ker_f<= 0;
    end
	else if(cs == OP_CONV1) begin
		if(conv_32to8_valid_dly3 && cnt_pixel==127 && cnt8_dly1==7) begin
			cnt_pixel <= 0;
			cnt_ker_f <= cnt_ker_f+1;
		end
		else if(conv_32to8_valid_dly3 && cnt8_dly1==7) begin
			cnt_pixel <= cnt_pixel + 1;
		end
		else cnt_pixel <= cnt_pixel;
	end
	else if(cs == OP_CONV2 || cs == OP_CONV3) begin
		//if(cnt_pixel==31 && cnt8_dly1==0) begin
		//	cnt_ker_f <= cnt_ker_f+1;
		//end
		if(conv_layer_vaild) begin
			cnt_ker_f <= cnt_ker_f+1;
		end
		else if(conv_32to8_valid_dly3 && cnt8_dly1==7) begin
			cnt_pixel <= cnt_pixel + 1;
		end
		else cnt_pixel <= cnt_pixel;
	end
	else if(cs == OP_RD_WEIGHT2 || cs == OP_RD_WEIGHT3) begin
		cnt_pixel <= -1;
		cnt_ker_f<= cnt_ker_f;
	end
	else begin
		cnt_pixel <= -1;
	    cnt_ker_f<= 0;
	end
end

always@(posedge clk, posedge rst) begin
    if(rst) begin
		conv_layer_vaild <= 0;
	end
	else if(cs == OP_CONV2) begin
		if(cnt_pixel==31) begin
			conv_layer_vaild <= 1;
		end
		else conv_layer_vaild <= 0;
	end
	else if(cs == OP_CONV3) begin
		if(cnt_pixel==7) begin
			conv_layer_vaild <= 1;
		end
		else conv_layer_vaild <= 0;
	end
	else conv_layer_vaild <= 0;
end


always@(posedge clk, posedge rst) begin
    if(rst) begin
        outputImg_conv <= 0;
    end
	else if(conv_32to8_valid_dly3 && cnt8_dly1==7) begin
		outputImg_conv <= outputImg_64;
	end
	else outputImg_conv <= outputImg_conv;
end


assign conv_o_addr = (cs==OP_CONV1) ? cnt_ker_f*128 + cnt_pixel : (cs==OP_CONV2) ? cnt_ker_f*32 + cnt_pixel : (cs==OP_CONV3) ? cnt_ker_f*8 + cnt_pixel : 0;
assign conv_o = outputImg_conv;
assign conv_wr_vaild = ( cnt_pixel >= 0) ? 1 : 0;
assign conv_finish = (cs == OP_CONV1) ? ( (conv_o_addr==4095) ? 1:0 ) : (cs==OP_CONV2) ?  ((conv_layer_vaild && conv_o_addr==1023) ? 1: 0) : (cs==OP_CONV3) ? ((conv_layer_vaild && conv_o_addr==511) ? 1 : 0) : 0;

//conv delay
always@(posedge clk or posedge rst) begin
	if(rst) begin
		ker_shift_y_dly1 <= 0;
		ker_shift_y_dly2 <= 0;
		ker_shift_y_dly3 <= 0;
		ker_y_dly1 <= 0;
		ker_y_dly2 <= 0;
		ker_y_dly3 <= 0;
		pos_dly1 <= 0;
		pos_dly2 <= 0;
		pos_dly3 <= 0;
		cnt_z_dly1 <= 0; 
		cnt32_dly1 <= 0;
		cnt32_dly2 <= 0;
		cnt32_dly3 <= 0;
		conv_32to8_valid_dly1 <= 0;
		conv_32to8_valid_dly2 <= 0;
		conv_32to8_valid_dly3 <= 0;
		cnt8_dly1 <= 0;
	end
	else begin
		ker_shift_y_dly1 <= ker_shift_y;
        ker_shift_y_dly2 <= ker_shift_y_dly1;
        ker_shift_y_dly3 <= ker_shift_y_dly2;
        ker_y_dly1 <= ker_y;
        ker_y_dly2 <= ker_y_dly1;
        ker_y_dly3 <= ker_y_dly2;
        pos_dly1 <= pos;
        pos_dly2 <= pos_dly1;
        pos_dly3 <= pos_dly2;
        cnt_z_dly1 <= cnt_z;
		cnt32_dly1 <= cnt32;
		cnt32_dly2 <= cnt32_dly1;
		cnt32_dly3 <= cnt32_dly2;
		conv_32to8_valid_dly1 <= conv_32to8_valid;
		conv_32to8_valid_dly2 <= conv_32to8_valid_dly1;
		conv_32to8_valid_dly3 <= conv_32to8_valid_dly2;
		cnt8_dly1 <= cnt8;
	end
end
assign pos_wire = pos_dly3;



//MAX_POOLING

reg [5:0] pool_x,pool_y;
reg [6:0] pool_z;
reg [1:0] pool_shift_y,pool_shift_y_dly1,pool_shift_y_dly2,pool_shift_y_dly3;
reg [TBITS-1:0]pool_i_data[0:1];
wire [TBITS-1:0]pool_i_data_wire[0:1];
reg pool_flag,pool_i_valid,pool_pixel_valid,pool_i_flag,pool_pixel_valid_dly1,pool_o_flag;
reg [7:0] pool_0,pool_1,pool_2,pool_3;
wire [9:0] aver_add;
wire [7:0] pool_result_1,pool_result_2;
reg [2:0] pool_cnt4,pool_cnt4_dly1;
reg [63:0] max_result,aver_result;

always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_shift_y <= 0;
		pool_x <= 0;
		pool_y <= 0;
		pool_z <= 0;
		
	end
	else if(cs == OP_MAX1) begin
		if(pool_flag==1) begin
			pool_shift_y <= pool_shift_y;
			pool_x <= pool_x;
			pool_y <= pool_y;
			pool_z <= pool_z;
		end
		else if(pool_y==30 && pool_x==3 && pool_shift_y == 1) begin
			pool_shift_y <= 0;
			pool_x <= -1;
			pool_y <= 0;
			pool_z <= pool_z +1;
		end
		else if(pool_x == 3 && pool_shift_y == 1) begin
			pool_shift_y <= 0;
			pool_x <= -1;
			pool_y <= pool_y + 2;
		end
		else if(pool_pixel_valid_dly1) begin
			pool_x <= pool_x + 1;
		end
		else if(pool_shift_y == 1)begin
			pool_shift_y <= 0;
		end
		else begin
			pool_shift_y <= 1;
		end
	end
	else if(cs == OP_AVER2) begin
		if(pool_flag==1) begin
			pool_shift_y <= pool_shift_y;
			pool_x <= pool_x;
			pool_y <= pool_y;
			pool_z <= pool_z;
		end
		else if(pool_y==14 && pool_x==1 && pool_shift_y == 1) begin
			pool_shift_y <= 0;
			pool_x <= -1;
			pool_y <= 0;
			pool_z <= pool_z +1;
		end
		else if(pool_x == 1 && pool_shift_y == 1) begin
			pool_shift_y <= 0;
			pool_x <= -1;
			pool_y <= pool_y + 2;
		end
		else if(pool_pixel_valid_dly1) begin
			pool_x <= pool_x + 1;
		end
		else if(pool_shift_y == 1)begin
			pool_shift_y <= 0;
		end
		else begin
			pool_shift_y <= 1;
		end
	end
	else if(cs == OP_AVER3) begin
		if(pool_flag==1) begin
			pool_shift_y <= pool_shift_y;
			pool_y <= pool_y;
			pool_z <= pool_z;
		end
		else if(pool_y==6 && pool_shift_y == 1) begin
			pool_shift_y <= 0;
			pool_y <= -2;
			pool_z <= pool_z +1;
		end
		else if(pool_pixel_valid_dly1) begin
			pool_shift_y <= 0;
			pool_y <= pool_y + 2;
		end
		else if(pool_shift_y == 1)begin
			pool_shift_y <= 0;
		end
		else begin
			pool_shift_y <= 1;
		end
	end
	else begin
		pool_shift_y <= 0;
		pool_x <= 0;
		pool_y <= 0;
		pool_z <= 0;
	end
end

assign pool_addr = (cs == OP_MAX1)? pool_x + (pool_y + pool_shift_y)*4 + pool_z*128 : (cs == OP_AVER2) ? pool_x + (pool_y + pool_shift_y)*2 + pool_z*32: (cs == OP_AVER3) ? pool_y + pool_shift_y + pool_z*8 : 0;
assign max_finish = (cs == OP_MAX1 || cs == OP_AVER2) ? ((max_o_valid && pool_z==32)? 1 : 0) : ((cs == OP_AVER3) ? ((max_o_valid && pool_z==64) ? 1 : 0) : 0);

always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_i_data[0] <= 0;
		pool_i_data[1] <= 0;
	end
	else if(cs == OP_MAX1 || cs == OP_AVER2 || cs == OP_AVER3) begin
		pool_i_data[pool_shift_y_dly3] <= dout_mem_1; //data in
	end
end

assign pool_i_data_wire[0] = pool_i_valid ? pool_i_data[0] : pool_i_data_wire[0];
assign pool_i_data_wire[1] = pool_i_valid ? pool_i_data[1] : pool_i_data_wire[1];

always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_i_valid <= 0;
	end
	else if(pool_shift_y_dly3)begin
		pool_i_valid <= 1;
	end
	else pool_i_valid <= 0;
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_flag <= 0;
	end
	else if(pool_pixel_valid) begin
		pool_flag <= 0;
	end
	else if(pool_shift_y)begin
		pool_flag <= 1;
	end
	else pool_flag <= pool_flag;
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_i_flag <= 0;
	end
	else if(pool_shift_y_dly3)begin
		pool_i_flag <= 1;
	end
	else if(pool_cnt4==3) begin
		pool_i_flag <= 0;
	end
	else pool_i_flag <= pool_i_flag;
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_0 <= 0;
		pool_1 <= 0;
		pool_2 <= 0;
		pool_3 <= 0;
	end
	else if(pool_i_flag && pool_cnt4==0)begin
		pool_0 <= pool_i_data_wire[0][63:56];
		pool_1 <= pool_i_data_wire[0][55:48];
		pool_2 <= pool_i_data_wire[1][63:56];
		pool_3 <= pool_i_data_wire[1][55:48];
	end
	else if(pool_i_flag && pool_cnt4==1)begin
		pool_0 <= pool_i_data_wire[0][47:40];
		pool_1 <= pool_i_data_wire[0][39:32];
		pool_2 <= pool_i_data_wire[1][47:40];
		pool_3 <= pool_i_data_wire[1][39:32];
	end
	else if(pool_i_flag && pool_cnt4==2)begin
		pool_0 <= pool_i_data_wire[0][31:24];
		pool_1 <= pool_i_data_wire[0][23:16];
		pool_2 <= pool_i_data_wire[1][31:24];
		pool_3 <= pool_i_data_wire[1][23:16];
	end
	else if(pool_i_flag && pool_cnt4==3)begin
		pool_0 <= pool_i_data_wire[0][15:8];
		pool_1 <= pool_i_data_wire[0][7:0];
		pool_2 <= pool_i_data_wire[1][15:8];
		pool_3 <= pool_i_data_wire[1][7:0];
	end
	else begin
		pool_0 <= 0;
		pool_1 <= 0;
		pool_2 <= 0;
		pool_3 <= 0;
	end 
end     

assign pool_result_1 = ((pool_0>=pool_1)&&(pool_0>=pool_2)&&(pool_0>=pool_3))?pool_0 : ((pool_1>=pool_0)&&(pool_1>=pool_2)&&(pool_1>=pool_3))?pool_1 : ((pool_2>=pool_0)&&(pool_2>=pool_1)&&(pool_2>=pool_3))?pool_2 : pool_3;
assign aver_add = ((pool_0 + pool_1 + pool_2 + pool_3) << 1 )/4 ;
assign pool_result_2 = (aver_add[0]) ? (aver_add >> 1)+1 : (aver_add >> 1) ;
  
always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_cnt4 <= 0;
		pool_pixel_valid <= 0;
	end
	else if(pool_i_flag && pool_cnt4==3) begin
		pool_cnt4 <= 0;
		pool_pixel_valid <= 1;
	end
	else if(pool_i_flag) begin
		pool_cnt4 <= pool_cnt4 +1;
		pool_pixel_valid <= 0;
	end
	else begin
		pool_cnt4 <= 0;
		pool_pixel_valid <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		max_result <= 0;
		aver_result <= 0;
	end
	else if(cs == OP_MAX1) begin
		if(pool_o_flag)begin
			max_result <= max_result<<8 ;
			max_result[7:0] <= pool_result_1 ;
		end
		else if(max_o_valid)begin
			max_result <= 0;
		end
		else max_result <= max_result;
	end
	else if(cs == OP_AVER2 || cs == OP_AVER3) begin
		if(pool_o_flag)begin
			aver_result <= aver_result<<8 ;
			aver_result[7:0] <= pool_result_2 ;
		end
		else if(max_o_valid)begin
			aver_result <= 0;
		end
		else aver_result <= aver_result;
	end
	else begin
		max_result <= 0;
		aver_result <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		max_o_valid <= 0;
	end
	else if( cs == OP_MAX1 || cs == OP_AVER2) begin
		if(pool_pixel_valid && pool_x%2 ) begin
			max_o_valid <= 1;
		end
		else max_o_valid <= 0;
	end
	else if (cs == OP_AVER3) begin
		if(pool_pixel_valid) begin
			max_o_valid <= 1;
		end
		else max_o_valid <= 0;
	end
	else max_o_valid <= 0;
end

assign max_o =  max_result;
assign aver_o = aver_result;

//maxpooling delay
always@(posedge clk or posedge rst) begin
	if(rst) begin
		pool_shift_y_dly1 <= 0;
		pool_shift_y_dly2 <= 0;
		pool_shift_y_dly3 <= 0;
		pool_pixel_valid_dly1 <= 0;
		pool_cnt4_dly1 <= 0;
		pool_o_flag <= 0;
	end
	else begin
		pool_shift_y_dly1 <= 	pool_shift_y;
		pool_shift_y_dly2 <= 	pool_shift_y_dly1;
		pool_shift_y_dly3 <= 	pool_shift_y_dly2;
		pool_pixel_valid_dly1 <=	pool_pixel_valid;
		pool_cnt4_dly1 <= 		pool_cnt4;
		pool_o_flag <= 			pool_i_flag;
	end
end


//FULLY CONNECT

reg [2:0] fully_x,fully_y;
reg [2:0] fully_x_dly1,fully_x_dly2,fully_x_dly3;
reg [8:0] fully_z;
reg [3:0] fully_we_cnt,fully_we_cnt_dly1,fully_we_cnt_dly2,fully_we_cnt_dly3;
reg [11:0] fully_cnt1;
reg [8:0] fuuly_cnt2;
reg signed [8:0] fully_data,fully_data_dly1;
reg [63:0] fully_in_weight;
reg signed [7:0] fully_weight;
reg signed [31:0] fully_acc;
reg signed [31:0] fully_bias;
wire [31:0] fully_relu;
reg [63:0] fully_m0;

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_x <= 0;
		fully_y <= 0;
		fully_z <= 0;
		fully_cnt1 <= 0;
	end
	else if(cs == OP_FULLY1) begin
		if(fully_y==3 && fully_z==63) begin
			fully_z <= 0;
			fully_y <= 0;
			fully_x <= fully_x + 1;
			fully_cnt1 <= fully_cnt1 + 1;
		end
		else if(fully_z == 63) begin
			fully_z <= 0;
			fully_y <= fully_y + 1;
			fully_cnt1 <= fully_cnt1 + 1;
		end
		else begin
			fully_z <= fully_z + 1;
			fully_cnt1 <= fully_cnt1 + 1;
		end
	end
	else if(cs == OP_FULLY2) begin
		if(fully_cnt1==71) begin
			fully_z <= fully_z + 1;
			fully_cnt1 <= fully_z + 1;
		end
		else if(fully_z==63) begin
			fully_z <= 0;
			fully_cnt1 <= fully_cnt1 + 1;
		end
		else begin
			fully_z <= fully_z + 1;
			fully_cnt1 <= fully_cnt1 + 1;
		end
	end
	else begin
		fully_x <= 0;
		fully_y <= 0;
		fully_z <= 0;
		fully_cnt1 <= 0;
	end
end 

assign fully_addr = (cs == OP_FULLY1) ? fully_z*4 + fully_y : (cs == OP_FULLY2)? fully_z:0 ;

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_data <= 0;
	end
	else if(cs == OP_FULLY1) begin
		if(fully_x_dly3 == 0) begin
			fully_data <= dout_mem_2[31:24];
		end
		else if(fully_x_dly3 == 1) begin
			fully_data <= dout_mem_2[23:16];
		end
		else if(fully_x_dly3 == 2) begin
			fully_data <= dout_mem_2[15:8];
		end
		else if(fully_x_dly3 == 3) begin
			fully_data <= dout_mem_2[7:0];
		end
		else begin
			fully_data <= 0;
		end
	end
	else if(cs == OP_FULLY2) begin
		fully_data <= dout_mem_1[7:0];
	end
	else begin
		fully_data <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_we_cnt <= 0;
		fully_we_addr <= 0;
	end
	else if(cs == OP_FULLY1 || cs == OP_FULLY2) begin
		if(fully_we_cnt == 7) begin
			fully_we_cnt <= 0;
			fully_we_addr <= fully_we_addr+1;
		end
		else begin
			fully_we_cnt <= fully_we_cnt + 1;
		end
	end
	else begin
		fully_we_cnt <= 0;
		fully_we_addr <= 0;
	end
end


always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_in_weight <= 0;
		fully_weight <= 0;
	end
	else if(cs == OP_FULLY1) begin
		if(fully_we_cnt_dly3 == 0) begin
			fully_in_weight <= dout_weight;
			fully_weight <= fully_in_weight[63:56] -128; 
		end
		else begin
			fully_in_weight <= fully_in_weight << 8;
			fully_weight <= fully_in_weight[63:56] -128; 
		end
	end
	else if(cs == OP_FULLY2) begin
		if(fully_we_cnt_dly3 == 0) begin
			fully_in_weight <= dout_weight;
			fully_weight <= fully_in_weight[63:56] -155; 
		end
		else begin
			fully_in_weight <= fully_in_weight << 8;
			fully_weight <= fully_in_weight[63:56] -155; 
		end
	end
	else begin
		fully_in_weight <= 0;
		fully_weight <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_acc <= 0;
	end
	else if(cs == OP_FULLY1) begin
		if(fully_cnt1 >4 && fully_cnt1<1029) begin
			fully_acc <= fully_acc + fully_data_dly1*fully_weight;
		end
		else begin
			fully_acc <= 0;
		end
	end
	else if(cs == OP_FULLY2) begin
		if(fully_cnt1 >4 && fully_cnt1<69) begin
			fully_acc <= fully_acc + fully_data_dly1*fully_weight;
		end
		else begin
			fully_acc <= 0;
		end
	end
	else begin
		fully_acc <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_bias <= 0;
	end
	else if(cs == OP_FULLY1) begin
		if(fully_cnt1 == 1029) begin
			fully_bias <= fully_acc + dout_bias;
		end
		else begin
			fully_bias <= 0;
		end
	end
	else if(cs == OP_FULLY2) begin
		if(fully_cnt1 == 69) begin
			fully_bias <= fully_acc + dout_bias;
		end
		else begin
			fully_bias <= 0;
		end
	end
	else fully_bias <= 0;
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_b_addr <= 0;
	end
	else if(cs == OP_FULLY1)begin
		if(fully_layer_vaild) begin
			fully_b_addr <= fully_b_addr +1;
		end
		else fully_b_addr <= fully_b_addr;
	end
	else if(cs == OP_FULLY2)begin
		if(fully_o_vaild) begin
			fully_b_addr <= fully_b_addr +1;
		end
		else fully_b_addr <= fully_b_addr;
	end
	else if(cs == OP_RD_FULLY1) begin
		fully_b_addr <= fully_b_addr;
	end
	else fully_b_addr <= 0;
end

assign fully_relu = fully_bias[31] ? 0 : fully_bias;

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_m0 <= 0;
	end
	else if(cs == OP_FULLY1) begin
		fully_m0 <= fully_relu * M0[3] ;
	end
	else if(cs == OP_FULLY2) begin
		fully_m0 <= fully_relu * M0[4] ;
	end
	else fully_m0 <= 0;
end


wire [63:0] fully_Img1;
wire [31:0] fully_remainder;
reg [10:0]fully_outputImg_reg;


assign fully_Img1 = (fully_m0[30])? fully_m0[63:31] +1 : fully_m0[63:31] ;
assign fully_remainder = fully_Img1 & ((1<<exp)-1);

always@(posedge clk, posedge rst) begin
    if(rst) begin
        fully_outputImg_reg <= 0;
    end
    else if (fully_remainder[exp-1]) begin
        fully_outputImg_reg <=  (fully_Img1>>exp) +1;
    end
    else fully_outputImg_reg <= (fully_Img1>>exp);
end
assign fully_o = (fully_outputImg_reg>255) ? 255 : fully_outputImg_reg ;


always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_o_vaild <= 0;
	end
	else if(cs == OP_FULLY1) begin
		if(fully_cnt1 == 1031) begin
			fully_o_vaild <= 1;
		end
		else begin
			fully_o_vaild <= 0;
		end
	end
	else if(cs == OP_FULLY2) begin
		if(fully_cnt1 == 71) begin
			fully_o_vaild <= 1;
		end
		else begin
			fully_o_vaild <= 0;
		end
	end
	else begin
		fully_o_vaild <= 0;
	end
end

always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_layer_vaild <= 0;
	end
	else if(cs == OP_FULLY1) begin
		if(fully_o_vaild) begin
			fully_layer_vaild <= 1;
		end
		else begin
			fully_layer_vaild <= 0;
		end
	end
	else begin
		fully_layer_vaild <= 0;
	end
end
assign fully_finish = (cs == OP_FULLY1) ? ( (fully_layer_vaild && fully_b_addr==63) ? 1:0) :  (cs == OP_FULLY2) ? (fully_o_vaild && fully_b_addr==3)?1:0 : 0 ;

//delay
always@(posedge clk or posedge rst) begin
	if(rst) begin
		fully_x_dly1 <= 0;
		fully_x_dly2 <= 0;
		fully_x_dly3 <= 0;
		fully_we_cnt_dly1 <= 0;
		fully_we_cnt_dly2 <= 0;
		fully_we_cnt_dly3 <= 0;
		fully_data_dly1 <=  0;
	end
	else begin
		fully_x_dly1 <= fully_x;
		fully_x_dly2 <= fully_x_dly1;
		fully_x_dly3 <= fully_x_dly2;
		fully_we_cnt_dly1 <= fully_we_cnt;
		fully_we_cnt_dly2 <= fully_we_cnt_dly1;
		fully_we_cnt_dly3 <= fully_we_cnt_dly2;
		fully_data_dly1 <= fully_data;
	end
end


endmodule 