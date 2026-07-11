`timescale 1ns / 1ps

module spi_slave_interface (
    // Tín hiệu toàn cục (Global Signals)
    input  wire        clk,         // Xung nhịp hệ thống (Ví dụ: 50MHz - 100MHz) [cite: 29]
    input  wire        rst_n,       // Reset bất đồng bộ tích cực mức thấp [cite: 29]

    // Giao tiếp SPI Vật lý (SPI Physical Interface)
    input  wire        spi_sclk,    // Xung nhịp từ MCU (10-20 Mbps) [cite: 14, 33]
    input  wire        spi_cs_n,    // Chip Select từ MCU [cite: 36]
    input  wire        spi_mosi,    // Dữ liệu nối tiếp từ MCU [cite: 37]
    output wire        spi_miso,    // Dữ liệu nối tiếp gửi về MCU 

    // Giao tiếp Nội bộ (Internal Interface)
    input  wire [15:0] tx_data,     // Dữ liệu từ Register Map chuẩn bị truyền cho MCU 
    output reg  [15:0] rx_data,     // Dữ liệu song song nhận được 
    output reg  [7:0]  rx_addr,     // Địa chỉ giải mã từ khung SPI 
    output reg         wr_en        // Tín hiệu cho phép ghi đồng bộ 
);

    // 1. Đồng bộ hóa tín hiệu SPI vào miền xung nhịp của FPGA (CDC)
    reg [2:0] sclk_sync;
    reg [2:0] cs_n_sync;
    reg [1:0] mosi_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 3'b111;
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], spi_sclk};
            cs_n_sync <= {cs_n_sync[1:0], spi_cs_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};
        end
    end

    // Phát hiện sườn xung SPI Clock và trạng thái CS
    wire sclk_rising  = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling = (sclk_sync[2:1] == 2'b10);
    wire cs_n_active  = ~cs_n_sync[1]; // CS tích cực mức thấp
    wire cs_n_rising  = (cs_n_sync[2:1] == 2'b01); // Kết thúc truyền

    // 2. Thanh ghi dịch (Shift Registers) và Bộ đếm bit
    reg [23:0] shift_reg_rx;
    reg [15:0] shift_reg_tx;
    reg [4:0]  bit_cnt;

    // Logic Đẩy dữ liệu ra (MISO) - Hoạt động ở sườn xuống SCLK
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg_tx <= 16'd0;
        end else if (!cs_n_active) begin
            // Nạp sẵn dữ liệu tx_data khi CS chưa kích hoạt
            shift_reg_tx <= tx_data;
        end else if (sclk_falling) begin
            // Dịch bit MSB ra MISO
            shift_reg_tx <= {shift_reg_tx[14:0], 1'b0};
        end
    end

    // Gán trực tiếp bit MSB của thanh ghi dịch TX ra MISO, dùng logic 3 trạng thái nếu CS không active
    assign spi_miso = cs_n_active ? shift_reg_tx[15] : 1'bz;

    // Logic Nhận dữ liệu (MOSI) - Hoạt động ở sườn lên SCLK
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg_rx <= 24'd0;
            bit_cnt      <= 5'd0;
        end else if (!cs_n_active) begin
            bit_cnt      <= 5'd0;
        end else if (sclk_rising) begin
            // Dịch bit MOSI vào LSB
            shift_reg_rx <= {shift_reg_rx[22:0], mosi_sync[1]};
            bit_cnt      <= bit_cnt + 1'b1;
        end
    end

    // 3. Logic chốt dữ liệu (Output Register)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 16'd0;
            rx_addr <= 8'd0;
            wr_en   <= 1'b0;
        end else begin
            // Mặc định hạ wr_en xuống 0 để tạo thành 1 xung (pulse) duy nhất
            wr_en <= 1'b0; 
            
            // Chốt dữ liệu khi CS kéo lên cao (kết thúc giao dịch) và đủ 24 bit
            if (cs_n_rising && (bit_cnt >= 5'd24)) begin
                rx_addr <= shift_reg_rx[23:16];
                rx_data <= shift_reg_rx[15:0];
                wr_en   <= 1'b1; 
            end
        end
    end

<<<<<<< HEAD
endmodule
=======
endmodule
>>>>>>> origin/main
