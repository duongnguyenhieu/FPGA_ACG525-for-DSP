`timescale 1ns / 1ps

module spi_slave_interface_tb;

    // Khai báo các tín hiệu kết nối với Device Under Test (DUT)
    reg         clk;
    reg         rst_n;
    reg         spi_sclk;
    reg         spi_cs_n;
    reg         spi_mosi;
    wire        spi_miso;
    reg  [15:0] tx_data;
    wire [15:0] rx_data;
    wire [7:0]  rx_addr;
    wire        wr_en;

    // Khởi tạo Module SPI Slave (DUT)
    spi_slave_interface dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .spi_sclk   (spi_sclk),
        .spi_cs_n   (spi_cs_n),
        .spi_mosi   (spi_mosi),
        .spi_miso   (spi_miso),
        .tx_data    (tx_data),
        .rx_data    (rx_data),
        .rx_addr    (rx_addr),
        .wr_en      (wr_en)
    );

    // 1. Tạo xung nhịp hệ thống (FPGA Clock) - Giả sử 50MHz (Chu kỳ 20ns)
    initial clk = 0;
    always #10 clk = ~clk;

    // 2. Task mô phỏng quá trình truyền SPI của MCU (SPI Master)
    // Tốc độ SPI giả lập là 10MHz (Chu kỳ 100ns -> Nửa chu kỳ là 50ns)
    task spi_master_transfer;
        input [7:0]  target_addr;
        input [15:0] target_data;
        reg   [23:0] shift_out;
        integer i;
        begin
            shift_out = {target_addr, target_data}; // Nối thành khung 24-bit
            spi_cs_n = 0;                           // Kéo CS xuống thấp để bắt đầu
            #50;                                    // Đợi một chút trước khi cấp SCLK
            
            // Dịch 24 bit, từ MSB đến LSB (Mode 0)
            for (i = 23; i >= 0; i = i - 1) begin
                spi_mosi = shift_out[i];            // Đặt dữ liệu lên MOSI
                #50 spi_sclk = 1;                   // Kéo SCLK lên cao (Slave sẽ lấy mẫu ở sườn này)
                #50 spi_sclk = 0;                   // Kéo SCLK xuống thấp
            end
            
            #50 spi_cs_n = 1;                       // Kết thúc giao dịch, kéo CS lên cao
            #100;                                   // Nghỉ giữa các khung truyền
        end
    endtask

    // 3. Kịch bản Mô phỏng (Test Scenario)
    initial begin
        // Thiết lập file xuất dạng sóng (Waveform Dump)
        $dumpfile("waves.vcd");
        $dumpvars(0, spi_slave_interface_tb);

        // Khởi tạo giá trị ban đầu
        rst_n = 0;
        spi_sclk = 0;
        spi_cs_n = 1;
        spi_mosi = 0;
        tx_data = 16'hAAAA; // Dữ liệu giả lập từ Register Map đẩy ra
        
        // Nhả Reset sau 100ns
        #100 rst_n = 1;
        #100;

        // --- GIAO DỊCH 1 ---
        // MCU Ghi dữ liệu 0x1234 vào địa chỉ 0x05
        $display("[%0t] Bat dau Giao dich 1", $time);
        spi_master_transfer(8'h05, 16'h1234);
        
        // --- GIAO DỊCH 2 ---
        // Thay đổi dữ liệu TX từ Register Map để kiểm tra đường MISO
        tx_data = 16'h55AA;
        // MCU Ghi dữ liệu 0xDEAD vào địa chỉ 0x0A
        $display("[%0t] Bat dau Giao dich 2", $time);
        spi_master_transfer(8'h0A, 16'hDEAD);

        // Đợi thêm một chút để quan sát wr_en pulse rồi kết thúc
        #200;
        $display("[%0t] Ket thuc Mo phong", $time);
        $finish;
    end

endmodule