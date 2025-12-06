module sound_controller (
    input wire clk,             // 50MHz System Clock
    input wire rst,             // Active High Reset
    input wire i_btn_jump,      // 1일 때 점프
    input wire i_collision,     // 1일 때 충돌 (게임오버)
    input wire [2:0] current_state, // 외부 FSM의 현재 상태
    input wire i_stage_cleared, // 1일 때 스테이지 클리어
    
    output reg piezo_out        // 피에조 스피커 출력
);

    // ... (파라미터 정의는 기존과 동일하게 유지) ...
    // [기존] 점프 & 게임오버 톤
    localparam TONE_JUMP_1 = 18'd38_000; 
    localparam TONE_JUMP_2 = 18'd19_000; 
    
    localparam TONE_OVER_1 = 18'd28_400; 
    localparam TONE_OVER_2 = 18'd37_900; 
    localparam TONE_OVER_3 = 18'd56_800; 

    // [기존] 스테이지 클리어 톤
    localparam TONE_CLEAR_1 = 18'd19_111; 
    localparam TONE_CLEAR_2 = 18'd17_026; 
    localparam TONE_CLEAR_3 = 18'd15_168; 

    localparam TONE_VIC_1 = 18'd31_888; 
    localparam TONE_VIC_2 = 18'd25_310; 
    localparam TONE_VIC_3 = 18'd21_280; 
    localparam TONE_VIC_4 = 18'd15_944; 
    
    // 시간 상수
    localparam TIME_JUMP   = 25'd4_000_000;  
    localparam TIME_OVER   = 25'd10_000_000; 
    localparam TIME_CLEAR  = 25'd5_000_000; 
    localparam TIME_VIC_S  = 25'd4_000_000; 
    localparam TIME_VIC_L  = 25'd25_000_000;

    // 상태 정의
    localparam S_IDLE      = 4'd0;
    localparam S_JUMP_1    = 4'd1;
    localparam S_JUMP_2    = 4'd2;
    localparam S_OVER_1    = 4'd3;
    localparam S_OVER_2    = 4'd4;
    localparam S_OVER_3    = 4'd5;
    
    localparam S_CLEAR_1   = 4'd6;
    localparam S_CLEAR_2   = 4'd7;
    localparam S_CLEAR_3   = 4'd8;

    localparam S_VIC_1     = 4'd9;
    localparam S_VIC_2     = 4'd10;
    localparam S_VIC_3     = 4'd11;
    localparam S_VIC_4     = 4'd12;

    localparam STATE_GAME_CLEAR_VAL = 3'b101; 

    // 내부 레지스터
    reg [3:0] state; 
    reg [17:0] tone_cnt;        
    reg [17:0] tone_target;     
    reg [24:0] duration_cnt;    

    reg btn_prev; 
    reg stage_cleared_prev; 
    reg [2:0] current_state_prev; 

    // =======================================================
    // 3. 소리 시퀀스 제어
    // =======================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            duration_cnt <= 0;
            tone_target <= 0;
            btn_prev <= 0;
            stage_cleared_prev <= 0;
            current_state_prev <= 0;
        end else begin
            // 엣지 디텍션 업데이트
            btn_prev <= i_btn_jump;
            stage_cleared_prev <= i_stage_cleared;
            current_state_prev <= current_state;

            // =========================================================
            // [수정 완료] 우선순위 및 트리거 로직 개선
            // =========================================================

            // 1순위: 충돌 발생 시 "시작" 트리거 (이미 게임오버 진행 중이면 무시하고 else로 넘어감)
            // 조건: 충돌 신호 ON AND (아직 게임오버 상태 아님)
            if (i_collision && (state < S_OVER_1 || state > S_OVER_3)) begin 
                state <= S_OVER_1;
                duration_cnt <= TIME_OVER;
                tone_target <= TONE_OVER_1;
            end
            
            // 2순위: 게임 전체 클리어 트리거
            else if (current_state == STATE_GAME_CLEAR_VAL && current_state_prev != STATE_GAME_CLEAR_VAL) begin
                state <= S_VIC_1;
                duration_cnt <= TIME_VIC_S;
                tone_target <= TONE_VIC_1;
            end
            
            // 3순위: 상태 머신 실행 (카운터 감소 및 상태 전이)
            // 위 두 조건에 해당하지 않거나, 이미 소리가 재생 중일 때 이곳이 실행됨
            else begin
                case (state)
                    // ------------------------------------
                    // 대기 상태
                    // ------------------------------------
                    S_IDLE: begin
                        tone_target <= 0;

                        // 스테이지 클리어
                        if (i_stage_cleared && !stage_cleared_prev) begin
                            state <= S_CLEAR_1;
                            duration_cnt <= TIME_CLEAR;
                            tone_target <= TONE_CLEAR_1;
                        end
                        // 점프 버튼
                        else if (i_btn_jump && !btn_prev) begin
                            state <= S_JUMP_1;
                            duration_cnt <= TIME_JUMP;
                            tone_target <= TONE_JUMP_1;
                        end
                    end

                    // ... (나머지 로직은 그대로) ...
                    
                    S_JUMP_1: begin
                        if (duration_cnt == 0) begin
                            state <= S_JUMP_2;
                            duration_cnt <= TIME_JUMP;
                            tone_target <= TONE_JUMP_2;
                        end else duration_cnt <= duration_cnt - 1;
                    end

                    S_JUMP_2: begin
                        if (duration_cnt == 0) begin
                            state <= S_IDLE; 
                        end else duration_cnt <= duration_cnt - 1;
                    end

                    S_CLEAR_1: begin
                        if (duration_cnt == 0) begin
                            state <= S_CLEAR_2;
                            duration_cnt <= TIME_CLEAR;
                            tone_target <= TONE_CLEAR_2;
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    S_CLEAR_2: begin
                        if (duration_cnt == 0) begin
                            state <= S_CLEAR_3;
                            duration_cnt <= TIME_CLEAR;
                            tone_target <= TONE_CLEAR_3;
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    S_CLEAR_3: begin
                        if (duration_cnt == 0) begin
                            state <= S_IDLE;
                        end else duration_cnt <= duration_cnt - 1;
                    end

                    // 게임 클리어 시퀀스
                    S_VIC_1: begin
                        if (duration_cnt == 0) begin
                            state <= S_VIC_2;
                            duration_cnt <= TIME_VIC_S;
                            tone_target <= TONE_VIC_2; 
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    S_VIC_2: begin
                        if (duration_cnt == 0) begin
                            state <= S_VIC_3;
                            duration_cnt <= TIME_VIC_S;
                            tone_target <= TONE_VIC_3; 
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    S_VIC_3: begin
                        if (duration_cnt == 0) begin
                            state <= S_VIC_4;
                            duration_cnt <= TIME_VIC_L;
                            tone_target <= TONE_VIC_4; 
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    S_VIC_4: begin
                        if (duration_cnt == 0) begin
                            state <= S_IDLE;
                        end else duration_cnt <= duration_cnt - 1;
                    end

                    // 게임오버 시퀀스
                    S_OVER_1: begin
                        if (duration_cnt == 0) begin
                            state <= S_OVER_2;
                            duration_cnt <= TIME_OVER;
                            tone_target <= TONE_OVER_2;
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    S_OVER_2: begin
                        if (duration_cnt == 0) begin
                            state <= S_OVER_3;
                            duration_cnt <= TIME_OVER * 2; 
                            tone_target <= TONE_OVER_3;
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    S_OVER_3: begin
                        if (duration_cnt == 0) begin
                            state <= S_IDLE; 
                        end else duration_cnt <= duration_cnt - 1;
                    end
                    
                    default: state <= S_IDLE;
                endcase
            end
        end
    end

    // 주파수 생성기는 동일 ...
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tone_cnt  <= 0;
            piezo_out <= 0;
        end else begin
            if (tone_target > 0) begin
                if (tone_cnt >= tone_target) begin
                    tone_cnt <= 0;
                    piezo_out <= ~piezo_out; 
                end else begin
                    tone_cnt <= tone_cnt + 1;
                end
            end else begin
                piezo_out <= 0;
                tone_cnt <= 0;
            end
        end
    end
endmodule
