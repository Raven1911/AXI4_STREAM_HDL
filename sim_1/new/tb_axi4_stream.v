`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2026 11:58:02 PM
// Design Name: 
// Module Name: tb_axi4_stream
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


module tb_axi4_stream();
    parameter DATA_WIDTH_BYTE = 2;
    parameter SIZE_FIFO = 3; 
    parameter CLK_PERIOD = 10;

    reg aclk, aresetn;
    wire user_m_busy;
    reg user_m_wr, user_m_tlast;
    reg [DATA_WIDTH_BYTE*8-1:0] user_m_data;
    reg [DATA_WIDTH_BYTE-1:0] user_m_strb, user_m_keep;

    wire m_s_tvalid, m_s_tready, m_s_tlast;
    wire [DATA_WIDTH_BYTE*8-1:0] m_s_tdata;
    wire [DATA_WIDTH_BYTE-1:0] m_s_tstrb, m_s_tkeep;

    wire user_s_ready, user_s_tlast;
    reg user_s_rd;
    wire [DATA_WIDTH_BYTE*8-1:0] user_s_data_o;
    wire [DATA_WIDTH_BYTE-1:0] user_s_tstrb_o, user_s_tkeep_o;

    // DUT Master
    axi4_stream #(.DATA_WIDTH_BYTE(DATA_WIDTH_BYTE), .SELECT_INTERFACE(0), .SIZE_FIFO(SIZE_FIFO)) 
    DUT_M (.aclk_i(aclk), .aresetn_i(aresetn), .m_tvalid_o(m_s_tvalid), .m_tready_i(m_s_tready), .m_tdata_o(m_s_tdata), .m_tstrb_o(m_s_tstrb), .m_tkeep_o(m_s_tkeep), .m_tlast_o(m_s_tlast), .user_m_busy_o(user_m_busy), .user_m_wr_data_i(user_m_wr), .user_m_data_i(user_m_data), .user_m_tstrb_i(user_m_strb), .user_m_tkeep_i(user_m_keep), .user_m_tlast_i(user_m_tlast), .s_tready_o(), .user_s_ready_o(), .user_s_data_o());

    // DUT Slave
    axi4_stream #(.DATA_WIDTH_BYTE(DATA_WIDTH_BYTE), .SELECT_INTERFACE(1), .SIZE_FIFO(SIZE_FIFO)) 
    DUT_S (.aclk_i(aclk), .aresetn_i(aresetn), .s_tvalid_i(m_s_tvalid), .s_tready_o(m_s_tready), .s_tdata_i(m_s_tdata), .s_tstrb_i(m_s_tstrb), .s_tkeep_i(m_s_tkeep), .s_tlast_i(m_s_tlast), .user_s_ready_o(user_s_ready), .user_s_rd_data_i(user_s_rd), .user_s_data_o(user_s_data_o), .user_s_tstrb_o(user_s_tstrb_o), .user_s_tkeep_o(user_s_tkeep_o), .user_s_tlast_o(user_s_tlast), .m_tvalid_o(), .user_m_busy_o());

    initial begin aclk = 0; forever #(CLK_PERIOD/2) aclk = ~aclk; end

    integer i;

    initial begin
        aresetn = 0; user_m_wr = 0; user_m_data = 0; user_m_tlast = 0;
        user_m_strb = 2'b11; user_m_keep = 2'b11; user_s_rd = 0;
        #(CLK_PERIOD * 5); aresetn = 1;

        // 1. Single
        $display("CASE 1: Single");
        @(posedge aclk); user_m_wr = 1; user_m_data = 16'hAAAA; user_m_tlast = 1;
        @(posedge aclk); user_m_wr = 0;
        repeat(5) @(posedge aclk);
        if (user_s_ready) begin user_s_rd = 1; @(posedge aclk); user_s_rd = 0; end

        // 2. Burst
        $display("CASE 2: Burst");
        for(i=0; i<4; i=i+1) begin
            @(posedge aclk); user_m_wr = 1; user_m_data = i; user_m_tlast = (i==3);
        end
        @(posedge aclk); user_m_wr = 0;
        repeat(10) begin @(posedge aclk); if(user_s_ready) user_s_rd = 1; else user_s_rd = 0; end
        user_s_rd = 0;

        // 3. Full FIFO
        $display("CASE 3: Full FIFO");
        for(i=0; i<10; i=i+1) begin
            @(posedge aclk); if(!user_m_busy) begin user_m_wr = 1; user_m_data = i + 20; end
        end
        @(posedge aclk); user_m_wr = 0;
        repeat(12) begin @(posedge aclk); if(user_s_ready) user_s_rd = 1; else user_s_rd = 0; end

        // 4. Simultaneous
        $display("CASE 4: Simultaneous");
        fork
            for(i=0; i<5; i=i+1) begin @(posedge aclk); user_m_wr=1; user_m_data=i+50; end
            repeat(3) @(posedge aclk);
            for(i=0; i<5; i=i+1) begin @(posedge aclk); user_s_rd=1; end
        join
        user_m_wr=0; user_s_rd=0;

        // 5. Continuous Master
        $display("CASE 5: Continuous Master");
        user_m_wr=1;
        for(i=0; i<20; i=i+1) begin
            user_m_data = i+100;
            @(posedge aclk); while(user_m_busy) @(posedge aclk);
        end
        user_m_wr=0;
        repeat(20) @(posedge aclk);

        // 6. Max Throughput (FULL SPEED)
        $display("CASE 6: Max Throughput");
        user_m_wr = 1; user_s_rd = 1;
        for(i=0; i<30; i=i+1) begin
            user_m_data = i+200; user_m_tlast = (i%5==4);
            @(posedge aclk); while(user_m_busy) @(posedge aclk);
        end
        user_m_wr = 0;
        repeat(10) @(posedge aclk);
        user_s_rd = 0;

        $display("--- SUCCESS: ALL CASES COMPLETED ---");
        $finish;
    end
endmodule