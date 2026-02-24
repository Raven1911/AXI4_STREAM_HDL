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

    // Parameters
    parameter DATA_WIDTH_BYTE = 2;
    parameter SIZE_FIFO = 3; // FIFO depth = 2^3 = 8 để dễ test tràn
    parameter CLK_PERIOD = 10;

    // Common Signals
    reg aclk;
    reg aresetn;

    // Master User Interface Signals
    wire user_m_busy;
    reg  user_m_wr;
    reg  [DATA_WIDTH_BYTE*8-1:0] user_m_data;
    reg  [DATA_WIDTH_BYTE-1:0]   user_m_strb;
    reg  [DATA_WIDTH_BYTE-1:0]   user_m_keep;
    reg  user_m_last;

    // AXI-Stream Intermediate Signals (Nối Master với Slave)
    wire m_s_tvalid;
    wire m_s_tready;
    wire [DATA_WIDTH_BYTE*8-1:0] m_s_tdata;
    wire [DATA_WIDTH_BYTE-1:0]   m_s_tstrb;
    wire [DATA_WIDTH_BYTE-1:0]   m_s_tkeep;
    wire m_s_tlast;

    // Slave User Interface Signals
    wire user_s_ready;
    reg  user_s_rd;
    wire [DATA_WIDTH_BYTE*8-1:0] user_s_data;
    wire [DATA_WIDTH_BYTE-1:0]   user_s_tstrb;
    wire [DATA_WIDTH_BYTE-1:0]   user_s_tkeep;
    wire user_s_tlast;

    // 1. Instantiate Master Interface
    axi4_stream #(
        .DATA_WIDTH_BYTE(DATA_WIDTH_BYTE),
        .SELECT_INTERFACE(0),
        .SIZE_FIFO(SIZE_FIFO)
    ) DUT_MASTER (
        .aclk_i(aclk),
        .aresetn_i(aresetn),
        // AXI Out
        .m_tvalid_o(m_s_tvalid),
        .m_tready_i(m_s_tready),
        .m_tdata_o(m_s_tdata),
        .m_tstrb_o(m_s_tstrb),
        .m_tkeep_o(m_s_tkeep),
        .m_tlast_o(m_s_tlast),
        // User In
        .user_m_busy_o(user_m_busy),
        .user_m_wr_data_i(user_m_wr),
        .user_m_data_i(user_m_data),
        .user_m_tstrb_i(user_m_strb),
        .user_m_tkeep_i(user_m_keep),
        .user_m_tlast_i(user_m_last),
        // Unused Slave ports
        .s_tready_o(), .user_s_ready_o(), .user_s_data_o()
    );

    // 2. Instantiate Slave Interface
    axi4_stream #(
        .DATA_WIDTH_BYTE(DATA_WIDTH_BYTE),
        .SELECT_INTERFACE(1),
        .SIZE_FIFO(SIZE_FIFO)
    ) DUT_SLAVE (
        .aclk_i(aclk),
        .aresetn_i(aresetn),
        // AXI In
        .s_tvalid_i(m_s_tvalid),
        .s_tready_o(m_s_tready),
        .s_tdata_i(m_s_tdata),
        .s_tstrb_i(m_s_tstrb),
        .s_tkeep_i(m_s_tkeep),
        .s_tlast_i(m_s_tlast),
        // User Out
        .user_s_ready_o(user_s_ready),
        .user_s_rd_data_i(user_s_rd),
        .user_s_data_o(user_s_data),
        .user_s_tstrb_o(user_s_tstrb),
        .user_s_tkeep_o(user_s_tkeep),
        .user_s_tlast_o(user_s_tlast),
        // Unused Master ports
        .m_tvalid_o(), .user_m_busy_o()
    );

    // Clock Generation
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end

    // Helper Tasks
    task master_push(input [15:0] data, input last);
        begin
            @(posedge aclk);
            if (!user_m_busy) begin
                user_m_wr = 1;
                user_m_data = data;
                user_m_last = last;
                user_m_strb = 2'b11;
                user_m_keep = 2'b11;
            end
            @(posedge aclk);
            user_m_wr = 0;
        end
    endtask

    task slave_pop();
        begin
            @(posedge aclk);
            if (user_s_ready) begin
                user_s_rd = 1;
                $display("[%0t] Read Data: %h, Last: %b", $time, user_s_data, user_s_tlast);
            end
            @(posedge aclk);
            user_s_rd = 0;
        end
    endtask

    // Main Test Procedure
    initial begin
        // Initialize signals
        aresetn = 0;
        user_m_wr = 0;
        user_m_data = 0;
        user_m_last = 0;
        user_m_strb = 0;
        user_m_keep = 0;
        user_s_rd = 0;

        #(CLK_PERIOD * 5);
        aresetn = 1;
        $display("--- Reset Released ---");

        // --- CASE 1: Truyền đơn lẻ 1 data ---
        $display("\nTEST CASE 1: Single data transfer");
        master_push(16'hAAAA, 1);
        repeat(5) @(posedge aclk);
        slave_pop();

        // --- CASE 2: Truyền một gói tin (Burst) ---
        $display("\nTEST CASE 2: Burst packet transfer (4 beats)");
        master_push(16'h1111, 0);
        master_push(16'h2222, 0);
        master_push(16'h3333, 0);
        master_push(16'h4444, 1);
        
        repeat(10) @(posedge aclk);
        repeat(4) slave_pop();

        // --- CASE 3: Test tràn FIFO (Backpressure) ---
        // Đẩy 10 data vào khi FIFO chỉ chứa được 8, không đọc ra để Slave bận
        $display("\nTEST CASE 3: FIFO Full & Backpressure");
        repeat(10) begin
            master_push($random, 0);
            if (user_m_busy) $display("[%0t] Master FIFO Busy/Full!", $time);
        end

        // Bắt đầu đọc từ Slave để giải phóng hệ thống
        repeat(10) slave_pop();

        // --- CASE 4: Truyền nhận đồng thời (Simultaneous) ---
        $display("\nTEST CASE 4: Simultaneous Read and Write");
        fork
            begin
                repeat(5) master_push($random, 0);
            end
            begin
                repeat(2) @(posedge aclk);
                repeat(5) slave_pop();
            end
        join

        #(CLK_PERIOD * 20);
        $display("\n--- All tests finished ---");
        $finish;
    end

endmodule
