module Timer (
    input wire clk,
    input wire rst,
    input wire tick_1hz,       // 1초 단위 펄스 (From Clock_Divider)
    input wire [1:0] current_state, // FSM 상태
    
    output reg [3:0] o_time,   // 현재 시간 (표시용)
    output reg o_timer_done    // 카운트다운 종료 알림
);

    localparam IDLE = 2'b00;
    localparam COUNTDOWN = 2'b01;
    localparam RUN = 2'b10;
    localparam GAMEOVER = 2'b11;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_time <= 3;
            o_timer_done <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    o_time <= 3;
                    o_timer_done <= 0;
                end
                COUNTDOWN: begin
                    if (tick_1hz) begin
                        if (o_time > 1) begin
                            o_time <= o_time - 1; // 3->2->1 
                        end else begin
                            o_time <= 0;
                            o_timer_done <= 1;
                        end
                    end
                end
                RUN: begin
                end
                GAMEOVER: begin
                end
                
                default: o_time <= 3;
            endcase
        end
    end
    
endmodule
