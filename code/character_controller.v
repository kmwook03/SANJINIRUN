module character_controller (
    input wire clk,
    input wire rst_n,
    input wire i_game_active,   // RUN 상태일 때만 동작
    input wire i_btn_jump,      // 점프 버튼 [cite: 88]
    
    output reg [7:0] char_y,    // 캐릭터 Y 위치
    output reg [7:0] char_x     // 캐릭터 X 위치 (고정값)
);
    // 물리 파라미터
    localparam GROUND_Y = 8'd10; // 바닥 위치
    localparam JUMP_MAX = 8'd50; // 점프 최대 높이
    
    reg is_jumping;
    reg jump_direction; // 0: 상승, 1: 하강

    // 캐릭터 X 좌표는 횡스크롤 게임 특성상 고정 (좌측 배치)
    always @(posedge clk) char_x <= 8'd20; 

    // 점프 로직 (간소화된 물리 엔진)
    // 실제로는 느린 클럭(enable 신호)을 사용해야 움직임이 보임
    reg [19:0] move_speed_cnt; // 속도 조절용
    wire move_tick = (move_speed_cnt == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_y <= GROUND_Y;
            is_jumping <= 0;
            jump_direction <= 0;
        end else if (i_game_active) begin
            move_speed_cnt <= move_speed_cnt + 1;

            // 점프 시작 트리거
            if (i_btn_jump && !is_jumping && char_y == GROUND_Y) begin
                is_jumping <= 1;
                jump_direction <= 0; // 상승 시작
            end

            // 점프 움직임 처리
            if (is_jumping && move_tick) begin
                if (jump_direction == 0) begin // 상승
                    if (char_y < JUMP_MAX) 
                        char_y <= char_y + 1;
                    else 
                        jump_direction <= 1; // 정점 도달, 하강 전환
                end else begin // 하강
                    if (char_y > GROUND_Y) 
                        char_y <= char_y - 1;
                    else begin
                        is_jumping <= 0; // 착지 완료
                        char_y <= GROUND_Y;
                    end
                end
            end
        end
    end
endmodule