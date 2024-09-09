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
            if (axi_arready) axi_arvalid <= 0;
            if (axi_rready) axi_rready <= 0;
        end
    end



    always 
        #50 axi_clk = ~axi_clk;

    reg [31:0] golden_mem[0:4095];
    // generate trace_packet task
    task new_data;
        input rc_count_mode;    
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
                up_la_data = generate_data;
            $display("cycle : %h    data:  %h",repeat_cycle, generate_data);
            $display("------------------------------");
        end     
    endtask

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
        axi_master_write_and_read(32'h30001000, 32'hffffffff);

        //h_thresh <= 7'h3F;
        axi_master_write_and_read(32'h30001004, 32'h0000003F);
        
        //l_thresh <= 7'h3F;
        axi_master_write_and_read(32'h30001008, 32'h0000003F);

        //pop_cond <= 7'h3F;
        axi_master_write_and_read(32'h3000100C, 32'h0000003F);

        //enable_la <= 1
        axi_master_write_and_read(32'h30001010, 32'h00000001);

        repeat (5) @(posedge axi_clk);
        $display("Monitoring started");

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
    

        