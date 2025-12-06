module timer (
    input wire clk,
    input wire rst_n,
    input wire [2:0] current_state, // FSM 상태
    input wire o_system_init,
    
    output reg [3:0] countdown_val, // 3, 2, 1 표시용
    output reg countdown_done,      // 카운트다운 종료 신호

    output reg [2:0] stage,
    output reg [15:0] play_time,     // 게임 플레이 시간 (초 단위)
    output reg stage_cleared
);
    
    localparam S_IDLE      = 3'b000;
    localparam S_COUNTDOWN = 3'b001;
    localparam S_RUN       = 3'b010;
    localparam S_OVER  = 3'b011;
    localparam S_STAGE_CLEAR = 3'b100;
    localparam S_GAME_CLEAR = 3'b101;

    parameter DELAY = 50_000_000;
 
    parameter STAGE_DURATION = 10;

    reg [31:0] cnt;
    wire tick_1s = (cnt == DELAY - 1);

    always @(posedge clk or posedge rst_n) begin
        if (rst_n)
            cnt <= 32'd0;
        else begin
            if (current_state == S_IDLE)
                cnt <= 32'd0;
            else if (countdown_done)
                cnt <= 32'd0;
            else if (cnt >= DELAY - 1)
                cnt <= 32'd0;
            else
                cnt <= cnt + 1;
        end
    end
    // 메인 타이머 로직
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            countdown_val <= 3;
            countdown_done <= 0;
            play_time <= 0;
            stage <= 0;
            stage_cleared <= 0;
        end else begin
            stage_cleared <= 0;
            case (current_state)
                S_COUNTDOWN: begin
                    play_time <= 0;
                    countdown_done <= 0;
                    if (tick_1s) begin
                        if (countdown_val > 1) begin
                            countdown_val <= countdown_val - 1;
                        end else begin
                            countdown_val <= 0;
                            countdown_done <= 1; // 0이 되면 완료 신호 [cite: 76]
                        end
                    end
                end
                S_RUN: begin
                    countdown_done <= 0; // 리셋
                    if (tick_1s) begin
                        play_time <= play_time + 1;
                        if ((play_time + 1) % STAGE_DURATION == 0) begin
                            if (stage < 4) begin
                                stage_cleared <= 1;
                                stage <= stage + 1;
                            end else if (stage == 4) begin
                                stage_cleared <= 1;
                            end
                        end
                    end
                end
                default: begin
                // IDLE 등에서는 초기값 유지
                    countdown_val <= 3;
                    play_time <= 0;
                end
            endcase
            if (o_system_init) begin
                countdown_val <= 3;
                play_time <= 0;
                stage <= 1;
                countdown_done <= 0;
            end
        end
    end
endmodule
