module obstacle_controller (
    input wire clk,
    input wire rst_n,
    input wire i_game_active,
    input wire [3:0] stage,
    
    output reg [7:0] obs_x, // 장애물 X 좌표
    output reg [7:0] obs_y  // 장애물 Y 좌표
);
    localparam SCREEN_WIDTH = 8'd16; 
    localparam OBS_SPEED_BASE = 11_500_000;
    
    reg [31:0] speed_cnt;
    reg [31:0] current_obs_speed_cnt;

    // ====================================================
    // 1. 랜덤 생성기 (LFSR) - 하드웨어 난수 생성
    // ====================================================
    reg [15:0] lfsr_reg; 

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            lfsr_reg <= 16'h1234; // 0이 아닌 초기값(Seed) 필수
        end else begin
            // 16비트 피보나치 LFSR (XOR 탭: 16, 14, 13, 11)
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
                3'd2:       current_obs_speed_cnt <= (OBS_SPEED_BASE >> 1); // /2
                3'd3:       current_obs_speed_cnt <= (OBS_SPEED_BASE >> 2); // /4
                default:    current_obs_speed_cnt <= OBS_SPEED_BASE;
            endcase
        end
    end
    
    // ====================================================
    // 3. 장애물 이동 및 위치 결정
    // ====================================================
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            obs_x <= SCREEN_WIDTH - 1;
            obs_y <= 1; 
            speed_cnt <= 0;
        end else if (i_game_active) begin
            speed_cnt <= speed_cnt + 1;
            
            if (speed_cnt >= current_obs_speed_cnt) begin
                speed_cnt <= 0;
                
                if (obs_x > 0) begin
                    obs_x <= obs_x - 1; 
                end else begin
                    // 장애물 리셋 (오른쪽 끝으로 이동)
                    obs_x <= SCREEN_WIDTH - 1;
                    
                    // [중요] LFSR 값을 이용한 랜덤 위치 설정
                    // lfsr_reg 값은 매 클럭마다 변하므로 이 시점의 값은 예측 불가함.
                    
                    // 경우 1: 0 또는 1만 나오게 하고 싶을 때 (2개 라인)
                    obs_y <= lfsr_reg[0]; 

                    // 경우 2: 0, 1, 2 중 하나가 나오게 하고 싶을 때 (3개 라인)
                    // 나머지 연산(%)을 사용하여 0, 1, 2 범위를 만듭니다.
                    // (주의: % 연산은 하드웨어 자원을 많이 쓰지만 작은 수는 괜찮습니다)
                    /*
                    if (lfsr_reg[1:0] == 2'b11) 
                        obs_y <= 0; // 3이 나오면 0으로 매핑 (확률 균등화를 위해 단순화)
                    else 
                        obs_y <= lfsr_reg[1:0]; // 0, 1, 2 사용
                      */  
                    // 팁: 가장 간단하게 0~2 범위를 대략적으로 맞추려면 아래처럼 해도 됩니다.
                    // obs_y <= lfsr_reg % 3; 
                end
            end
        end
    end
endmodule
