`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/30/2023 05:16:40 PM
// Design Name: 
// Module Name: LOGIC_ANLZ_tb
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

module LOGIC_ANLZ_tb;
    // instance
    // - axi-lite
    wire        axi_awready;
    wire        axi_wready;
    wire        axi_arready;
    wire  [31:0] axi_rdata;
    wire        axi_rvalid;
    reg         axi_awvalid;
    reg  [14:0] axi_awaddr;
    reg         axi_wvalid;
    reg  [31:0] axi_wdata;
    reg  [3:0]  axi_wstrb;
    reg         axi_arvalid;
    reg  [14:0] axi_araddr;
    reg         axi_rready;
    reg         cc_la_enable;

    // - axis
    wire [31:0] m_tdata;
    wire [3:0]  m_tstrb;
    wire [3:0]  m_tkeep;
    wire        m_tlast;
    wire        m_tvalid;
    wire [1:0]  m_tuser;
    wire        la_hpri_req;
    wire        user_clock2;
    wire        axis_clk;
    wire        uck2_rst_n;
    wire        axis_rst_n;
    reg         m_tready;
    reg  [23:0] up_la_data;
    reg         axi_clk;
    reg         axi_reset_n;

    LOGIC_ANLZ #(
        .pADDR_WIDTH(15),
        .pDATA_WIDTH(32)
    ) DUT (
        .axi_awready(axi_awready),
        .axi_wready(axi_wready),
        .axi_arready(axi_arready),
        .axi_rdata(axi_rdata),
        .axi_rvalid(axi_rvalid),
        .axi_awvalid(axi_awvalid),
        .axi_awaddr(axi_awaddr),
        .axi_wvalid(axi_wvalid),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_arvalid(axi_arvalid),
        .axi_araddr(axi_araddr),
        .axi_rready(axi_rready),
        .cc_la_enable(cc_la_enable),
        .m_tdata(m_tdata),
        .m_tstrb(m_tstrb),
        .m_tkeep(m_tkeep),
        .m_tlast(m_tlast),
        .m_tvalid(m_tvalid),
        .m_tuser(m_tuser),
        .la_hpri_req(la_hpri_req),
        .m_tready(m_tready),
        .up_la_data(up_la_data),
        .user_clock2(user_clock2),
        .axi_clk(axi_clk),
        .axi_reset_n(axi_reset_n),
        .axis_clk(axis_clk),
        .uck2_rst_n(uck2_rst_n),
        .axis_rst_n(axis_rst_n)
    );
    assign axis_clk     = axi_clk;
    assign axis_rst_n   = axi_reset_n; 

    //-axi lite control
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if (!axi_reset_n) 
        begin
            axi_awvalid <= 0;
            axi_wvalid  <= 0;
            axi_arvalid <= 0;
            axi_rready  <= 0;
        end else 
        begin 
            if (axi_awready) 
            begin
                axi_awvalid <= 0;
                axi_awaddr  <= 0;
            end
            if (axi_wready) 
            begin
                axi_wvalid  <= 0;
                axi_wdata   <= 0;
            end
            if (axi_arready) 
            begin
                axi_arvalid <= 0;   // invaldiated araddr
                axi_araddr  <= 32'h0;
            end
            if (axi_rready) 
            begin
                axi_rready  <= 0;   
            end
        end
    end
    always 
        #50 axi_clk = ~axi_clk;

    // configuration write 
    task configure_write;
        input [31:0] addr;
        input [31:0] data;
    begin
        @(posedge axi_clk);
        axi_awvalid <= 1;
        axi_wvalid  <= 1;
        axi_wdata   <= data;
        axi_awaddr  <= addr;
        //fork addr & data
        fork
            begin
                while( !axi_awready) @(posedge axi_clk);
                axi_awvalid <= 0;
                axi_awaddr  <= 0;
            end 
            begin
                while( !axi_wready) @(posedge axi_clk)
                axi_wvalid  <= 0;
                axi_wdata   <= 0;
            end
        join
    end
    endtask

    task configure_read;
        input [31:0] addr;
        input [31:0] exp_data;
        input [31:0] vld_bit;
        begin

            @(posedge axi_clk);
            axi_arvalid <= 1;
            axi_araddr  <= addr;

            fork
                begin   
                    while( !axi_arready) @(posedge axi_clk);
                    axi_arvalid <= 0;
                    axi_araddr  <= 0;
                end
                begin  
                    // wait for rvalid, rdata
                    axi_rready  <= 1;
                    while( !axi_rvalid ) @(posedge axi_clk);
                    axi_rready  <= 0;

                    // check rdata == exp_data
                    if( (axi_rdata & vld_bit) !== exp_data ) 
                        $display(" ERROR: exp_data %h != rdata %h", exp_data, axi_rdata);
                    else 
                        $display("    OK: exp_data %h == rdata %h", exp_data, axi_rdata);
                end
            join
        end
    endtask



reg [31:0] trace_mem[0:4095];
reg [11:0] wptr, rptr;
reg [12:0] dptr;  // count
initial 
begin
    wptr = 0;
    rptr = 0;
    dptr = 0;
end

// task: push_trace_mem
task push_trace_mem;
    input [31:0] trace;
    output  status;         // status = 1; fifo full
    begin
        status = 0;
        if( dptr == 12'hfff)  
            status = 1;
        else 
        begin  
            trace_mem[wptr] = trace;
            wptr = wptr + 1'b1;
            dptr = dptr + 1;
        end
    end
endtask

// task: pop_trace_mem
task pop_trace_mem;
    output [31:0] trace;
    output  status;         // status = 1; fifo empty
    begin
        status = 0;
        if( dptr == 12'h0)  
            status = 1;
        else 
        begin  
            trace = trace_mem[rptr];
            rptr = rptr + 1'b1;
            dptr = dptr - 1;
        end
    end
endtask

// Generate_trace & push to push_mem
task generate_trace;
    input [9:0]     rc;
    input [23:0]    signal;
    reg  status;
    begin
        repeat( rc ) @(posedge axi_clk);
        begin
            push_trace_mem(signal, status);
            up_la_data <= signal;
        end
    end
endtask 



//--------------------------------------------------------------------------------------------------
// Dynamic adjust m_tready wait-state
reg [9:0] tready_ws; // controlled by testbench zero-wait 
reg [9:0]  ws_count; // local variable to count wait-state

//  waveform
//  tws = 0; zero-state
//          |   |   |   |   |
// m_tvalid _/----------
// m_tready _/---------- 
// ws=0

//  tws = 1; 1 wait-state
//          |   |   |   |   |
// m_tvalid _/----------
// m_tready _/---\__/---\___
// ws        1---0--0---0--

//  tws = 1; 1 wait-state
//          |   |   |   |   |
// m_tvalid _/----------
// m_tready _/---\__/---\___
// ws        1---0--overflow-

reg         fifo_empty_status;
reg [31:0]  exp_trace;
always @(posedge axi_clk or negedge axi_reset_n) 
begin
    if( !axi_reset_n) 
    begin
        m_tready <= 0;   
        ws_count <= tready_ws;
    end 
    else 
    begin
        if( ws_count >= 1) 
        begin
            m_tready <= 0;
            if(tready_ws > 0) 
                ws_count = ws_count - 1;
        end 
        else 
        begin 
            m_tready <= 1; // (tready_ws = 0 | (m_tvalid & m_tready) != 1) , ws = 0 --> wait state is zero , and initial wait state is zero or ready & valid is zero 
            if( m_tvalid & m_tready) 
            begin

                if( tready_ws > 0) //issue : will ws_count = 0 , tws > 0 ,ws_count overflow?
                begin
                    m_tready <= 0;
                    ws_count <= tready_ws - 1;
                end
            end 
        end
    end
end


always @(posedge axi_clk) 
begin
    if( m_tvalid & m_tready) 
    begin
        auto_check(m_tdata[31:24],m_tdata[23:0]);
    end
end


/******************  Auto Check  
     trace_mem[9:4096] : keep all trace signals
     1. every cycle push trace-signal to trace_mem
     2. when LA output (m_tvalid), check m_tdata
        LA data format 
        [23:0]  signals
        [31:24] repeat_count
        if (repeat_count == 0)   // overflow - drop it
            overflow <= 1;      // mark overflow 
        else begin
            if( overflow ) begin    // overflow handling
               pop trace_mem until it matches m_tdata    - find sync point
               if pop & reach empty nd of trace_mem -> report error -> $stop
               overflow <= 0;
            end begin
                for ( repeat_count ) pop trace_mem and compare tdata with trace_mem
                if mismatch -> $stop, $display error
*/

task auto_check;
    input [9:0]     rc;
    input [23:0]    signal;
    reg overflow;
    reg status;
    reg[23:0] exp_signal;
    begin
        if(rc == 0) 
            overflow <= 1;
        else
        begin
            if(overflow)
            begin

            end
            else
            begin
                repeat( rc ) @(posedge axi_clk);
                begin
                    pop_trace_mem(exp_signal,status);
                    if( exp_signal != signal ) 
                        begin
                        $display(" ERROR: exp_signal %h != signal %h", exp_signal, signal);
                        $stop;
                        end
                    else 
                        $display("    OK: exp_signal %h == signal %h", exp_signal, signal);
                end
            end
        end
    end
endtask 

//--------------------------------------------------------------------------------------------------
integer i;
// --- Test Start Here ------
    initial begin
        tready_ws = 3;
        axi_clk = 1'b0;
        up_la_data = 24'd0;
        axi_reset_n = 1'b0;
        cc_la_enable = 1'b0;        
        axi_awvalid = 1'b0;
        axi_awaddr = 32'b0;
        axi_wvalid = 1'b0;
        axi_wdata = 32'b0;
        axi_wstrb = 4'b0;
        axi_arvalid = 1'b0;
        axi_araddr = 32'b0;
        axi_rready = 1'b0;        
        m_tready=0;
        
        repeat (10) @(posedge axi_clk);
        axi_reset_n = 1'b1;    
        

        //-------------------configure the logic analyzer--------------------
        //la_enable <= 1'b1;
        cc_la_enable = 1; 
        configure_write(32'h3000_1000, 32'hffffffff);
        //h_thresh <= 7'h3F;
        configure_write(32'h30001004, 32'h0000003F);
        
        //l_thresh <= 7'h3F;
        configure_write(32'h30001008, 32'h0000003F);

        //pop_cond <= 7'h3F;
        configure_write(32'h3000100C, 32'h0000003F);

        //enable_la <= 1
        configure_write(32'h30001010, 32'h00000001);

        // configuration read to check 
        configure_read(32'h3000_1000, 32'h00ffffff, 32'h00ffffff);
/*
        //h_thresh <= 7'h3F;
        configure_write(32'h30001004, 32'h0000003F, 32'h000000ff);
        
        //l_thresh <= 7'h3F;
        configure_write(32'h30001008, 32'h0000003F, 32'h000000ff);

        //pop_cond <= 7'h3F;
        configure_write(32'h3000100C, 32'h0000003F, 32'h000000ff);

        //enable_la <= 1
        configure_write(32'h30001010, 32'h00000001, 32'h00000001);
*/

        repeat (5) @(posedge axi_clk);
        $display("Monitoring started");

        // Basic test
        // 1. enable_la  - soft reset
        // 2. la_enable  - only selected signal will be monitored
        // 3. overflow
        // 4. random test with different la_enable

    // 1. la_enable - only selected signal will be monitored
    /*
        configure_write(32'h3000_1000, 32'h005a5a5a);       // la_enable
        generate_trace(1, 24'h00005a);
        generate_trace(1, 24'h0000ff);         // signal not monitored
        generate_trace(1, 24'h000055);          // push 5a rc=2
    */

    // overflow Test
    //   - need to control m_tready
    //     configuration tready_ws : set larger value
    //  for( tready_ws = 5, 10, 15, 20, 20 .. )
    //   for( 100 trace)
        configure_write(32'h3000_1000, 32'hffffffff);   // la_enable
    for(i = 0;i<100;i=i+1)
        generate_trace(1, 24'h000055 + i);

    // 4. random test with different la_enable
    //  for(  random la_enable)   
    //    for( loop 1000 )

        $finish;
    end
endmodule
    

        