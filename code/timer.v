module timer (
    input wire clk,
    input wire rst_n,
    input wire [1:0] current_state, // FSM 상태
    
    output reg [3:0] countdown_val, // 3, 2, 1 표시용
    output reg countdown_done,      // 카운트다운 종료 신호
    output reg [2:0] stage,
    output reg [15:0] play_time     // 게임 플레이 시간 (초 단위)
);
    
    localparam S_IDLE = 2'b00;
    localparam S_COUNTDOWN = 2'b01;
    localparam S_RUN  = 2'b10;
    localparam S_OVER = 2'b11;

    parameter DELAY = 50_000_000;

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
            stage <= 1;
        end else begin
            case (current_state)
                S_COUNTDOWN: begin
                    if (tick_1s) begin
                        if (countdown_val > 1) 
                            countdown_val <= countdown_val - 1;
                        else begin
                            countdown_val <= 0;
                            countdown_done <= 1; // 0이 되면 완료 신호 [cite: 76]
                        end
                    end
                end
                S_RUN: begin
                    countdown_done <= 0; // 리셋
                    if(stage == 0)
                        stage = 1;
                    else if(play_time / 60 + 1 > stage)
                        stage = stage + 1;
                    if (tick_1s) 
                        play_time <= play_time + 1; // [cite: 81] 카운트업
                end
                default: begin
                // IDLE 등에서는 초기값 유지
                    countdown_val <= 3;
                    play_time <= 0;
                end
            endcase
        end
    end
endmodule
