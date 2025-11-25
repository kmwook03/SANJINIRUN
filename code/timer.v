module timer (
    input wire clk,
    input wire rst_n,
    input wire i_enable,          // [추가] FSM이 보내는 활성화 신호 받기
    input wire [1:0] current_state, 
    
    output reg [3:0] countdown_val,
    output reg countdown_done,
    output reg [15:0] play_time
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
            // [수정] i_enable 신호가 1일 때만 동작하도록 변경
            if (i_enable) begin 
                if (current_state == 2'b01) begin // S_COUNTDOWN
                     // ... 카운트다운 로직 (기존과 동일)
                     if (tick_1s) begin
                        if (countdown_val > 0) countdown_val <= countdown_val - 1; // 0까지 가도록 수정
                        if (countdown_val == 1) countdown_done <= 1; // 1->0 넘어갈 때 완료 신호
                     end
                end else if (current_state == 2'b10) begin // S_RUN
                     // ... 플레이 시간 로직 (기존과 동일)
                end
            end else begin
                // 타이머 꺼짐 (IDLE 상태 등) -> 리셋
                countdown_val <= 3;
                countdown_done <= 0;
                // play_time은 유지하거나 리셋 (게임 기획에 따라 결정)
            end
        end
    end
endmodule
