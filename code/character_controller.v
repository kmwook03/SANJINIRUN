module character_controller (
    input wire clk,
    input wire rst_n,
    input wire i_game_active,   // RUN 상태일 때만 동작
    input wire i_btn_jump,      // 점프 버튼 [cite: 88]
    
    output reg char_y,    // 캐릭터 Y 위치
    output reg char_x     // 캐릭터 X 위치 (고정값)
);

    // 캐릭터 X 좌표는 횡스크롤 게임 특성상 고정 (좌측 배치)
    always @(posedge clk) char_x <= 0; 

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            char_y <= 1;
        end else if (i_game_active) begin
            // 점프 시작 트리거
            if (i_btn_jump) begin
                char_y = ~char_y;
            end
        end 
    end
endmodule
