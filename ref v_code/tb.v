//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/08 20:42:27
// Design Name: 
// Module Name: tb
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

`timescale	1ns/1ps
`define CYCLE	50.0

//picture
`define PAT_ifmap	"D:\\Work\\IMPORTANT\\gold\\layer0_INPUT_MAP_5.txt"
//conv1
`define PAT_bias1	"D:\\Work\\IMPORTANT\\gold\\bias1.txt"
`define PAT_weight1	"D:\\Work\\IMPORTANT\\gold\\weight1.txt"
//conv2
`define PAT_bias2	"D:\\Work\\IMPORTANT\\gold\\bias2.txt"
`define PAT_weight2	"D:\\Work\\IMPORTANT\\gold\\weight2.txt"
//conv3
`define PAT_bias3	"D:\\Work\\IMPORTANT\\gold\\bias3.txt"
`define PAT_weight3	"D:\\Work\\IMPORTANT\\gold\\weight3.txt"
//dense1
`define PAT_fully_b1"D:\\Work\\IMPORTANT\\gold\\fully_b1.txt"
`define PAT_fully1	"D:\\Work\\IMPORTANT\\gold\\fully1.txt"
//dense2
`define PAT_fully_b2"D:\\Work\\IMPORTANT\\gold\\fully_b2.txt"
`define PAT_fully2	"D:\\Work\\IMPORTANT\\gold\\fully2.txt"

`define M0_exponent	"D:\\Work\\IMPORTANT\\gold\\m0exponent.txt"

module tb();
parameter TBITS = 64;
parameter TBYTE = 8;

reg              S_AXIS_MM2S_TVALID = 0;
wire             S_AXIS_MM2S_TREADY;
reg  [TBITS-1:0] S_AXIS_MM2S_TDATA = 0;
reg  [TBYTE-1:0] S_AXIS_MM2S_TKEEP = 0;
reg  [1-1:0]     S_AXIS_MM2S_TLAST = 0;

wire             M_AXIS_S2MM_TVALID;
reg              M_AXIS_S2MM_TREADY = 0;
wire [TBITS-1:0] M_AXIS_S2MM_TDATA;
wire [TBYTE-1:0] M_AXIS_S2MM_TKEEP;
wire [1-1:0]     M_AXIS_S2MM_TLAST;

reg              aclk = 0;
reg              aresetn = 1;

//image
reg	[63:0]	ifmap	[0:383];
//conv1
reg	[63:0]	bias1	[0:31];
reg	[63:0]	weight1	[0:480];
//conv2
reg	[63:0]	bias2	[0:31];
reg	[63:0]	weight2	[0:9215];
//conv3
reg	[63:0]	bias3	[0:63];
reg	[63:0]	weight3	[0:18431];
//dense1
reg	[63:0]	fully_b1[0:63];
reg	[63:0]	fully1	[0:65535];
//dense2
reg	[63:0]	fully_b2[0:9];
reg	[63:0]	fully2	[0:639];

reg [63:0] m0exponent [0:4];
//yolo_top----------------------------------------
yolo_top
#(
        .TBITS(TBITS),
        .TBYTE(TBYTE)
) top_inst (
        .S_AXIS_MM2S_TVALID(S_AXIS_MM2S_TVALID),
        .S_AXIS_MM2S_TREADY(S_AXIS_MM2S_TREADY),
        .S_AXIS_MM2S_TDATA(S_AXIS_MM2S_TDATA),
        .S_AXIS_MM2S_TKEEP(S_AXIS_MM2S_TKEEP),
        .S_AXIS_MM2S_TLAST(S_AXIS_MM2S_TLAST),
        
        .M_AXIS_S2MM_TVALID(M_AXIS_S2MM_TVALID),
        .M_AXIS_S2MM_TREADY(M_AXIS_S2MM_TREADY),
        .M_AXIS_S2MM_TDATA(M_AXIS_S2MM_TDATA),
        .M_AXIS_S2MM_TKEEP(M_AXIS_S2MM_TKEEP),
        .M_AXIS_S2MM_TLAST(M_AXIS_S2MM_TLAST),  // EOL      
        
        .S_AXIS_MM2S_ACLK(aclk),
        .M_AXIS_S2MM_ACLK(aclk),
        .aclk(aclk),
        .aresetn(aresetn)
);

