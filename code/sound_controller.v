module sound_controller (
    input wire clk,             // 50MHz System Clock
    input wire rst,             // Active High Reset
    input wire i_btn_jump,      // 1일 때 점프
    input wire i_collision,     // 1일 때 충돌 (게임오버)
    input wire [2:0] current_state, 
    
    output reg piezo_out        // 피에조 스피커 출력
);

    // =======================================================
    // 1. 파라미터 정의
    // =======================================================
    localparam TONE_JUMP_1 = 18'd38_000; 
    localparam TONE_JUMP_2 = 18'd19_000; 
    
    localparam TONE_OVER_1 = 18'd28_400; 
    localparam TONE_OVER_2 = 18'd37_900; 
    localparam TONE_OVER_3 = 18'd56_800; 

    localparam TIME_JUMP   = 25'd4_000_000;  
    localparam TIME_OVER   = 25'd10_000_000; 

    localparam S_IDLE      = 3'd0;
    localparam S_JUMP_1    = 3'd1;
    localparam S_JUMP_2    = 3'd2;
    localparam S_OVER_1    = 3'd3;
    localparam S_OVER_2    = 3'd4;
    localparam S_OVER_3    = 3'd5;

    // =======================================================
    // 2. 내부 레지스터
    // =======================================================
    reg [2:0] state;            
    reg [17:0] tone_cnt;        
    reg [17:0] tone_target;     
    reg [24:0] duration_cnt;    

    // [추가] 이전 버튼 상태 저장을 위한 레지스터
    reg btn_prev; 

    // =======================================================
    // 3. 소리 시퀀스 제어
    // =======================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            duration_cnt <= 0;
            tone_target <= 0;
            btn_prev <= 0; // 초기화
        state <= current_state;
        end else begin
            // [중요] 매 클럭마다 현재 버튼 상태를 '과거'로 저장
            btn_prev <= i_btn_jump;

            // 충돌 감지 (최우선)
            if (i_collision) begin
                if (state < S_OVER_1) begin 
                    state <= S_OVER_1;
                    duration_cnt <= TIME_OVER;
                    tone_target <= TONE_OVER_1;
                end
            end
            else begin
                case (state)
                    // ------------------------------------
                    // 대기 상태
                    // ------------------------------------
                    S_IDLE: begin
                        tone_target <= 0;
                        
                        // [수정된 조건] 
                        // 현재 버튼이 1이고(i_btn_jump), 이전에는 0이었을 때(!btn_prev)만 실행
                        if (i_btn_jump && !btn_prev) begin
                            state <= S_JUMP_1;
                            duration_cnt <= TIME_JUMP;
                            tone_target <= TONE_JUMP_1;
                        end
                    end

                    // ------------------------------------
                    // 점프 시퀀스
                    // ------------------------------------
                    S_JUMP_1: begin
                        if (duration_cnt == 0) begin
                            state <= S_JUMP_2;
                            duration_cnt <= TIME_JUMP;
                            tone_target <= TONE_JUMP_2;
                        end else duration_cnt <= duration_cnt - 1;
                    end

                    S_JUMP_2: begin
                        if (duration_cnt == 0) begin
                            state <= S_IDLE; // 끝나면 IDLE로 감
                        end else duration_cnt <= duration_cnt - 1;
                    end

                    // ------------------------------------
                    // 게임 오버 시퀀스
                    // ------------------------------------
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

    // =======================================================
    // 4. 주파수 생성기 (변경 없음)
    // =======================================================
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
