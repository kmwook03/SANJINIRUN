module timer (
    input wire clk,
    input wire rst_n,
    input wire [1:0] current_state, // FSM 상태
    
    output reg [3:0] countdown_val, // 3, 2, 1 표시용
    output reg countdown_done,      // 카운트다운 종료 신호
    output reg [15:0] play_time     // 게임 플레이 시간 (초 단위)
);
    localparam S_COUNTDOWN = 2'b01;
    localparam S_RUN       = 2'b10;
    
    // 1초 생성을 위한 카운터 (50MHz 기준: 50,000,000 - 1)
    reg [25:0] clk_cnt;
    wire tick_1s = (clk_cnt == 26'd49_999_999);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_cnt <= 0;
        else if (clk_cnt >= 26'd49_999_999) clk_cnt <= 0;
        else clk_cnt <= clk_cnt + 1;
    end

    // 메인 타이머 로직
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            countdown_val <= 3;
            countdown_done <= 0;
            play_time <= 0;
        end else begin
            if (current_state == S_COUNTDOWN) begin
                if (tick_1s) begin
                    if (countdown_val > 1) 
                        countdown_val <= countdown_val - 1;
                    else begin
                        countdown_val <= 0;
                        countdown_done <= 1; // 0이 되면 완료 신호 [cite: 76]
                    end
                end
            end else if (current_state == S_RUN) begin
                countdown_done <= 0; // 리셋
                if (tick_1s) 
                    play_time <= play_time + 1; // [cite: 81] 카운트업
            end else begin
                // IDLE 등에서는 초기값 유지
                countdown_val <= 3;
                play_time <= 0;
            end
        end
    end
endmodule