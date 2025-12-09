module game_state_controller (
    input wire clk,                 // 시스템 클럭
    input wire rst_n,               // 비동기 리셋 (Active Low)
    input wire i_btn_start,         // 게임 시작 버튼
    input wire i_countdown_done,    // 3초 카운트 완료 신호
    input wire i_collision,         // 충돌 감지 신호
    input wire i_stage_cleared,     // 스테이지 클리어 신호
    input wire [2:0] stage,         // 현재 스테이지 정보
    
    // [수정] life는 내부에서 계산하여 LED로 보여주는 값이므로 Output이어야 합니다.
    output wire [4:0] life,         
    
    output reg [2:0] current_state, // 현재 상태 출력
    output reg o_system_init,       // 시스템 초기화 신호
    output reg o_game_active        // 게임 진행 중 신호
);

    // -------------------------------------------------------
    // State Definition 
    // -------------------------------------------------------
    localparam S_IDLE        = 3'b000;
    localparam S_COUNTDOWN   = 3'b001;
    localparam S_RUN         = 3'b010;
    localparam S_GAMEOVER    = 3'b011;
    localparam S_STAGE_CLEAR = 3'b100;
    localparam S_GAME_CLEAR  = 3'b101;

    reg [2:0] next_state;
    
    // 스테이지 클리어 딜레이용
    reg [31:0] delay_cnt;
    parameter STAGE_CLEAR_DELAY = 100_000_000; // 약 2초 (50MHz 기준)

    // -------------------------------------------------------
    // Internal Registers for Life Logic
    // ------------------------------------------------------- 
    reg [3:0] life_cnt;      // 실제 생명 개수 (0~3)
    reg prev_collision;      // 충돌 엣지 디텍션용

    // [LED 출력 연결] life_cnt 값에 따라 LED 켜기 (3개 -> 2개 -> 1개)
    assign life = (life_cnt >= 4'd5) ? 5'b11111 :
                  (life_cnt >= 4'd4) ? 5'b01111 :
                  (life_cnt >= 4'd3) ? 5'b00111 :
                  (life_cnt == 4'd2) ? 5'b00011 :
                  (life_cnt == 4'd1) ? 5'b00001 : 3'b00000;
    
    // -------------------------------------------------------
    // Sequential Logic: State Register & Life Control
    // ------------------------------------------------------- 
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            current_state  <= S_IDLE;
            life_cnt       <= 4'd5;  // 리셋 시 목숨 3개
            prev_collision <= 1'b0;
        end else begin
            // 1. 상태 전이
            current_state <= next_state;

            // 2. 충돌 감지 엣지 업데이트
            prev_collision <= i_collision;

            // 3. Life 관리 로직
            if (current_state == S_IDLE && i_btn_start) begin
                // 게임 새로 시작 시 목숨 충전
                life_cnt <= 4'd5; 
            end 
            else if (current_state == S_RUN) begin
                // RUN 상태에서 충돌 발생 (Rising Edge) 시 목숨 감소
                if (i_collision && !prev_collision) begin
                    if (life_cnt > 0) begin
                        life_cnt <= life_cnt - 1;
                    end
                end
            end
        end
    end
    
    // -------------------------------------------------------
    // Sequential Logic: Delay Counter (Stage Clear)
    // ------------------------------------------------------- 
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            delay_cnt <= 0;
        end else if (current_state != S_STAGE_CLEAR) begin // current_state로 변경 권장
            delay_cnt <= 0;
        end else if (current_state == S_STAGE_CLEAR && delay_cnt < STAGE_CLEAR_DELAY) begin
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
            S_IDLE: begin
                if (i_btn_start) 
                    next_state = S_COUNTDOWN;
            end

            // [state] COUNTDOWN 
            S_COUNTDOWN: begin
                if (i_countdown_done)
                    next_state = S_RUN;
            end

            // [state] RUN 
            S_RUN: begin
                // [수정됨] 충돌했다고 바로 게임오버가 아님. Life가 0이 되어야 게임오버.
                if (life_cnt == 0) begin
                    next_state = S_GAMEOVER;
                end 
                else if (i_stage_cleared) begin
                    if (stage < 4) // stage 3 클리어 시 엔딩이라고 가정 (0,1,2,3 -> 4단계면 <4가 맞음)
                        next_state = S_STAGE_CLEAR;
                    else
                        next_state = S_GAME_CLEAR;
                end 
                // Life가 남아있고 충돌했다면? -> 상태는 RUN 유지 (Life만 깎임)
                else begin
                    next_state = S_RUN;
                end
            end
            
            // [state] STAGE CLEAR (잠시 대기 후 다음 스테이지 카운트다운)
            S_STAGE_CLEAR: begin
                if (delay_cnt >= STAGE_CLEAR_DELAY)
                    next_state = S_COUNTDOWN;
            end
            
            // [state] GAME CLEAR (축하 화면 유지)
            S_GAME_CLEAR: begin
                // 리셋 버튼 누르기 전까지 유지
                 if (i_btn_start) // 혹은 특정 버튼으로 재시작 기능 추가 가능
                    next_state = S_IDLE;
            end

            // [state] GAMEOVER 
            S_GAMEOVER: begin
                if (i_btn_start) // 게임오버에서 시작 버튼 누르면 IDLE(초기화)로
                    next_state = S_IDLE;
            end
            
            default: next_state = S_IDLE;
        endcase
    end

    // -------------------------------------------------------
    // Output Logic: Control Signals per State
    // -------------------------------------------------------
    always @(*) begin
        // 기본값 설정
        o_system_init = 1'b0;
        o_game_active = 1'b0;

        case (current_state)
            S_IDLE: begin
                o_system_init = 1'b1; 
            end

            S_COUNTDOWN: begin
                // 필요한 경우 카운트다운 enable 신호 추가
            end

            S_RUN: begin
                o_game_active = 1'b1; // 장애물 이동, 캐릭터 점프 허용
            end

            S_STAGE_CLEAR, S_GAME_CLEAR, S_GAMEOVER: begin
                o_game_active = 1'b0; // 게임 정지
            end
        endcase
    end

endmodule
