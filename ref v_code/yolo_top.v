// ============================================================================
// Designer : Liu Yi-Jun
// Create   : 2019.8.20
// Ver      : 1.0
// Func     : Yolo Top with AXI_DMA
// Func     : AXIS I/O Stream interface for rate adaption
// ============================================================================

`timescale 1 ns / 1 ps

module yolo_top
#(
        parameter TBITS = 64 ,
        parameter TBYTE = 8
) (
        input  wire             S_AXIS_MM2S_TVALID,
        output wire             S_AXIS_MM2S_TREADY,
        input  wire [TBITS-1:0] S_AXIS_MM2S_TDATA,
        input  wire [TBYTE-1:0] S_AXIS_MM2S_TKEEP,
        input  wire [1-1:0]     S_AXIS_MM2S_TLAST,

        output wire             M_AXIS_S2MM_TVALID,
        input  wire             M_AXIS_S2MM_TREADY,
        output wire [TBITS-1:0] M_AXIS_S2MM_TDATA,
        output wire [TBYTE-1:0] M_AXIS_S2MM_TKEEP,
        output wire [1-1:0]     M_AXIS_S2MM_TLAST,  // EOL      
        
        output wire [TBITS-1:0] isif_data_dout,
        output wire [TBYTE-1:0] isif_strb_dout,
        output wire [1 - 1:0]   isif_last_dout,
        output wire [1 - 1:0]   isif_user_dout,
        output wire             isif_empty_n,
        output wire             isif_read,        
        
        output wire [TBITS-1:0] osif_data_din,
        output wire [TBYTE-1:0] osif_strb_din,
        output wire [1 - 1:0]   osif_last_din,
        output wire [1 - 1:0]   osif_user_din,
        output wire             osif_full_n,
        output wire             osif_write,
              
        output wire [12:0] addr_mem_1 , 
        output wire [12:0] addr_mem_2 , 
        output wire [12:0] addr_weight , 
        output wire [12:0] addr_bias ,
        
        output wire [TBITS-1:0] din_mem_1 ,
        output wire [TBITS-1:0] din_mem_2 ,
        output wire [TBITS-1:0] din_weight ,
        output wire [TBITS-1:0] din_bias ,
        
        output wire wen_mem_1 ,
        output wire wen_mem_2 ,
        output wire wen_weight ,
        output wire wen_bias ,
        
        output wire [TBITS-1:0] dout_mem_1 , 
        output wire [TBITS-1:0] dout_mem_2 , 
        output wire [TBITS-1:0] dout_weight ,
        output wire [TBITS-1:0] dout_bias , 
        
        output wire [4:0] cs,
        
        input  wire             S_AXIS_MM2S_ACLK,
        input  wire             M_AXIS_S2MM_ACLK,
        input  wire             aclk,
        input  wire             aresetn
);

parameter RESET_ACTIVE_LOW = 1;

//wire [TBITS - 1:0] isif_data_dout;
//wire [TBYTE - 1:0] isif_strb_dout;
//wire [1 - 1:0]     isif_last_dout;
//wire [1 - 1:0]     isif_user_dout;
//wire               isif_empty_n;
//wire               isif_read;

//wire [TBITS - 1:0] osif_data_din;
//wire [TBYTE - 1:0] osif_strb_din;
//wire               osif_full_n;
//wire               osif_write;
//wire [1 - 1:0]     osif_last_din;
//wire [1 - 1:0]     osif_user_din;

wire ap_rst;


// ============================================================================
// Instantiation
//

yolo_core
#(
        .TBITS (TBITS) ,
        .TBYTE (TBYTE)
)
yolo_core_U (
        
        //
        .isif_data_dout ( isif_data_dout ) ,
        .isif_strb_dout ( isif_strb_dout ) ,
        .isif_last_dout ( isif_last_dout ) ,
        .isif_user_dout ( isif_user_dout ) ,
        .isif_empty_n ( isif_empty_n ) ,
        .isif_read ( isif_read ) ,
        //
        .osif_data_din ( osif_data_din ) ,
        .osif_strb_din ( osif_strb_din ) ,
        .osif_last_din ( osif_last_din ) ,
        .osif_user_din ( osif_user_din ) ,
        .osif_full_n ( osif_full_n ) ,
        .osif_write ( osif_write ) ,
        
        .addr_mem_1 (addr_mem_1) , 
        .addr_mem_2 (addr_mem_2) , 
        .addr_weight (addr_weight) , 
        .addr_bias (addr_bias) ,
        
        .din_mem_1 (din_mem_1) ,
        .din_mem_2 (din_mem_2) ,
        .din_weight (din_weight) ,
        .din_bias (din_bias) ,
        
        .wen_mem_1 (wen_mem_1) ,
        .wen_mem_2 (wen_mem_2) ,
        .wen_weight (wen_weight) ,
        .wen_bias (wen_bias) ,
        
        .dout_mem_1 (dout_mem_1) , 
        .dout_mem_2 (dout_mem_2) , 
        .dout_weight (dout_weight) ,
        .dout_bias (dout_bias) ,
        
        .cs(cs),

        //
        .rst ( ap_rst ) ,
        .clk ( aclk )
);  // yolo_core_U


INPUT_STREAM_if
#(
        .TBITS (TBITS) ,
        .TBYTE (TBYTE)
)
INPUT_STREAM_if_U (

        .ACLK ( S_AXIS_MM2S_ACLK ) ,
        .ARESETN ( aresetn ) ,
        .TVALID ( S_AXIS_MM2S_TVALID ) ,
        .TREADY ( S_AXIS_MM2S_TREADY ) ,
        .TDATA ( S_AXIS_MM2S_TDATA ) ,
        .TKEEP ( S_AXIS_MM2S_TKEEP ) ,
        .TLAST ( S_AXIS_MM2S_TLAST ) ,      
        .TUSER ( 1'b0 ) ,

        .isif_data_dout ( isif_data_dout ) ,
        .isif_strb_dout ( isif_strb_dout ) ,
        .isif_last_dout ( isif_last_dout ) ,
        .isif_user_dout ( isif_user_dout ) ,
        .isif_empty_n ( isif_empty_n ) ,
        .isif_read ( isif_read )
);  // input_stream_if_U

OUTPUT_STREAM_if
#(
        .TBITS (TBITS) ,
        .TBYTE (TBYTE)
)
OUTPUT_STREAM_if_U (

        .ACLK ( M_AXIS_S2MM_ACLK ) ,
        .ARESETN ( aresetn ) ,
        .TVALID ( M_AXIS_S2MM_TVALID ) ,
        .TREADY ( M_AXIS_S2MM_TREADY ) ,
        .TDATA ( M_AXIS_S2MM_TDATA ) ,
        .TKEEP ( M_AXIS_S2MM_TKEEP ) ,
        .TLAST ( M_AXIS_S2MM_TLAST ) ,      
        .TUSER (  ) ,

        .osif_data_din ( osif_data_din ) ,
        .osif_strb_din ( osif_strb_din ) ,
        .osif_last_din ( osif_last_din ) ,
        .osif_user_din ( osif_user_din ) ,
        .osif_full_n ( osif_full_n ) ,
        .osif_write ( osif_write )
);  // output_stream_if_U

yolo_rst_if #(
        .RESET_ACTIVE_LOW ( RESET_ACTIVE_LOW ) )
yolo_rst_if_U(
        .dout ( ap_rst ) ,
        .din ( aresetn ) );  // yolo_rst_if_U

endmodule  // yolo_top
