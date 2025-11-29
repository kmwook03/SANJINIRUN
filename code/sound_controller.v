module sound_controller (
    input wire clk,             // 50MHz System Clock
    input wire rst,             // [수정] Active High Reset (1일 때 리셋)
    input wire i_btn_jump,      // 1일 때 점프
    input wire i_collision,     // 1일 때 충돌
    input wire [1:0] current_state,
    output reg piezo_out        // 피에조 스피커 출력
);

    // -------------------------------------------------------
    // 1. 파라미터 정의 (주파수 설정)
    // -------------------------------------------------------
    // 50MHz / (Target_Freq * 2) = Toggle Count
    // 예: 261Hz(도) -> 50,000,000 / 522 = approx 95,785
    // 예: 1000Hz(삑!) -> 50,000,000 / 2000 = 25,000
    
    //  점프 효과음: 짧고 높은 소리 (약 1kHz)
    localparam TONE_JUMP = 18'd25_000; 
    
    // [cite: 94] 게임오버 효과음: 길고 낮은 소리 (약 260Hz)
    localparam TONE_OVER = 18'd95_000; 
    
    // -------------------------------------------------------
    // 2. 내부 레지스터
    // -------------------------------------------------------
    reg [17:0] tone_cnt;      // 주파수 분주 카운터
    reg [17:0] tone_target;   // 목표 분주 값 (소리 높낮이 결정)
    reg sound_en;             // 소리 재생 ON/OFF 플래그
    reg [24:0] duration_cnt;  // 소리 지속 시간 카운터

    // -------------------------------------------------------
    // 3. 소리 제어 로직 (Active High Reset 적용)
    // -------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // [Active High] 리셋이 1일 때 초기화
            tone_target  <= 0;
            sound_en     <= 0;
            duration_cnt <= 0;
        end else begin
            // 우선순위: 충돌(게임오버) > 점프
            // 이미 소리가 나고 있어도 충돌이 발생하면 덮어씌움 (중요)
            if (current_state == 2'b10)
                tone_target  <= TONE_OVER;
                sound_en     <= 1;
                duration_cnt <= 25'd5_000_000;  // 0.1초 (50MHz * 0.1)
            if (i_collision) begin 
                // [cite: 94] 충돌 시 게임오버 효과음 출력
                tone_target  <= TONE_OVER;
                sound_en     <= 1;
                duration_cnt <= 25'd25_000_000; // 0.5초 (50MHz * 0.5)
            end 
            else if (i_btn_jump && !sound_en) begin 
                //  점프 버튼 입력 시 점프 효과음 출력
                // (!sound_en 조건을 넣어 소리가 겹치거나 재시작되는 것 방지)
                tone_target  <= TONE_JUMP;
                sound_en     <= 1;
                duration_cnt <= 25'd5_000_000;  // 0.1초 (50MHz * 0.1)
            end

            // 소리 지속 시간 카운트 (Timer)
            if (sound_en) begin
                if (duration_cnt > 0) begin
                    duration_cnt <= duration_cnt - 1;
                end else begin
                    // 시간이 다 되면 소리 끄기
                    sound_en <= 0;
                    tone_target <= 0; // 안전하게 타겟도 초기화
                end
            end
        end
    end

    // -------------------------------------------------------
    // 4. 주파수 생성 (Square Wave Generator)
    // -------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tone_cnt  <= 0;
            piezo_out <= 0;
        end else begin
            if (sound_en && tone_target > 0) begin
                if (tone_cnt >= tone_target) begin
                    tone_cnt <= 0;
                    piezo_out <= ~piezo_out; // 0과 1을 번갈아 출력하여 소리 발생
                end else begin
                    tone_cnt <= tone_cnt + 1;
                end
            end else begin
                // 소리가 안 날 때는 0으로 고정 (잡음 방지)
                piezo_out <= 0;
                tone_cnt <= 0;
            end
        end
    end

endmodule
