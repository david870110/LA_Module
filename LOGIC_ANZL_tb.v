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

    wire axi_awready;
    wire axi_wready;
    wire axi_arready;
    wire [31 : 0] axi_rdata;
    wire axi_rvalid;
    reg axi_awvalid;
    reg [14 : 0] axi_awaddr;
    reg axi_wvalid;
    reg [31 : 0] axi_wdata;
    reg [3 : 0] axi_wstrb;
    reg axi_arvalid;
    reg [14 : 0] axi_araddr;
    reg axi_rready;
    reg cc_la_enable;
    reg enable_la;
    wire [31 : 0] m_tdata;
    wire [3 : 0] m_tstrb;
    wire [3 : 0] m_tkeep;
    wire m_tlast;
    wire m_tvalid;
    wire [1 : 0] m_tuser;
    wire la_hpri_req;
    reg m_tready;//wire
    reg [23 : 0] up_la_data;
    wire user_clock2;
    reg axi_clk;
    reg axi_reset_n;
    wire axis_clk;
    wire uck2_rst_n;
    wire axis_rst_n;

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
        .enable_la(enable_la),
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

 

    // 簡化的AXI-Lite主機處理邏輯
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if (!axi_reset_n) begin
            axi_awvalid <= 0;
            axi_wvalid <= 0;
            axi_arvalid <= 0;
            axi_rready <= 0;
        end else begin 
            // 寫地址通道
            //if (axi_awvalid && axi_awready) begin
            if (axi_awready) begin
                axi_awvalid <= 0;
                axi_awaddr <= 0;
            end

            // 寫數據通道
            //if (axi_wvalid && axi_wready) begin
            if (axi_wready) begin
                axi_wvalid <= 0;
                axi_wdata <= 0;
            end

            // 讀地址通道
            //if (axi_arvalid && axi_arready) begin
            if (axi_arready) begin
                axi_arvalid <= 0;
            end

            // 讀數據通道
            //if (axi_rvalid && axi_rready) begin
            if (axi_rready) begin
                axi_rready <= 0;
            end
        end
    end

    assign axis_clk = axi_clk;
    assign axis_rst_n = axi_reset_n; 

    always 
        #50 axi_clk = ~axi_clk;

    reg [31:0] golden_mem[0:4095];
    task generate_cycles;
        input [15:0] num_cycles;
        input delay_mode;    
        input [5:0] delay_cycles;
        input [23:0] base;
        output integer total_cycles;

        reg [23:0] data;
        integer i, j;
        reg [5:0] delay;
    
        begin
            j = 0;
            total_cycles =0;
            for (i = 0; i < num_cycles; i = i + 1) begin    
                if (delay_mode) begin
                    delay = delay_cycles;
                end else begin
                    delay = $random;
                    $display("Random cycle: %d", delay);
                    if (delay <= 1)
                        delay = delay_cycles;           
                end
                total_cycles = total_cycles + delay;          
                data = i + 1 + base;               
                // 生成實際輸入
                repeat(delay) @(posedge axi_clk)begin
                    up_la_data = data;
                    golden_mem[j] = data;
                    j=j+1;
                end
                $display("i:  %d, data:  %h", i, data);
                $display("------------------------------");
            end

        end     
    endtask


    task axi_master_write_and_read();
        input [31:0] addr;
        input [31:0] data;
    begin
        repeat (10) @(posedge axi_clk);
        @(posedge axi_clk)
        begin
            cc_la_enable <= 1'b1;
            enable_la = 1'b1;
            axi_awvalid <= 1'b1;
            axi_awaddr <= addr;
            axi_wdata <= data;
            axi_wvalid <= 1'b1;           
        end
        
        repeat (10) @(posedge axi_clk);
        @(posedge axi_clk)
        begin
            cc_la_enable <= 1'b1;
            enable_la = 1'b1;
            axi_arvalid <= 1'b1;
            axi_araddr <= addr;       
        end
        
        @(posedge axi_rvalid);
        $display("Write address: %x, data: %x", addr, data);
        $display("Read data: %x", axi_rdata);
        if (axi_rdata == data)
            $display("Matched");
        else
            $display("Mismatched");
        $display("------------------------------");
    end
    endtask
    localparam MAX_COMPRESSED_SIZE = 256;
    reg [31:0] compressed_mem [0:MAX_COMPRESSED_SIZE-1];
    reg [8:0] compressed_index;  // 改為 9 位，範圍 0 到 255
    
    always @(posedge axi_clk or negedge axi_reset_n) begin
        if (!axi_reset_n) begin
            compressed_index <= 0;
        end else begin
            if (m_tready && m_tvalid) begin
                //$display("Received compressed data: %x", m_tdata);
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
                //$display("Decompressing index %d: %x", i, compressed_mem[i]);
                repeat_count = compressed_mem[i][31:24];
                data = compressed_mem[i][23:0];
                for (j = 0; j < repeat_count && output_index < 4096; j = j + 1) begin
                    //$display("Output_mem[%d] = %h", output_index, data);
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

    integer test_data;
    integer total_cycles;
    initial begin
        axi_clk = 1'b0;
        up_la_data = 24'd8787;
        axi_reset_n = 1'b0;
        cc_la_enable = 1'b0;        
        enable_la = 1'b0;
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
        //axi_master_write_and_read(32'h30001004, 32'h0000003F);
        
        //l_thresh <= 7'h3F;
        //axi_master_write_and_read(32'h30001008, 32'h0000003F);

        //pop_cond <= 7'h3F;
        //axi_master_write_and_read(32'h3000100C, 32'h0000003F);

        repeat (100) @(posedge axi_clk);
        $display("Monitoring started");

        repeat (15) @(posedge axi_clk);
        @(posedge axi_clk)
        generate_cycles(16'd200, 1'b0, 6'h3F, 24'h0,total_cycles); //random delay
        //generate_cycles(16'd10, 1'b1, 6'h10, 24'h0,total_cycles); //random delay
        $display("Total cycles: %d", total_cycles);
        //cc_la_enable = 1'b0;        
        //enable_la = 1'b0;

         @(posedge axi_clk);m_tready=1;
        repeat (10000) @(posedge axi_clk);
        decompress_data();
        
        compare_data(total_cycles);     

        $finish;
    end
endmodule
    

        