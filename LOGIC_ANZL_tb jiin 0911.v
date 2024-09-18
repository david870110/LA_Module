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
    wire [31:0] axi_rdata;
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


    integer decompressed_count;

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
    assign axis_clk = axi_clk;
    assign axis_rst_n = axi_reset_n; 

    //-axi lite control
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if (!axi_reset_n) 
        begin
            axi_awvalid <= 0;
            axi_wvalid <= 0;
            axi_arvalid <= 0;
            axi_rready <= 0;
        end else 
        begin 
            if (axi_awready) 
            begin
                axi_awvalid <= 0;
                axi_awaddr <= 0;
            end
            if (axi_wready) 
            begin
                axi_wvalid <= 0;
                axi_wdata <= 0;
            end
            if (axi_arready) begin
                axi_arvalid <= 0;   // invaldiated araddr
                axi_araddr <= 32'h0;
            end
            if (axi_rready) begin
                axi_rready <= 0;    // invalidate rdata
                axi_rdata <= 32'h0;
            end
        end
    end



    always 
        #50 axi_clk = ~axi_clk;

    reg [31:0] golden_mem[0:4095];
    // generate trace_packet task
    task new_data;
        input rc_count_mode;     // Jiin: add comment
        input [5:0] rc_count_nums;
        input [23:0] generate_data;

        reg [5:0] repeat_cycle;
    
        begin
            // rc_count_mode = 0 is random mode, it will generate random cycle, and it will exclude 0 cycle. -JIANG
            if (rc_count_mode) repeat_cycle = rc_count_nums;
            else 
            begin
                repeat_cycle = $random;
                if (repeat_cycle <= 1)
                    repeat_cycle = 1;           
            end     
            repeat(repeat_cycle) @(posedge axi_clk)
                up_la_data <= generate_data;         // Jiin : use non-blocking
            $display("cycle : %h    data:  %h",repeat_cycle, generate_data);
            $display("------------------------------");
        end     
    endtask

    // configuration write 
    task configuration_write;
        input [31:0] addr;
        input [31:0] data;
    begin
        @(posedge axi_clk);
        axi_awvalid <= 1;
        axi_wvalid <= 1;
        axi_awdata <= data;
        axi_awaddr <= addr;

        fork
            begin
                while( !axi_awready) @(posedge axi_clk);
                axi_awvalid <= 0;
                axi_awaddr <= 0;
            end 
            begin
                while( !axi_wready) @(posedge axi_clk)
                axi_wvalid <= 0;
                axi_wdata <= 0;
            end
        end
    endtask

    task configuration_read;
        input [31:0] addr;
        input [31:0] exp_data;
        input [31:0] vld_bit;
    begin

        @(posedge axi_clk);
        axi_arvalid <= 1;
        axi_araddr <= addr;

        fork
            begin   
                while( !axi_arready) @(posedge axi_clk);
                axi_arvalid <= 0;
                axi_araddr <= 0;
            end
            begin  // wait for rvalid, rdata
                axi_rready <= 1;
                while( !axi_rvalid ) @(posedge axi_clk);
                axi_rready <= 0;

                // check rdata == exp_data
                if( (axi_rdata & vld_bit) !== exp_data ) begin
                    $display(" ERROR: exp_data %h != rdata %h", exp_data, axi_rdata);
                end else begin 
                    $display("    OK: exp_data %h != rdata %h", exp_data, axi_rdata);
                end
            end
        join
    end



    endtask


/***************
    // software program data(axi-lite)
    task axi_master_write_and_read();
        input [31:0] addr;
        input [31:0] data;
    begin
        cc_la_enable <= 1'b1;
        repeat (10) @(posedge axi_clk);
        @(posedge axi_clk)
        begin
            axi_awaddr <= addr;
            axi_wdata <= data;
            axi_awvalid <= 1'b1;
            axi_wvalid <= 1'b1;           
        end
        
        repeat (10) @(posedge axi_clk);
        @(posedge axi_clk)
        begin
            axi_arvalid <= 1'b1;
            axi_araddr <= addr;       
        end
    end
    endtask
*********************



/*
    localparam MAX_COMPRESSED_SIZE = 256;
    reg [31:0] compressed_mem [0:MAX_COMPRESSED_SIZE-1];
    reg [8:0] compressed_index;
    
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if (!axi_reset_n) begin
            compressed_index <= 0;
        end else begin
            if (m_tready && m_tvalid) begin
                if (compressed_index < MAX_COMPRESSED_SIZE) begin
                    compressed_mem[compressed_index] <= m_tdata;
                    compressed_index <= compressed_index + 1;
                end 
            end 
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
    
    reg [31:0] output_mem [0:4095];
    task decompress_data;
        integer i, j;
        reg [23:0] data;
        reg [7:0] repeat_count;
        integer output_index;
        begin
            output_index = 0;
            for (i = 0; i < compressed_index; i = i + 1) begin
                repeat_count = compressed_mem[i][31:24];
                data = compressed_mem[i][23:0];
                for (j = 0; j < repeat_count && output_index < 4096; j = j + 1) begin
                    output_mem[j+output_index] = {8'b0, data};
                end
                output_index = output_index + repeat_count;
            end
            $display("Decompression completed. Total output size: %d", output_index);
        end
    endtask
    

    
    task compare_data;
        integer i;
        integer mismatch_count;
        integer first_data;
        integer first_data_found;
        input integer total_cycles;
        begin
            mismatch_count = 0;
            first_data = 0;
            first_data_found = 0;

            for (i = 0; i < total_cycles; i = i + 1) begin
                if (!first_data_found && output_mem[i] == 32'd1) begin
                    first_data = i;
                    first_data_found = 1;
                    $display("First data found at index %d", first_data);   
                end

                if (first_data_found && output_mem[i + first_data] !== golden_mem[i]) begin
                    $display("Mismatch at index %d: Output = %h, Golden = %h", i, output_mem[i + first_data], golden_mem[i]);
                    mismatch_count = mismatch_count + 1;
                end
            end
            
            if (mismatch_count == 0)
                $display("All data matched successfully!");
            else
                $display("%d mismatches found.", mismatch_count);
        end
    endtask
*/
    integer test_data;
    integer total_cycles;
    integer repeat_data;

