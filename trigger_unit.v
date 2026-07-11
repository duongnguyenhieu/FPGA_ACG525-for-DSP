/*-------------------------------------------------------------------------
 * Module: trigger_unit
 * Project: Thiết bị Đo lường Số Mini Cấu hình bằng Phần mềm
 * Developer: Dương Nguyễn Hiếu
 * Affiliation: VNU-UET / SISLAB
 * Description: Trigger Unit với Hysteresis và tùy chọn Sườn (Edge Select)
 *-------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module trigger_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,             // Kích hoạt toàn mạch

    // Giao tiếp luồng dữ liệu (Theo dõi trực tiếp dữ liệu đang ghi vào RAM)
    input  wire [15:0] data_in,        // Dữ liệu mẫu hiện tại
    input  wire [11:0] current_addr,   // Địa chỉ đang ghi vào Frame Buffer

    // Cấu hình từ Register Map
    input  wire [15:0] cfg_th_upper,   // Ngưỡng trên (Hysteresis)
    input  wire [15:0] cfg_th_lower,   // Ngưỡng dưới (Hysteresis)
    input  wire [1:0]  cfg_edge,       // 00: Rising, 01: Falling, 10: Any Edge

    // Output
    output reg         trig_detected,  // Xung báo hiệu Trigger
    output reg  [11:0] trig_pos        // Lưu vị trí Trigger (Tâm điểm)
);

    // Trạng thái FSM
    localparam IDLE      = 2'b00;
    localparam ARMED     = 2'b01;
    localparam TRIGGERED = 2'b10;

    reg [1:0] state;
    
    // Các cờ trạng thái "Đã nạp đạn" cho từng loại sườn
    reg armed_for_rising;
    reg armed_for_falling;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= IDLE;
            trig_detected     <= 1'b0;
            trig_pos          <= 12'd0;
            armed_for_rising  <= 1'b0;
            armed_for_falling <= 1'b0;
        end else begin
            trig_detected <= 1'b0; // Tạo xung pulse 1 nhịp

            case (state)
                IDLE: begin
                    if (en) begin
                        state <= ARMED;
                        armed_for_rising  <= 1'b0;
                        armed_for_falling <= 1'b0;
                    end
                end

                ARMED: begin
                    if (!en) begin
                        state <= IDLE;
                    end else begin
                        // 1. Logic "Nạp đạn" (Arming) dựa trên Hysteresis
                        // Tín hiệu phải rớt xuống dưới ngưỡng dưới mới sẵn sàng bắt sườn lên
                        if (data_in <= cfg_th_lower) armed_for_rising <= 1'b1;
                        // Tín hiệu phải vượt lên trên ngưỡng trên mới sẵn sàng bắt sườn xuống
                        if (data_in >= cfg_th_upper) armed_for_falling <= 1'b1;

                        // 2. Logic Kích hoạt (Triggering)
                        if ((cfg_edge == 2'b00 || cfg_edge == 2'b10) && armed_for_rising && (data_in >= cfg_th_upper)) begin
                            // Rising Edge
                            trig_detected <= 1'b1;
                            trig_pos      <= current_addr;
                            state         <= TRIGGERED;
                        end 
                        else if ((cfg_edge == 2'b01 || cfg_edge == 2'b10) && armed_for_falling && (data_in <= cfg_th_lower)) begin
                            // Falling Edge
                            trig_detected <= 1'b1;
                            trig_pos      <= current_addr;
                            state         <= TRIGGERED;
                        end
                    end
                end

                TRIGGERED: begin
                    if (!en) state <= IDLE; // Giữ nguyên đến khi MCU reset khối
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule