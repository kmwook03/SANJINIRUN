module character_controller (
    input wire clk,             // 시스템 클럭 (50MHz)
    input wire rst_n,           // Active Low 리셋
    input wire i_game_active,   // 게임 활성화 상태
    input wire i_btn_jump,      // 점프 버튼 입력
    
    output reg char_y,          // 캐릭터 Y 위치 (1: 바닥, 0: 점프)
    output reg char_x           // 캐릭터 X 위치 (고정값)
);

    // ====================================================
    // 1. 파라미터 정의
    // ====================================================
    parameter DEBOUNCE_LIMIT = 500_000; 

    // [점프 체공 시간 설정]
    // 50MHz 클럭 기준, 0.4초 동안 점프 유지
    // 50,000,000 * 0.4 = 20,000,000
    localparam JUMP_DURATION = 40_000_000; 
    
    // ====================================================
    // 2. 내부 레지스터 정의
    // ====================================================
    reg [19:0] debounce_cnt;    // 디바운싱 카운터
    reg btn_stable;             // 디바운싱된 버튼 값
    reg btn_prev;               // 엣지 검출용
    
    reg [31:0] jump_timer;      // 점프 시간을 세는 타이머 [추가됨]

    wire btn_posedge;           // 버튼 눌린 순간 (Rising Edge)

    // 캐릭터 X 좌표 고정
    always @(posedge clk) char_x <= 0;

    // ====================================================
    // 3. 디바운싱 로직 (기존 유지)
    // ====================================================
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            debounce_cnt <= 0;
            btn_stable <= 0;
        end else begin
            if (i_btn_jump != btn_stable) begin
                debounce_cnt <= debounce_cnt + 1;
                if (debounce_cnt >= DEBOUNCE_LIMIT) begin
                    btn_stable <= i_btn_jump;
                    debounce_cnt <= 0;
                end
            end else begin
                debounce_cnt <= 0;
            end
        end
    end

    // ====================================================
    // 4. 엣지 디텍션 (기존 유지)
    // ====================================================
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            btn_prev <= 0;
        end else begin
            btn_prev <= btn_stable;
        end
    end

    assign btn_posedge = (btn_stable == 1'b1) && (btn_prev == 1'b0);


    // ====================================================
    // 5. 점프 로직 (수정됨: 토글 -> 타이머 방식)
    // ====================================================
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            char_y <= 1;        // 초기 위치 (1 = 바닥)
            jump_timer <= 0;    // 타이머 초기화
        end else if (i_game_active) begin
            
            // (1) 바닥에 있을 때 (char_y == 1)
            if (char_y == 1'b1) begin
                // 점프 버튼을 누르면 점프 시작!
                if (btn_posedge) begin
                    char_y <= 1'b0;          // 위로 이동 (점프)
                    jump_timer <= JUMP_DURATION; // 체공 시간 설정
                end
            end 
            
            // (2) 공중에 있을 때 (char_y == 0)
            else begin
                // 타이머가 남아있으면 시간 감소
                if (jump_timer > 0) begin
                    jump_timer <= jump_timer - 1;
                end 
                // 시간이 다 되면 착지
                else begin
                    char_y <= 1'b1;          // 바닥으로 복귀
                end
            end
        end
    end

endmodule
