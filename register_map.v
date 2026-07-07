`timescale 1ns / 1ps

module register_map (
    input  wire        clk,
    input  wire        rst_n,

    // Giao tiếp với SPI Interface (Bus điều khiển ghi/đọc)
    input  wire [15:0] rx_data,
    input  wire [7:0]  rx_addr,
    input  wire        wr_en,
    output reg  [15:0] tx_data,

    // Giao tiếp với Trigger Unit
    input  wire [11:0] trig_pos,
    
    // Giao tiếp với Measurement Unit
    input  wire [15:0] vpp_res,
    input  wire [15:0] max_res,
    input  wire [15:0] min_res,
    
    // Giao tiếp với Statistics Unit
    input  wire [15:0] mean_res,
    input  wire [15:0] count_res,
    
    // Giao tiếp với FFT Coprocessor & Ngắt
    input  wire        fft_done_flag,

    // Tín hiệu đầu ra cấu hình (Config)
    output wire [3:0]  cfg_mode,
    output wire [3:0]  cfg_en_modules, 
    output wire [15:0] cfg_trigger_th
);

    // =========================================================
    // Định nghĩa Bản đồ Địa chỉ (Address Map)
    // =========================================================
    // Thanh ghi cấu hình (Read/Write)
    localparam ADDR_CFG_MODE    = 8'h00;
    localparam ADDR_CFG_EN      = 8'h01;
    localparam ADDR_CFG_TRIG    = 8'h02;
    
    // Thanh ghi trạng thái và kết quả (Read-Only)
    localparam ADDR_STATUS      = 8'h10;
    localparam ADDR_TRIG_POS    = 8'h11;
    localparam ADDR_VPP         = 8'h12;
    localparam ADDR_MAX         = 8'h13;
    localparam ADDR_MIN         = 8'h14;
    localparam ADDR_MEAN        = 8'h15;
    localparam ADDR_COUNT       = 8'h16;

    // =========================================================
    // Khai báo Thanh ghi Nội bộ
    // =========================================================
    reg [3:0]  reg_cfg_mode;
    reg [3:0]  reg_cfg_en_modules;
    reg [15:0] reg_cfg_trigger_th;

    // Gán tín hiệu ra liên tục (Continuous Assignment)
    assign cfg_mode       = reg_cfg_mode;
    assign cfg_en_modules = reg_cfg_en_modules;
    assign cfg_trigger_th = reg_cfg_trigger_th;

    // =========================================================
    // Logic Ghi (Write Logic) - Đồng bộ theo xung nhịp
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Trạng thái reset mặc định an toàn
            reg_cfg_mode       <= 4'b0000;
            reg_cfg_en_modules <= 4'b0000;
            reg_cfg_trigger_th <= 16'h0000;
        end else begin
            if (wr_en) begin
                case (rx_addr)
                    ADDR_CFG_MODE:    reg_cfg_mode       <= rx_data[3:0];
                    ADDR_CFG_EN:      reg_cfg_en_modules <= rx_data[3:0]; // Từng bit kích hoạt từng khối
                    ADDR_CFG_TRIG:    reg_cfg_trigger_th <= rx_data;
                    // Các địa chỉ cấu hình khác nếu có
                    default: ; // Không làm gì nếu ghi vào địa chỉ Read-Only hoặc không tồn tại
                endcase
            end
        end
    end

    // =========================================================
    // Logic Đọc (Read Logic) - Tổ hợp (Combinational)
    // =========================================================
    // Dữ liệu đọc được phản hồi ngay lập tức để khối SPI kịp thời 
    // đẩy lên MOSI trong chu kỳ SPI tiếp theo.
    always @(*) begin
        case (rx_addr)
            // Đọc lại cấu hình hiện tại
            ADDR_CFG_MODE:    tx_data = {12'h000, reg_cfg_mode};
            ADDR_CFG_EN:      tx_data = {12'h000, reg_cfg_en_modules};
            ADDR_CFG_TRIG:    tx_data = reg_cfg_trigger_th;
            
            // Đọc trạng thái & Kết quả
            ADDR_STATUS:      tx_data = {15'h0000, fft_done_flag}; 
            ADDR_TRIG_POS:    tx_data = {4'h0, trig_pos};
            ADDR_VPP:         tx_data = vpp_res;
            ADDR_MAX:         tx_data = max_res;
            ADDR_MIN:         tx_data = min_res;
            ADDR_MEAN:        tx_data = mean_res;
            ADDR_COUNT:       tx_data = count_res;
            
            // Mặc định trả về 0 nếu địa chỉ không hợp lệ
            default:          tx_data = 16'h0000;
        endcase
    end

endmodule