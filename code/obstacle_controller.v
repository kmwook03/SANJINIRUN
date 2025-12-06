module obstacle_controller (
    input wire clk,
    input wire rst_n,
    input wire i_game_active,
    input wire [2:0] current_state, 
    input wire [3:0] stage,
    
    output reg [7:0] obs_x, // 장애물 X 좌표
    output reg [7:0] obs_y  // 장애물 Y 좌표
);
    localparam SCREEN_WIDTH = 8'd16; 
    localparam OBS_SPEED_BASE = 11_500_000;
    
    reg [31:0] speed_cnt;
    reg [31:0] current_obs_speed_cnt;

    // 움직임 횟수 제어용 레지스터
    reg [3:0] toggle_cnt; // 현재 몇 번 움직였는지 카운트
    reg [3:0] toggle_max; // 이번 장애물의 최대 움직임 허용 횟수

    // ====================================================
    // 1. 랜덤 생성기 (LFSR)
    // ====================================================
    reg [15:0] lfsr_reg; 

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin // rst_n Active Low
            lfsr_reg <= 16'h1234; 
        end else begin
            lfsr_reg <= {lfsr_reg[14:0], lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10]};
        end
    end

    // ====================================================
    // 2. 스테이지별 속도 설정
    // ====================================================
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            current_obs_speed_cnt <= OBS_SPEED_BASE;
        end else begin
            case (stage)
                3'd0, 3'd1: current_obs_speed_cnt <= OBS_SPEED_BASE;
                3'd2:       current_obs_speed_cnt <= (OBS_SPEED_BASE >> 1); 
                3'd3:       current_obs_speed_cnt <= (OBS_SPEED_BASE >> 2); 
                default:    current_obs_speed_cnt <= OBS_SPEED_BASE;
            endcase
        end
    end
    
    // ====================================================
    // 3. 장애물 이동 및 위치 결정
    // ====================================================
    always @(posedge clk or posedge rst_n) begin
        if (rst_n || current_state == 3'b100) begin
            obs_x <= SCREEN_WIDTH - 1;
            obs_y <= 1; 
            speed_cnt <= 0;
            toggle_cnt <= 0;
            toggle_max <= 0;
        end else if (i_game_active) begin
            speed_cnt <= speed_cnt + 1;
            
            if (speed_cnt >= current_obs_speed_cnt) begin
                speed_cnt <= 0;
                
                if (obs_x > 0) begin
                    obs_x <= obs_x - 1; 
                    
                    // [수정된 부분] 
                    // 기존 조건 && (obs_x > 2) 추가
                    // obs_x가 2보다 클 때만 움직임 허용 (2, 1, 0일 때는 위치 고정)
                    if ((toggle_cnt < toggle_max) && (lfsr_reg[1:0] == 2'b00) && (obs_x > 2)) begin
                        obs_y <= obs_y ^ 1; 
                        toggle_cnt <= toggle_cnt + 1;
                    end
                    
                end else begin
                    // === 장애물 리셋 ===
                    obs_x <= SCREEN_WIDTH - 1;
                    obs_y <= lfsr_reg[0]; 
                    toggle_cnt <= 0;
                    toggle_max <= lfsr_reg[3:1]; 
                end
            end
        end
    end
endmodule
