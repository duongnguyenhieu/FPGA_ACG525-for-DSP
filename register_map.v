<<<<<<< HEAD
/*-------------------------------------------------------------------------
 * Module: register_map
 * Description: Khối Bản đồ Thanh ghi Cấu hình và Trạng thái.
 * Đã cập nhật hỗ trợ Hysteresis Trigger và Pre/Post-Triggering.
 *-------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module register_map (
    input  wire        clk,
    input  wire        rst_n,

    // Giao tiếp với SPI Interface (Bus điều khiển ghi/đọc)
    input  wire [15:0] rx_data,
    input  wire [7:0]  rx_addr,
    input  wire        wr_en,
    output reg  [15:0] tx_data,

    // Giao tiếp dữ liệu kết quả từ các khối xử lý
    input  wire [11:0] trig_pos,
    input  wire [15:0] vpp_res,
    input  wire [15:0] max_res,
    input  wire [15:0] min_res,
    input  wire [15:0] mean_res,
    input  wire [15:0] count_res,
    input  wire        fft_done_flag,

    // Tín hiệu đầu ra cấu hình (Config) cấp cho các khối
    output wire [3:0]  cfg_mode,
    output wire [3:0]  cfg_en_modules, 
    
    // Cấu hình Trigger & Frame Buffer mở rộng
    output wire [15:0] cfg_th_upper,
    output wire [15:0] cfg_th_lower,
    output wire [1:0]  cfg_edge,
    output wire [11:0] cfg_post_depth
);

    // =========================================================
    // Định nghĩa Bản đồ Địa chỉ (Address Map)
    // =========================================================
    // Thanh ghi cấu hình (Read/Write)
    localparam ADDR_CFG_MODE       = 8'h00;
    localparam ADDR_CFG_EN         = 8'h01;
    localparam ADDR_CFG_TH_UPPER   = 8'h02; // Ngưỡng trên (Hysteresis)
    localparam ADDR_CFG_TH_LOWER   = 8'h03; // Ngưỡng dưới (Hysteresis)
    localparam ADDR_CFG_EDGE       = 8'h04; // Chọn sườn (00: Lên, 01: Xuống, 10: Cả hai)
    localparam ADDR_CFG_POST_DEPTH = 8'h05; // Độ sâu lấy mẫu sau Trigger

    // Thanh ghi trạng thái và kết quả (Read-Only)
    localparam ADDR_STATUS         = 8'h10;
    localparam ADDR_TRIG_POS       = 8'h11;
    localparam ADDR_VPP            = 8'h12;
    localparam ADDR_MAX            = 8'h13;
    localparam ADDR_MIN            = 8'h14;
    localparam ADDR_MEAN           = 8'h15;
    localparam ADDR_COUNT          = 8'h16;

    // =========================================================
    // Khai báo Thanh ghi Nội bộ
    // =========================================================
    reg [3:0]  reg_cfg_mode;
    reg [3:0]  reg_cfg_en_modules;
    reg [15:0] reg_cfg_th_upper;
    reg [15:0] reg_cfg_th_lower;
    reg [1:0]  reg_cfg_edge;
    reg [11:0] reg_cfg_post_depth;

    // Gán tín hiệu ra liên tục (Continuous Assignment)
    assign cfg_mode       = reg_cfg_mode;
    assign cfg_en_modules = reg_cfg_en_modules;
    assign cfg_th_upper   = reg_cfg_th_upper;
    assign cfg_th_lower   = reg_cfg_th_lower;
    assign cfg_edge       = reg_cfg_edge;
    assign cfg_post_depth = reg_cfg_post_depth;

    // =========================================================
    // Logic Ghi (Write Logic) - Đồng bộ theo xung nhịp
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Trạng thái reset mặc định an toàn
            reg_cfg_mode       <= 4'b0000;
            reg_cfg_en_modules <= 4'b0000;
            reg_cfg_th_upper   <= 16'h0000;
            reg_cfg_th_lower   <= 16'h0000;
            reg_cfg_edge       <= 2'b00;    // Mặc định sườn lên
            reg_cfg_post_depth <= 12'd2048; // Mặc định 50% khung (giả sử BRAM 4096)
        end else begin
            if (wr_en) begin
                case (rx_addr)
                    ADDR_CFG_MODE:       reg_cfg_mode       <= rx_data[3:0];
                    ADDR_CFG_EN:         reg_cfg_en_modules <= rx_data[3:0];
                    ADDR_CFG_TH_UPPER:   reg_cfg_th_upper   <= rx_data;
                    ADDR_CFG_TH_LOWER:   reg_cfg_th_lower   <= rx_data;
                    ADDR_CFG_EDGE:       reg_cfg_edge       <= rx_data[1:0];
                    ADDR_CFG_POST_DEPTH: reg_cfg_post_depth <= rx_data[11:0];
                    default: ; // Bỏ qua nếu ghi vào địa chỉ Read-Only hoặc không tồn tại
                endcase
            end
        end
    end

    // =========================================================
    // Logic Đọc (Read Logic) - Tổ hợp (Combinational)
    // =========================================================
    always @(*) begin
        case (rx_addr)
            // Đọc lại cấu hình hiện tại
            ADDR_CFG_MODE:       tx_data = {12'h000, reg_cfg_mode};
            ADDR_CFG_EN:         tx_data = {12'h000, reg_cfg_en_modules};
            ADDR_CFG_TH_UPPER:   tx_data = reg_cfg_th_upper;
            ADDR_CFG_TH_LOWER:   tx_data = reg_cfg_th_lower;
            ADDR_CFG_EDGE:       tx_data = {14'h0000, reg_cfg_edge};
            ADDR_CFG_POST_DEPTH: tx_data = {4'h0, reg_cfg_post_depth};

            // Đọc trạng thái & Kết quả
            ADDR_STATUS:         tx_data = {15'h0000, fft_done_flag};
            ADDR_TRIG_POS:       tx_data = {4'h0, trig_pos};
            ADDR_VPP:            tx_data = vpp_res;
            ADDR_MAX:            tx_data = max_res;
            ADDR_MIN:            tx_data = min_res;
            ADDR_MEAN:           tx_data = mean_res;
            ADDR_COUNT:          tx_data = count_res;
            
            // Mặc định trả về 0 nếu địa chỉ không hợp lệ
            default:             tx_data = 16'h0000;
        endcase
    end

=======
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

>>>>>>> origin/main
endmodule
