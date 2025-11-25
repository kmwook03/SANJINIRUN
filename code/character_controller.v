module Character_Controller (
    input wire clk,              // 50MHz Clock
    input wire rst_n,            // Reset
    input wire tick_60hz,        // 애니메이션 프레임 (초당 60회)
    input wire jump_signal,      // 점프 버튼 입력 (Pulse)
    input wire [1:0] current_state, // 게임 상태 (IDLE, RUN...)
    
    output reg [7:0] o_char_y    // 캐릭터 Y 좌표 (0: 공중, 1: 바닥)
);

    // 상태 정의
    localparam IDLE      = 2'b00;
    localparam COUNTDOWN = 2'b01;
    localparam RUN       = 2'b10;
    localparam GAMEOVER  = 2'b11;

    // 점프 체공 시간 설정 (60Hz 기준)
    // 30 ticks = 0.5초 동안 공중에 머무름
    parameter JUMP_DURATION = 30; 

    reg [5:0] jump_timer; // 점프 시간 카운터
    reg is_jumping;       // 현재 점프 중인지 상태 플래그

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_char_y <= 1; // 바닥 초기화
            jump_timer <= 0;
            is_jumping <= 0;
        end else begin
            if (current_state == RUN) begin
                // 1. 점프 시작 로직 (바닥에 있을 때만 가능)
                if (jump_signal && !is_jumping) begin
                    is_jumping <= 1;
                    o_char_y <= 0; // 공중으로 이동
                    jump_timer <= 0;
                end

                // 2. 점프 유지 및 착지 로직
                if (is_jumping && tick_60hz) begin
                    if (jump_timer < JUMP_DURATION) begin
                        jump_timer <= jump_timer + 1;
                    end else begin
                        // 체공 시간 종료 -> 착지
                        is_jumping <= 0;
                        o_char_y <= 1; // 바닥으로 복귀
                        jump_timer <= 0;
                    end
                end
            end else begin
                // 게임 중이 아니면 항상 바닥 위치, 변수 초기화
                o_char_y <= 1;
                is_jumping <= 0;
                jump_timer <= 0;
            end
        end
    end

endmodule
