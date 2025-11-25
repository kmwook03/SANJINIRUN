module obstacle_controller (
    input wire clk,
    input wire rst_n,
    input wire i_game_active,
    
    output reg [7:0] obs_x, // 장애물 X 좌표
    output reg [7:0] obs_y  // 장애물 Y 좌표 (공중/지상)
);
    localparam SCREEN_WIDTH = 8'd100; // 가상 화면 너비
    localparam OBS_SPEED_CNT = 20'd100_000; // 이동 속도

    reg [19:0] speed_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            obs_x <= SCREEN_WIDTH;
            obs_y <= 8'd10; // 초기값: 지상 장애물
        end else if (i_game_active) begin
            speed_cnt <= speed_cnt + 1;
            
            if (speed_cnt >= OBS_SPEED_CNT) begin
                speed_cnt <= 0;
                if (obs_x > 0) begin
                    obs_x <= obs_x - 1; // 왼쪽으로 이동 [cite: 32] (배경 스크롤과 유사)
                end else begin
                    // 화면 끝 도달 시 리스폰
                    obs_x <= SCREEN_WIDTH;
                    // 랜덤 대신 단순 토글로 지상/공중 장애물 변경 예시 [cite: 21]
                    obs_y <= (obs_y == 8'd10) ? 8'd30 : 8'd10; 
                end
            end
        end
    end
endmodule