integer i;

initial begin // initial pattern and expected result
	wait(aresetn==1);
	begin
		$readmemh(`PAT_ifmap, ifmap);
        $readmemh(`PAT_bias1, bias1);
        $readmemh(`PAT_weight1, weight1);
        
        $readmemh(`PAT_bias2, bias2);
        $readmemh(`PAT_weight2, weight2);
		
        $readmemh(`PAT_bias3, bias3);
        $readmemh(`PAT_weight3, weight3);

        $readmemh(`PAT_fully_b1, fully_b1);
        $readmemh(`PAT_fully1, fully1);
		
        $readmemh(`PAT_fully_b2, fully_b2);    
        $readmemh(`PAT_fully2, fully2);
        
        $readmemh(`M0_exponent, m0exponent);
	end	
end

initial begin   
    S_AXIS_MM2S_TKEEP = 'hff;
    #(`CYCLE*2);
    aresetn = 0;
    #(`CYCLE*3);
    aresetn = 1;

    #(`CYCLE*2);

    for(i=0; i<384; i=i+1)begin	//image
        @(posedge aclk);    
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=ifmap[i];
		
		#0.1;
        wait(S_AXIS_MM2S_TREADY);
    end
    
    for(i=0; i<5; i=i+1)begin	//image
        @(posedge aclk);    
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=m0exponent[i];
                
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
                               
    end
        
    for(i=0; i<32; i=i+1)begin	//bias1
        @(posedge aclk);
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=bias1[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end                                                      
               
    for(i=0; i<480; i=i+1)begin	//weight1
        @(posedge aclk);          
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=weight1[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end
    
    for(i=0; i<32; i=i+1)begin	//bias2
        @(posedge aclk);
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=bias2[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end
                
    for(i=0; i<5120; i=i+1)begin //weight2
        @(posedge aclk);            
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=weight2[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end
    
    for(i=0; i<64; i=i+1)begin	//bias3
        @(posedge aclk);
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=bias3[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end
                
    for(i=0; i<10240; i=i+1)begin //weight3
        @(posedge aclk);            
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=weight3[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end
    
    for(i=0; i<64; i=i+1)begin //dense bias1
        @(posedge aclk);
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=fully_b1[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end
     
    for(i=0; i<8192; i=i+1)begin //dense weight1
        @(posedge aclk);            
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=fully1[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end 
        
    for(i=0; i<4; i=i+1)begin //dense bias2
        @(posedge aclk);
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=fully_b2[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
    end              
                
    for(i=0; i<32; i=i+1)begin //dense weight2
        @(posedge aclk);            
        S_AXIS_MM2S_TVALID=1;
        S_AXIS_MM2S_TDATA=fully2[i];
        
        #0.1;
        wait(S_AXIS_MM2S_TREADY);
        
        if(i==31) 
            S_AXIS_MM2S_TLAST=1;
            //wait(S_AXIS_MM2S_TREADY);
    end


    @(posedge aclk);
    S_AXIS_MM2S_TVALID = 0;
    S_AXIS_MM2S_TDATA  = 'h0;
    S_AXIS_MM2S_TLAST  = 0;
    #(`CYCLE*5);
  
    @(posedge aclk);
    M_AXIS_S2MM_TREADY = 1;
   
    @(posedge M_AXIS_S2MM_TVALID);
    #(`CYCLE*450);
    M_AXIS_S2MM_TREADY = 1;
    
    @(negedge M_AXIS_S2MM_TVALID);

    #(`CYCLE*15);
    $finish;
end

always begin #(`CYCLE/2) aclk = ~aclk; end

endmodule 