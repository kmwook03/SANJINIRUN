module obstacle_controller (
    input wire clk,
    input wire rst_n,
    input wire i_game_active,
    
    // [중요 수정] 1비트 -> 8비트로 확장
    output reg [7:0] obs_x, // 장애물 X 좌표
    output reg [7:0] obs_y  // 장애물 Y 좌표
);
    localparam SCREEN_WIDTH = 8'd100; 
    
    // 속도 설정 (50,000,000 = 1초, 너무 느리면 값을 줄이세요. 예: 10_000_000)
    localparam OBS_SPEED_CNT = 25_000_000; 

    reg [31:0] speed_cnt;

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin // Active Low 체크 (!rst_n)
            obs_x <= 15;
            obs_y <= 1; 
            speed_cnt <= 0;
        end else if (i_game_active) begin
            speed_cnt <= speed_cnt + 1;
            
            if (speed_cnt >= OBS_SPEED_CNT) begin
                speed_cnt <= 0;
                if (obs_x > 0) begin
                    obs_x <= obs_x - 1; 
                end else begin
                    obs_x <= 15;
                    // 높이 토글 (랜덤성)
                    // obs_y가 1이면 0으로, 0이면 1로 바꿈 (단, 8비트이므로 1/0 값 유지 주의)
                    if (obs_y == 1) obs_y <= 0;
                    else obs_y <= 1;
                end
            end
        end
    end
endmodule
