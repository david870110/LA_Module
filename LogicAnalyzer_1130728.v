`timescale 1 ns / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/15/2023 10:02:45 AM
// Design Name: 
// Module Name: LOGIC_ANLZ
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


module LOGIC_ANLZ #( parameter pADDR_WIDTH   = 15,
                     parameter pDATA_WIDTH   = 32
                   )
(
    //AxiLite
    output wire           axi_awready,
    output wire           axi_wready,
    output wire           axi_arready,
    output wire   [31: 0] axi_rdata,
    output wire           axi_rvalid,

    input  wire           axi_awvalid,
    input  wire   [14: 0] axi_awaddr,
    input  wire           axi_wvalid,
    input  wire   [31: 0] axi_wdata,
    input  wire   [3: 0]  axi_wstrb,
    input  wire           axi_arvalid,
    input  wire   [14: 0] axi_araddr,
    input  wire           axi_rready,
    input  wire           cc_la_enable,


    //AxiS  
    output wire   [31: 0] m_tdata,
    output wire   [3: 0]  m_tstrb,
    output wire   [3: 0]  m_tkeep,
    output wire           m_tlast,
    output wire           m_tvalid,
    output wire   [1: 0]  m_tuser,
    output wire           la_hpri_req,

    input  wire           m_tready,

    //User singals
    input  wire   [23: 0] up_la_data,

    //Generic
    input  wire           user_clock2,
    input  wire           axi_clk,
    input  wire           axi_reset_n,
    input  wire           axis_clk,
    input  wire           uck2_rst_n,
    input  wire           axis_rst_n
);
    localparam FIFO_DEPTH               = 128;  
    localparam AXIS_PKT_LEN             = 8;   	

    wire fifo_full;
	reg wr_en,wr_en_d1; // if (fifo full wait , cc_la_enable)
    reg rd_en,rd_en_d1;
    reg [23:0] la_enable;
    reg [6:0] h_thresh;
    reg [6:0] l_thresh;
    reg [6:0] pop_cond;
    
    assign fifo_full = 0;
    //--------------------------------------------------------------
    // write
    //--------------------------------------------------------------
    assign axi_awready  = wr_en;
    assign axi_wready   = wr_en;
    //--------------------------------------------------------------
    // read
    //--------------------------------------------------------------
    assign axi_arready  = rd_en;
    assign axi_rdata    = (axi_araddr[11:2] == 10'h000) ? {8'b0, la_enable} : 
                          (axi_araddr[11:2] == 10'h001) ? {24'b0, h_thresh} :
                          (axi_araddr[11:2] == 10'h002) ? {24'b0, l_thresh} :
                          (axi_araddr[11:2] == 10'h003) ? {24'b0, pop_cond} : 32'hFFFFFFFF;
    assign axi_rvalid   = rd_en;
    
    always @(posedge axi_clk or negedge axi_reset_n) 
        begin
        if(!axi_reset_n) 
            begin
            wr_en <= 0;
            rd_en <= 0;
            end 
        else 
            begin
            wr_en_d1 <= wr_en;
            rd_en_d1 <= rd_en;
            if(cc_la_enable)
                begin
                if( !fifo_full & wr_en )
                    wr_en <= 0;
                else if( axi_awvalid & axi_wvalid & !wr_en_d1) // if address arrive but data not arrived?
                    wr_en <= 1; 
                if(rd_en)
                    rd_en <= 0;
                else if( axi_arvalid & !rd_en_d1)
                    rd_en <= 1; 
                end
            end
        end    

// *** for testing
    always @(posedge axi_clk or negedge axi_reset_n) 
        begin
        if(!axi_reset_n) 
            begin
            h_thresh <= FIFO_DEPTH >> 1;
            l_thresh <= FIFO_DEPTH >> 3;
            la_enable <= 24'h01;
            pop_cond <= AXIS_PKT_LEN;
            end 
        else 
            begin
                if(wr_en)
                    case ( axi_awaddr[11:2] )
                    10'h000:
                        la_enable <= axi_wdata[23:0];
                    10'h001:
                        h_thresh <= axi_wdata[15:0];                        
                    10'h002:
                        l_thresh <= axi_wdata[15:0];                        
                    10'h003:
                        pop_cond <= axi_wdata[15:0];                                          
                    endcase
            end   
        end 
        
    reg [23:0] r_la_data;
    reg la_changed_d1;
    wire la_changed;
    assign la_changed = (up_la_data & la_enable) != r_la_data;   // Jiin: identify # of bits
    always @(posedge axi_clk or negedge axi_reset_n) 
        begin
        if( la_changed ) 
            r_la_data <= up_la_data & la_enable; 
        la_changed_d1 <= la_changed;
        end    
endmodule

//----------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
	localparam axi_fsm_idle             = 3'b000;
	localparam axi_fsm_read_data        = 3'b001;
	localparam axi_fsm_read_complete    = 3'b010;
	localparam axi_fsm_write_data       = 3'b011;
	localparam axi_fsm_write_complete   = 3'b100;	

    localparam FIFO_WIDTH               = 32; 
    localparam FIFO_DEPTH               = 128;  
    localparam AXIS_PKT_LEN             = 8;   	
	

	reg axi_wready_o;
	reg axi_arready_o;
	reg [31:0] axi_rdata_o;
	reg axi_rvalid_o;

    reg [23:0] la_enable;
    reg [6:0] h_thresh;
    reg [6:0] l_thresh;
    reg [6:0] pop_cond;
    
    reg la_hpri_req_o;

	reg [2:0] axi_fsm_reg;
	reg [11:0] axi_addr_reg;
	reg [31:0] axi_wdata_reg;    
    
    assign axi_awready = axi_awready_o;
    assign axi_wready = axi_wready_o;
    assign axi_arready = axi_arready_o;
    assign axi_rdata = axi_rdata_o;
    assign axi_rvalid = axi_rvalid_o;
     
    ///////////////////////////////////////////
	// Always for AXI-Lite LA Slave response //
	///////////////////////////////////////////
    // -- Jiin  Can reduce to several lines of code -> no need to latch address/wdata
    // -- Jiin  No need for state machine
    // -- axilite write - W_en = cc_la_enable & (awaddr == target_address) & (awready & wready)
    // -- axi_rdata = mux register out based on araddr; no need other qualification
	always @ ( posedge axi_clk or negedge axi_reset_n ) begin	
		if ( !axi_reset_n ) begin
			axi_awready_o <= 0;
			axi_wready_o <= 0;
			axi_arready_o <= 0;
			axi_rdata_o <= 0; 
			axi_rvalid_o <= 0;
			axi_fsm_reg <= axi_fsm_idle;
			axi_addr_reg <= 0;
			axi_wdata_reg <= 0;
            la_enable <= 24'h0;
            //!!
            h_thresh <= FIFO_DEPTH >> 1;
            l_thresh <= FIFO_DEPTH >> 3;

            pop_cond <= AXIS_PKT_LEN;
		end else begin
			case ( axi_fsm_reg )
				axi_fsm_idle:
				begin
					if ( axi_arvalid && cc_la_enable ) begin
						axi_arready_o <= 1'b1;
						axi_addr_reg <= axi_araddr;
						axi_fsm_reg <= axi_fsm_read_data;						
					end else if ( axi_awvalid && axi_wvalid && cc_la_enable ) begin
						axi_wready_o <= 1'b1;							
						axi_awready_o <= 1'b1;
						axi_addr_reg <= axi_awaddr;	
						axi_wdata_reg <= axi_wdata;	
						axi_fsm_reg <= axi_fsm_write_complete;
					end else if ( axi_awvalid && cc_la_enable ) begin
						axi_awready_o <= 1'b1;
						axi_addr_reg <= axi_awaddr;
						axi_fsm_reg <= axi_fsm_write_data;						
					end
				end
				axi_fsm_read_data:
				begin	
					axi_arready_o <= 1'b0;
					case ( axi_addr_reg[11:2] )
                        10'h000:
                        begin
                            axi_rdata_o <= {8'b0, la_enable};
                        end
                        10'h001:
                        begin
                            axi_rdata_o <= {24'b0, h_thresh};                        
                        end
                        10'h002:
                        begin
                            axi_rdata_o <= {24'b0, l_thresh};                        
                        end
                        10'h003:
                        begin
                            axi_rdata_o <= {24'b0, pop_cond};                        
                        end                        
                        default:                        
                        begin
                            axi_rdata_o <= 32'hFFFFFFFF;
                        end
                    endcase                       
					axi_rvalid_o <= 1'b1;	
					axi_fsm_reg <= axi_fsm_read_complete;																					
				end
				axi_fsm_read_complete:			
				begin
					if ( axi_rready ) begin    
						axi_rdata_o <= 32'h0;       // Jiin: no need to gated to zero - don't care
						axi_rvalid_o <= 1'b0;	
						axi_fsm_reg <= axi_fsm_idle;															
					end
				end	
				axi_fsm_write_data:
				begin
					axi_awready_o <= 1'b0;						
					if ( axi_wvalid && cc_la_enable ) begin
						axi_wdata_reg <= axi_wdata;     // Jiin: no need to latch axi_wdata;
						axi_wready_o <= 1'b1;
						axi_fsm_reg <= axi_fsm_write_complete;
					end					
				end
				axi_fsm_write_complete:
				begin
					case ( axi_addr_reg[11:2] )
                        10'h000:
                        begin
                            la_enable <= axi_wdata_reg[23:0];
                        end
                        10'h001:
                        begin
                            h_thresh <= axi_wdata_reg[15:0];                        
                        end
                        10'h002:
                        begin
                            l_thresh <= axi_wdata_reg[15:0];                        
                        end
                        10'h003:
                        begin
                            pop_cond <= axi_wdata_reg[15:0];                        
                        end                        
                        default:                        
                        begin
                            axi_wdata_reg <= 32'b0;
                        end
                    endcase  									
					axi_awready_o <= 1'b0;						
					axi_wready_o <= 1'b0;
					axi_fsm_reg <= axi_fsm_idle;
				end
			endcase
		end
	end	    

    reg [23:0] r_la_data;
    reg la_changed_d1;
    wire la_changed;
    assign la_changed = |( la_enable) & ( (up_la_data & la_enable) != r_la_data );   // Jiin: identify # of bits
    
    ////////////////////////////////////////////
    // Always for latch up_la_data if changed //
    ////////////////////////////////////////////    
    always @(posedge axi_clk or negedge axi_reset_n) 
        begin
        if( la_changed ) 
            r_la_data <= up_la_data & la_enable; 
        la_changed_d1 <= la_changed;
        end    
//----------------------------------------------------------------------------------
    reg [7:0] rle_count;
    reg [7:0] r_la_count;
    reg rle_overflow;
    
    //////////////////////////
    // Always for rel_count //
    //////////////////////////    
    // Jiin:  clarify the relationship of rle_count, r_la_count ??
    // Jiin: why r_la_count is 1T delay from rle_count ??
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if(!axi_reset_n) begin
            rle_count <= 1;
            r_la_count <= 1;
            rle_overflow <= 0;
        end else begin
            rle_overflow <= 0;     // Jiin: zero-delay glitch ?   
            if( la_changed ) begin
                rle_count <= 1;
                r_la_count <= rle_count;
            end else begin
                if( rle_count == 8'hff ) begin
                    rle_count <= 1;
                    r_la_count <= rle_count;
                    rle_overflow <= 1;
                end else begin
                    rle_count <= rle_count + 1;
                    // Jiin: put rle_overflow <= 0;  
                end
            end
        end    
    end   
//-----------------------------------------------------------------------------------------------------------------
    reg	fifo_wren;
    reg [31:0] fifo_wrdata0;
    wire fifo_full;
    wire [31:0] fifo_rddata0;    
    wire [31:0] fifo_rddata1;
    wire fifo_empty;
    reg [23:0] fifo_full_count;
    wire [31:0] fifo_full_push_data;
    
    assign fifo_full_push_data = {8'b0, fifo_full_count};
    
    ////////////////////////////////
    // Always for fifo full count //
    ////////////////////////////////    
    // Jiin: Why need fifo full count ?
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if(!axi_reset_n) begin
            fifo_full_count <= 24'b0;
        end else begin
            if (fifo_full)
                fifo_full_count <= fifo_full_count + 1;
            else
                fifo_full_count <= 24'b0;
        end
    end    

    reg fifo_full_push;
    reg [7:0] fifo_push_count;
    wire fifo_push_la_changed;
    wire [31:0] fifo_push_data_la_changed;
    
    assign fifo_push_la_changed = fifo_full? 1'b0 : (r_la_data_available || rle_overflow);
    assign fifo_push_data_la_changed = { r_la_count , r_la_data};    
    
    /////////////////////////////////////
    // Always for FIFO push operations //
    /////////////////////////////////////   
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if(!axi_reset_n) begin  
            fifo_push_count <= 8'b0;
            fifo_full_push <= 1'b0;
            fifo_wren <= 1'b0;
            fifo_wrdata0 <= 32'b0;            
        end else begin
            fifo_wren <= 1'b0;
            if(|la_enable) begin
                if (fifo_full) begin
                    fifo_full_push <= 1'b1;
                end else if ( fifo_full_push )begin
                    if (!fifo_full) begin
                        fifo_push_count <= fifo_push_count + 1; 
                        fifo_full_push <= 1'b0;            
                        fifo_wren <= 1'b1;
                        fifo_wrdata0 <= fifo_full_push_data;
                    end     
                end else if (fifo_push_count == 8'h40) begin   // Jiin - replaced with Parameters  
                        fifo_push_count <= 0;
                        fifo_wren <= 1'b1;
                        fifo_wrdata0 <= 32'b0;                     
                end else begin
                    if ( fifo_push_la_changed ) begin
                        fifo_push_count <= fifo_push_count + 1;                
                        fifo_wren <= 1'b1;
                        fifo_wrdata0 <= fifo_push_data_la_changed;
                    end            
                end  
            end else begin
                //Do nothing if no signals need to be monitored
            end 
        end
    end
    
    reg [$clog2(FIFO_DEPTH)-1:0] w_ptr;
    reg [$clog2(FIFO_DEPTH)-1:0] r_ptr; 
    reg [$clog2(FIFO_DEPTH):0] fifo_count;  

    // Jiin: use push, pop instead of w_valid, r_valid - it is easily confused with axi signals
    wire w_valid;
    reg r_valid;

    assign fifo_full = (fifo_count==FIFO_DEPTH)? 1'b1 : 1'b0;
    assign fifo_empty = (fifo_count==0)? 1'b1 : 1'b0;
    assign w_valid = fifo_wren & !fifo_full;

    ///////////////////////////////////////////
    // Always for FIFO fifo_count operations //
    ///////////////////////////////////////////     
    always @(posedge axi_clk or negedge axi_reset_n)
    begin
        if(!axi_reset_n)
            fifo_count <= 0;          
        else if(w_valid & !r_valid)
            fifo_count <= fifo_count + 1'b1;
        else if(!w_valid & r_valid)
            fifo_count <= fifo_count - pop_cond;
        else if(w_valid & r_valid)
            fifo_count <= fifo_count + 1'b1 - pop_cond;
    end
    
    //////////////////////////////////////
    // Always for FIFO w_ptr operations //
    //////////////////////////////////////    
    // Jiin: The FIFO is used as a ring FIFO, when reach the depth-1, it shall wrap to 0
    // Jiin: wptr, rptr wrap around logic
    always @(posedge axi_clk or negedge axi_reset_n)
    begin
        if(!axi_reset_n)
            w_ptr <= 0;
        else if(fifo_wren)
            w_ptr <= w_ptr + 1'b1;      // Jiin: wrap around logic
    end                

    reg [1:0] pop_stm;
    reg [31:0] m_tvalid_o;          // Jiin: 32-bit ??
    reg [31:0] fifo_latchdata;
    reg fifo_latchavaliable;
    reg [7:0] transfered_count;   
    
    assign m_tvalid = m_tvalid_o;       // Jiin: 32bit assigned to one bit signal m_tvalid ??
    assign m_tstrb = 4'b1111;
    assign m_tkeep = m_tstrb;
    assign m_tuser = 2'b00;
    assign m_tlast = (transfered_count == pop_cond)? 1'b1: 1'b0;
    assign la_hpri_req = la_hpri_req_o;

    // Jiin: m_tdata can be just the top of FIFO, i.e. FIFOSRAM[rptr]
    assign m_tdata =  fifo_latchavaliable? fifo_latchdata : fifo_rddata1; 
    
    ///////////////////////////////////////
    // Always for AXIS output operations //
    ///////////////////////////////////////
    // Jiin:  Redesign LA flush mechanism
    // When fifo_count >= l_thresh, start flush, till fifo empty
    // When fifo_count >= h_thresh, asserts high_priority, deasserts high_priority when reach l_thresh
    // 
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if(!axis_rst_n) begin
            la_hpri_req_o <= 1'b0;
            transfered_count <= 4'b0;
            pop_stm <= 2'b0;
            fifo_latchdata <= 32'b0;
            fifo_latchavaliable <= 1'b0;
            r_ptr <= 0;                        
            r_valid <= 1'b0;
            m_tvalid_o <= 32'b0;
        end else begin
            case (pop_stm)
                2'b0:
                begin
                    if (fifo_count >= h_thresh)
                        la_hpri_req_o <= 1'b1;
                    else if (fifo_count <= l_thresh)
                        la_hpri_req_o <= 1'b0;                            
                    transfered_count <= 4'b0;
                    r_valid <= 1'b0;
                    pop_stm <= 2'b01;
                end            
                2'b01:
                begin
                    if (fifo_count > pop_cond) begin
                        if (fifo_count >= h_thresh)
                            la_hpri_req_o <= 1'b1;
                        else if (fifo_count <= l_thresh)
                            la_hpri_req_o <= 1'b0; 
                        transfered_count <= transfered_count + 1;
                        fifo_latchdata <= fifo_rddata1;
                        m_tvalid_o <= 1'b1;                        
                        fifo_latchavaliable <= 1'b1;
                        r_ptr <= r_ptr + 1; 
                        pop_stm <= 2'b10;
                    end     
                end
                2'b10:
                begin
                    if (transfered_count == pop_cond) begin
                        transfered_count <= 4'b0;                    
                        pop_stm <= 2'b0;
                        fifo_latchdata <= 32'b0;
                        fifo_latchavaliable <= 1'b0;
                        r_valid <= 1'b1;
                        m_tvalid_o <= 1'b0;
                    end else begin
                        if (!fifo_latchavaliable)
                            fifo_latchdata <= fifo_rddata1;
                             
                        if(m_tready)begin
                            transfered_count <= transfered_count + 1;
                            fifo_latchavaliable <= 1'b0;                            
                            r_ptr <= r_ptr + 1;
                            m_tvalid_o <= 1'b1;
                            pop_stm <= 2'b10;
                        end else begin
                            transfered_count <= transfered_count;
                            fifo_latchavaliable <= 1'b1;
                            m_tvalid_o <= 1'b1;
                            pop_stm <= 2'b10;
                        end
                    end
                end                
             endcase
        end
    end 

// Jiin: Change to single port SRAM
//    use 2x data-width, i.e. 48-bit. 
//    so that we double the SRAM bandwidth to emulate two-port SRAM
//    
   
`ifdef USE_skywater_SRAM
    sram #(.pADDR_WIDTH($clog2(FIFO_DEPTH)),
           .pDATA_WIDTH(FIFO_WIDTH)
          ) captured_fifo
    (
        .clk0(axi_clk),
        .csb0(1'b0),
        .web0(!fifo_wren),
        .wmask0(4'hF),
        .addr0(w_ptr),
        .din0(fifo_wrdata0),
        .dout0(fifo_rddata0),
        .clk1(axi_clk),
        .csb1(1'b0),
        .addr1(r_ptr),
        .dout1(fifo_rddata1)
    );       

`endif //USE_skywater_SRAM

`ifdef USE_PDK_SRAM
    PDK_SRAM2RW128x32 captured_fifo
    (
      .CLKA(axi_clk),
      .CENA(1'b0),
      .WENA(~fifo_wren),
      .AA(w_ptr),
      .DA(fifo_wrdata0),
      .OENA(1'b0),
      .QA(fifo_rddata0),
      .CLKB(axi_clk),
      .CENB(1'b0),
      .WENB(1'b1), //always read
      .AB(r_ptr),      
      .DB(0),       //data in always 0
      .OENB(1'b0),
      .QB(fifo_rddata1)
    );


`endif //USE_PDK_SRAM
   
`ifdef USE_EDK_SRAM
    EDK_SRAM2RW128x32 captured_fifo
    (	
      .CE1(axi_clk),
      .CSB1(1'b0),
      .WEB1(~fifo_wren),
      .OEB1(1'b0),
      .A1(w_ptr),
      .I1(fifo_wrdata0),
      .O1(fifo_rddata0),
      .CE2(axi_clk),
      .CSB2(1'b0),
      .WEB2(1'b1), //always read
      .OEB2(1'b0),
      .A2(r_ptr),      
      .I2(0),       //data in always 0
      .O2(fifo_rddata1)
    );

`endif //USE_EDK_SRAM

endmodule // LOGIC_ANLZ

*/