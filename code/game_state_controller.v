module game_state_controller (
    input wire clk,                 // 시스템 클럭
    input wire rst_n,               // 비동기 리셋 (Active Low) - 시스템 리셋
    input wire i_btn_start,         // 입력: 게임 시작 버튼 (Debounced) 
    input wire i_countdown_done,    // 입력: Timer로부터 3초 카운트 완료 신호 
    input wire i_collision,         // 입력: Collision Detector로부터 충돌 감지 신호 
    input wire i_stage_cleared, 
    input wire [2:0] stage,
    
    output reg [2:0] current_state, // 현재 상태 출력 (다른 모듈 제어용)
    output reg o_system_init,       // IDLE 상태에서 내부 레지스터 초기화 신호 
    output reg o_game_active        // 게임 진행 중 (RUN) 신호
);

    // -------------------------------------------------------
    // State Definition 
    // -------------------------------------------------------
    localparam S_IDLE      = 3'b000;
    localparam S_COUNTDOWN = 3'b001;
    localparam S_RUN       = 3'b010;
    localparam S_GAMEOVER  = 3'b011;
    localparam S_STAGE_CLEAR = 3'b100;
    localparam S_GAME_CLEAR = 3'b101;

    reg [2:0] next_state;
    
    reg [31:0] delay_cnt;
    parameter STAGE_CLEAR_DELAY = 100_000_000;
    // -------------------------------------------------------
    // Sequential Logic: State Register
    // ------------------------------------------------------- 
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            delay_cnt <= 0;
        end else if (next_state != S_STAGE_CLEAR) begin
            delay_cnt <= 0;
        end else if (delay_cnt < STAGE_CLEAR_DELAY) begin
            delay_cnt <= delay_cnt + 1;
        end
    end

    // -------------------------------------------------------
    // Combinational Logic: Next State Logic
    // -------------------------------------------------------
    always @(*) begin
        // Default assignment
        next_state = current_state;

        case (current_state)
            // [state] IDLE 
            // 시작 신호가 감지되면 COUNTDOWN으로 전이
            S_IDLE: begin
                if (i_btn_start) 
                    next_state = S_COUNTDOWN;
                else
                    next_state = S_IDLE;
            end

            // [state] COUNTDOWN 
            // 3초 카운트다운 완료(Timer 신호)되면 RUN으로 전이
            S_COUNTDOWN: begin
                if (i_countdown_done)
                    next_state = S_RUN;
                else
                    next_state = S_COUNTDOWN;
            end

            // [state] RUN 
            // 충돌 신호(Collision)가 수신되면 GAMEOVER로 전이
            S_RUN: begin
                if (i_collision)
                    next_state = S_GAMEOVER;
                else if (i_stage_cleared) begin
                    if (stage < 4)
                        next_state = S_STAGE_CLEAR;
                    else
                        next_state = S_GAME_CLEAR;
                end else
                    next_state = S_RUN;
            end
            
            S_STAGE_CLEAR: begin
                if (delay_cnt >= STAGE_CLEAR_DELAY)
                    next_state = S_COUNTDOWN;
                else
                    next_state = S_STAGE_CLEAR;
            end
            
            S_GAME_CLEAR: begin
                next_state = S_GAME_CLEAR;
            end

            // [state] GAMEOVER 
            S_GAMEOVER: begin
                // rst_n이 눌리기 전까지 대기 (Source 98 기준)
                if (i_btn_start)
                    next_state = S_IDLE;
                else
                    next_state = S_GAMEOVER; 
            end
                // 만약 Source 104(자동 IDLE 복귀)를 따르고 싶다면:
                // next_state = S_IDLE; 
            
            default: next_state = S_IDLE;
        endcase
    end

    // -------------------------------------------------------
    // Output Logic: Control Signals per State
    // -------------------------------------------------------
    always @(*) begin
        // 기본값 설정 (Latch 방지)
        o_system_init = 1'b0;
        o_game_active = 1'b0;

        case (current_state)
            S_IDLE: begin
                // 모든 내부 레지스터를 '0'으로 비동기 리셋
                o_system_init = 1'b1; 
            end

            S_COUNTDOWN: begin
                // 타이머 활성화 (카운트다운 모드)
            end

            S_RUN: begin
                // 모든 게임 로직 모듈 활성화
                o_game_active = 1'b1; // Character, Obstacle 제어용
            end

            S_STAGE_CLEAR, S_GAME_CLEAR, S_GAMEOVER: begin
                // RUN state의 모든 동작 정지
                o_game_active = 1'b0;
                // LCD Controller에게 'Game Over' 출력 지시 (current_state로 판별)
            end
        endcase
    end

endmodule
