module lcd_controller (
    input wire clk,                 // 50MHz Clock
    input wire rst_n,
    input wire [1:0] current_state, // FSM State
    input wire [7:0] char_y,        // 캐릭터 Y 좌표
    input wire [7:0] obs_x,         // 장애물 X 좌표
    
    output reg lcd_rs,    // 0: Cmd, 1: Data
    output reg lcd_rw,    // 0: Write
    output reg lcd_e,     // Enable
    output reg [7:0] lcd_data
);

    // -------------------------------------------------------
    // 상태 정의
    // -------------------------------------------------------
    localparam S_IDLE      = 2'b00;
    localparam S_COUNTDOWN = 2'b01;
    localparam S_RUN       = 2'b10;
    localparam S_GAMEOVER  = 2'b11;

    // CGRAM 문자 코드 정의 (0~7번지 사용 가능)
    localparam CHAR_SANJINI = 8'h00; // 0번 문자: 산지니
    localparam CHAR_OBSTACLE= 8'h01; // 1번 문자: 장애물

    // 타이밍 상수
    parameter DELAY_INIT = 100000;
    
    reg [19:0] delay_cnt;
    reg [5:0]  state_idx; 
    reg [3:0]  send_step;
    
    // 화면 버퍼
    reg [7:0] line1_buffer [0:15];
    reg [7:0] line2_buffer [0:15];
    integer i;

    // -------------------------------------------------------
    // [1] CGRAM 데이터 정의 (5x8 픽셀 비트맵)
    // -------------------------------------------------------
    // index 0~7: 산지니(새 모양), index 8~15: 장애물(가시 모양)
    function [7:0] get_cgram_pixel;
        input [3:0] row_idx; // 0~15
        begin
            case (row_idx)
                // --- 산지니 (Bird) ---
                4'd0: get_cgram_pixel = 5'b00000;
                4'd1: get_cgram_pixel = 5'b00110; // 머리
                4'd2: get_cgram_pixel = 5'b01101; // 눈/부리
                4'd3: get_cgram_pixel = 5'b11111; // 몸통
                4'd4: get_cgram_pixel = 5'b01110; // 날개
                4'd5: get_cgram_pixel = 5'b00100; // 다리
                4'd6: get_cgram_pixel = 5'b00000;
                4'd7: get_cgram_pixel = 5'b00000;
                
                // --- 장애물 (Spike) ---
                4'd8: get_cgram_pixel = 5'b00000;
                4'd9: get_cgram_pixel = 5'b00000;
                4'd10:get_cgram_pixel = 5'b00100; // 뾰족
                4'd11:get_cgram_pixel = 5'b01110;
                4'd12:get_cgram_pixel = 5'b01110;
                4'd13:get_cgram_pixel = 5'b11111;
                4'd14:get_cgram_pixel = 5'b11111;
                4'd15:get_cgram_pixel = 5'b11111; // 바닥
                default: get_cgram_pixel = 5'b00000;
            endcase
        end
    endfunction

    // -------------------------------------------------------
    // [2] 화면 버퍼 업데이트 로직
    // -------------------------------------------------------
    always @(posedge clk) begin
        // 버퍼 초기화 (공백)
        for (i=0; i<16; i=i+1) begin
            line1_buffer[i] <= " ";
            line2_buffer[i] <= " ";
        end

        case (current_state)
            S_IDLE: begin
                // 텍스트 출력 예시
                line1_buffer[3]="R"; line1_buffer[4]="E"; line1_buffer[5]="A"; 
                line1_buffer[6]="D"; line1_buffer[7]="Y"; line1_buffer[8]="?";
                
                // 산지니 미리보기
                line2_buffer[7] = CHAR_SANJINI; 
            end

            S_COUNTDOWN: begin
                line1_buffer[3]="S"; line1_buffer[4]="T"; line1_buffer[5]="A";
                line1_buffer[6]="R"; line1_buffer[7]="T";
            end

            S_RUN: begin
                // --- 산지니 표시 (커스텀 문자 0번 사용) ---
                if (char_y > 8'd10) 
                    line1_buffer[2] = CHAR_SANJINI; // 점프 시 윗줄
                else 
                    line2_buffer[2] = CHAR_SANJINI; // 평소 아랫줄

                // --- 장애물 표시 (커스텀 문자 1번 사용) ---
                // obs_x를 16칸으로 스케일링
                if (obs_x[7:4] < 16) begin
                    line2_buffer[obs_x[7:4]] = CHAR_OBSTACLE;
                end
            end

            S_GAMEOVER: begin
                line1_buffer[3]="G"; line1_buffer[4]="A"; line1_buffer[5]="M"; line1_buffer[6]="E";
                line1_buffer[8]="O"; line1_buffer[9]="V"; line1_buffer[10]="E"; line1_buffer[11]="R";
            end
        endcase
    end

    // -------------------------------------------------------
    // [3] LCD 제어 FSM (CGRAM Load 추가)
    // -------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lcd_e <= 0; lcd_rs <= 0; lcd_rw <= 0;
            delay_cnt <= 0;
            state_idx <= 0;
            send_step <= 0;
        end else begin
            if (delay_cnt < DELAY_INIT) begin
                delay_cnt <= delay_cnt + 1;
            end else begin
                delay_cnt <= 0; // 딜레이 리셋
                
                case (state_idx)
                    // === 1. 초기화 (Initialization) ===
                    0: begin lcd_rs<=0; lcd_data<=8'h38; lcd_e<=1; state_idx<=state_idx+1; end // Function Set
                    1: begin lcd_e<=0; state_idx<=state_idx+1; end
                    2: begin lcd_rs<=0; lcd_data<=8'h0C; lcd_e<=1; state_idx<=state_idx+1; end // Display On
                    3: begin lcd_e<=0; state_idx<=state_idx+1; end
                    4: begin lcd_rs<=0; lcd_data<=8'h01; lcd_e<=1; state_idx<=state_idx+1; end // Clear
                    5: begin lcd_e<=0; state_idx<=state_idx+1; end
                    
                    // === 2. CGRAM 데이터 로드 (Load Custom Char) ===
                    // CGRAM Address Set (0x40부터 시작)
                    6: begin 
                         lcd_rs<=0; 
                         lcd_data<=8'h40 + send_step; // 0x40 + offset
                         lcd_e<=1; 
                         state_idx<=state_idx+1; 
                    end
                    7: begin lcd_e<=0; state_idx<=state_idx+1; end
                    
                    // Pixel Data Write
                    8: begin 
                         lcd_rs<=1; // Data 모드
                         lcd_data<= get_cgram_pixel(send_step); // 픽셀 가져오기
                         lcd_e<=1; 
                         state_idx<=state_idx+1; 
                    end
                    9: begin 
                         lcd_e<=0; 
                         // 총 16줄 (8줄 x 2글자) 로드 반복
                         if(send_step < 15) begin
                             send_step <= send_step + 1;
                             state_idx <= 6; // 다시 주소 설정부터
                         end else begin
                             send_step <= 0;
                             state_idx <= 10; // 메인 루프로 이동
                         end
                    end

                    // === 3. 메인 디스플레이 루프 (Refresh) ===
                    10: begin // Line 1 커서 이동 (0x80)
                        lcd_rs<=0; lcd_data<=8'h80; lcd_e<=1; 
                        send_step<=0; state_idx<=state_idx+1; 
                    end
                    11: begin lcd_e<=0; state_idx<=state_idx+1; end
                    
                    12: begin // Line 1 데이터 쓰기
                        lcd_rs<=1; lcd_data<=line1_buffer[send_step]; lcd_e<=1;
                        state_idx<=state_idx+1;
                    end
                    13: begin 
                        lcd_e<=0; 
                        if(send_step < 15) begin
                            send_step <= send_step + 1;
                            state_idx <= 12; 
                        end else begin
                            state_idx <= 20; // Line 2로
                        end
                    end

                    20: begin // Line 2 커서 이동 (0xC0)
                        lcd_rs<=0; lcd_data<=8'hC0; lcd_e<=1; 
                        send_step<=0; state_idx<=state_idx+1; 
                    end
                    21: begin lcd_e<=0; state_idx<=state_idx+1; end

                    22: begin // Line 2 데이터 쓰기
                        lcd_rs<=1; lcd_data<=line2_buffer[send_step]; lcd_e<=1;
                        state_idx<=state_idx+1;
                    end
                    23: begin 
                        lcd_e<=0; 
                        if(send_step < 15) begin
                            send_step <= send_step + 1;
                            state_idx <= 22; 
                        end else begin
                            state_idx <= 10; // 다시 처음으로 반복
                        end
                    end
                endcase
            end
        end
    end
endmodule