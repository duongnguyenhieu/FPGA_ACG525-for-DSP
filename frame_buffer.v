/*-------------------------------------------------------------------------
 * Module: frame_buffer
 * Description: Bộ đệm vòng (Circular Buffer) hỗ trợ Pre/Post-Triggering
 * Sử dụng IP Core Gowin_SDP (Gowin Simple Dual Port Block RAM)
 *-------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module frame_buffer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        acq_en,         // Lệnh bắt đầu thu thập từ MCU

    // Giao tiếp ghi từ SPI / ADC
    input  wire [15:0] spi_wr_data,
    input  wire        spi_wr_en,      // Xung clock báo có dữ liệu mới

    // Giao tiếp với Trigger Unit
    input  wire        trig_detected,  // Xung từ khối Trigger
    input  wire [11:0] cfg_post_depth, // Số mẫu muốn ghi tiếp SAU khi trigger
    
    // Output cho các khối xử lý và Trigger
    output wire [11:0] current_wr_addr,// Cấp cho Trigger chốt vị trí
    output reg         acq_done,       // Báo hiệu đã đóng băng khung dữ liệu

    // Giao tiếp Đọc (Measurement, FFT, MCU)
    input  wire [11:0] rd_addr,
    output wire [15:0] rd_data         // Đổi thành wire vì nối trực tiếp từ output của IP Core
);

    reg [11:0] wr_addr;
    reg [11:0] post_trigger_cnt;
    reg        post_trigger_active;
    reg        buffer_locked;

    assign current_wr_addr = wr_addr;

    // Tín hiệu enable thực tế để ghi vào RAM (chỉ ghi khi chưa bị khóa và hệ thống cho phép)
    wire actual_wr_en = spi_wr_en & (~buffer_locked) & acq_en;

    // =================================================================
    // Gọi module IP Core của Gowin (Gowin_SDP)
    // =================================================================
    Gowin_SDP your_bram_inst (
        .dout  (rd_data),       // Output: Dữ liệu đọc ra 16-bit
        .clka  (clk),           // Input: Xung nhịp cổng ghi A
        .cea   (actual_wr_en),  // Input: Cho phép ghi (Clock Enable A)
        .clkb  (clk),           // Input: Xung nhịp cổng đọc B
        .ceb   (1'b1),          // Input: Luôn cho phép đọc (Clock Enable B)
        .oce   (1'b0),          // Input: Output Clock Enable (0 = Bypass thanh ghi đầu ra)
        .reset (~rst_n),        // Input: Tín hiệu Reset (Gowin IP tích cực mức cao, nên đảo rst_n)
        .ada   (wr_addr),       // Input: Địa chỉ ghi 12-bit
        .din   (spi_wr_data),   // Input: Dữ liệu ghi 16-bit
        .adb   (rd_addr)        // Input: Địa chỉ đọc 12-bit
    );

    // =================================================================
    // Logic Quản lý Địa chỉ Ghi và Bộ đệm Vòng (Circular Buffer FSM)
    // =================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_addr             <= 12'd0;
            post_trigger_cnt    <= 12'd0;
            post_trigger_active <= 1'b0;
            buffer_locked       <= 1'b0;
            acq_done            <= 1'b0;
        end else begin
            if (!acq_en) begin
                // Reset trạng thái khi MCU yêu cầu thu thập lại
                wr_addr             <= 12'd0;
                post_trigger_active <= 1'b0;
                buffer_locked       <= 1'b0;
                acq_done            <= 1'b0;
            end else if (!buffer_locked) begin
                
                // Cập nhật địa chỉ vòng tròn khi có xung ghi
                if (spi_wr_en) begin
                    wr_addr <= wr_addr + 1'b1; // Tự tràn (overflow) ở 4095 về 0

                    // Đếm dữ liệu Post-trigger nếu đã nhận được cờ Trigger
                    if (post_trigger_active) begin
                        if (post_trigger_cnt == cfg_post_depth - 1'b1) begin
                            buffer_locked <= 1'b1; // Khóa Buffer
                            acq_done      <= 1'b1; // Báo hoàn thành cho MCU
                        end else begin
                            post_trigger_cnt <= post_trigger_cnt + 1'b1;
                        end
                    end
                end

                // Bắt sự kiện Trigger để khởi động bộ đếm Post-trigger
                if (trig_detected && !post_trigger_active) begin
                    post_trigger_active <= 1'b1;
                    post_trigger_cnt    <= 12'd0;
                end
            end
        end
    end

endmodule