reg [11:0] wptr; rptr;
reg [12:0] dptr;  // count
intial begin
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
    if( dptr == 12'hfff) begin 
        status = 1;
    end else begin  
        trace_mem[wptr] = trace;
        wptr = wptr + 1'b1;
        dptr = dptr + 1;
    end

end

// task: pop_trace_mem


// Generate_trace
// 1. 
// 
task generate_trace;
    input [9:0]     rc;
    input [23:0]    signal;
begin
    integer i_rc;
    reg  status;

    repeat( rc ) begin
        push_trace_mem(signal, status);
        up_la_data <= signal;
    end

endtask 

// Dynamic adjust m_tready wait-state
reg [9:0] tready_ws;  initial tready_ws = 0;     // controlled by testbench zero-wait 
reg [9:0]  ws_count;                          // local variable to count wait-state

//  waveform
//  tws = 0; zero-state
//          |   |   |   |   |
// m_tvalid _/----------
// m_tready _/---------- 
// ws=0
//  tws = 1 : 1 wait-state
//          |   |   |   |   |
// m_tvalid _/----------
// m_tready _----\__/---\___
// ws         1--0-- 0---0--


always @(posedge axi_clk or negedge axi_reset_n) begin
    if( !axi_reset_n) begin
        axi_mtready <= 0;   
        ws_count <= tready_ws;
    end else begin
        if( ws_count >= 1) begin
            axi_mtready <= 0;
            if(tready_ws > 0) begin
                ws_count = ws_count - 1;
            end 
        end else begin 
            axi_mtready <= 1;
            if( axi_mtvalid & axi_mtready) begin
                if( tready_ws > 0) begin
                    axi_mtready <= 0;
                    ws_count <= tready_ws - 1;
                end
            end 
    end
end

// --- Test Start Here ------
    initial begin
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
        decompressed_count =0;
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

        //h_thresh <= 7'h3F;
        configure_write(32'h30001004, 32'h0000003F, 32'h000000ff);
        
        //l_thresh <= 7'h3F;
        configure_write(32'h30001008, 32'h0000003F, 32'h000000ff);

        //pop_cond <= 7'h3F;
        configure_write(32'h3000100C, 32'h0000003F, 32'h000000ff);

        //enable_la <= 1
        configure_write(32'h30001010, 32'h00000001, 32'h00000001);
    

        repeat (5) @(posedge axi_clk);
        $display("Monitoring started");

        // Basic test
        // 1. enable_la  - soft reset
        // 2. la_enable  - only selected signal will be monitored
        // 3. overflow
        // 4. random test with different la_enable

    // 1. la_enable - only selected signal will be monitored
        configure_write(32'h3000_1000, 32'h005a5a5a);       // la_enable
        generate_trace(1, 24'h00005a);
        generate_trace(1, 24'h0000ff);         // signal not monitored
        generate_trace(1, 24'h000055);          // push 5a rc=2

    // overflow Test
    //   - need to control m_tready
    //     configuration tready_ws : set larger value
    //  for( tready_ws = 5, 10, 15, 20, 20 .. )
    //   for( 100 trace)

    // 4. random test with different la_enable
    //  for(  random la_enable)   
    //    for( loop 1000 )
        

        repeat (15) @(posedge axi_clk);
        // - param(rc_count mode(0 = random) , rc , generate_data data)
        for(repeat_data=0;repeat_data<200;repeat_data=repeat_data+1)begin
            new_data(1'b1, 6'h1, 24'h0 + repeat_data);
        end
/*
        $display("Total cycles: %d", total_cycles);    

        @(posedge axi_clk); m_tready=1;
        repeat (10000) @(posedge axi_clk);
        decompress_data();
        
        compare_data(total_cycles);     
*/
        $finish;
    end
endmodule
    

        