module LCD_Controller (
    input wire clk,              // 50MHz System Clock
    input wire rst_n,            // Reset (Active Low)
    
    // 게임 정보 입력
    input wire [1:0] current_state, // FSM 상태
    input wire [7:0] char_y,        // 캐릭터 Y 좌표 (0: 위, 1: 아래)
    input wire [7:0] obs_x,         // 장애물 X 좌표 (0~15)
    input wire [7:0] obs_y,         // 장애물 Y 좌표 (0: 위, 1: 아래)

    // LCD 하드웨어 제어 신호
    output wire [7:0] o_lcd_data, // Data Bus
    output wire o_lcd_rs,         // 0: Command, 1: Data
    output wire o_lcd_rw,         // 0: Write, 1: Read (보통 0 고정)
    output wire o_lcd_en          // Enable Pulse
);

    // =========================================================================
    // 1. 파라미터 및 상태 정의
    // =========================================================================
    
    // LCD 명령어
    localparam CMD_FUNCTION_SET = 8'h38; // 8-bit, 2 lines, 5x8 font
    localparam CMD_DISPLAY_ON   = 8'h0C; // Display ON, Cursor OFF
    localparam CMD_CLEAR        = 8'h01; // Clear Display
    localparam CMD_ENTRY_MODE   = 8'h06; // Increment cursor
    localparam CMD_SET_DDRAM    = 8'h80; // Set Cursor Position (Line 1)
    localparam CMD_SET_DDRAM2   = 8'hC0; // Set Cursor Position (Line 2)
    localparam CMD_SET_CGRAM    = 8'h40; // Set CGRAM Address (Custom Char)

    // FSM 상태
    localparam S_POWER_ON    = 0;
    localparam S_INIT_FUNC   = 1;
    localparam S_INIT_DISP   = 2;
    localparam S_INIT_CLR    = 3;
    localparam S_INIT_ENTRY  = 4;
    localparam S_LOAD_CGRAM  = 5; // 커스텀 캐릭터 로딩
    localparam S_READY       = 6; // 그리기 준비
    localparam S_DRAW_LINE1  = 7; // 첫 번째 줄 그리기
    localparam S_DRAW_LINE2  = 8; // 두 번째 줄 그리기
    localparam S_DONE        = 9; // 프레임 완료 (대기)

    reg [3:0] state;
    reg [4:0] send_idx; // 데이터 전송 인덱스 (0~15)
    
    // 타이밍 제어용 카운터 (50MHz 기준)
    reg [20:0] delay_cnt; 
    parameter DELAY_20MS = 1000000; // 전원 인가 후 대기
    parameter DELAY_2MS  = 100000;  // 명령어 처리 대기 (Clear 등)
    parameter DELAY_50US = 2500;    // 일반 데이터 쓰기 대기

    // =========================================================================
    // 2. 커스텀 캐릭터 데이터 (산지니 - 간단한 졸라맨)
    // =========================================================================
    reg [7:0] cgram_sanjini [0:7];
    initial begin
        cgram_sanjini[0] = 5'b00110; //  깃털
        cgram_sanjini[1] = 5'b01111; //  머리
        cgram_sanjini[2] = 5'b11111; //  얼굴
        cgram_sanjini[3] = 5'b11111; //  얼굴
        cgram_sanjini[4] = 5'b01110; //  목
        cgram_sanjini[5] = 5'b11111; //  날개
        cgram_sanjini[6] = 5'b01110; //  다리
        cgram_sanjini[7] = 5'b01010; //  발
    end

    // =========================================================================
    // 3. 메인 FSM
    // =========================================================================
    
    // 내부 신호
    reg [7:0] line_buffer [0:15]; // 한 줄 분량 버퍼
    reg [7:0] next_data;          // 보낼 데이터
    reg next_rs;                  // 보낼 RS 값
    reg start_send;               // 전송 시작 신호
    wire send_done;               // 전송 완료 신호

    // LCD Low-Level Driver 인스턴스 (아래에 정의)
    LCD_Driver driver (
        .clk(clk),
        .rst_n(rst_n),
        .i_data(next_data),
        .i_rs(next_rs),
        .i_start(start_send),
        .o_done(send_done),
        .o_lcd_data(o_lcd_data),
        .o_lcd_rs(o_lcd_rs),
        .o_lcd_rw(o_lcd_rw),
        .o_lcd_en(o_lcd_en)
    );

    // FSM 로직
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_POWER_ON;
            delay_cnt <= 0;
            send_idx <= 0;
            start_send <= 0;
        end else begin
            // Pulse 신호는 한 클럭만 유지
            if (start_send) start_send <= 0;

            case (state)
                // -------------------------------------------------------------
                // 초기화 시퀀스 (Initialization)
                // -------------------------------------------------------------
                S_POWER_ON: begin
                    if (delay_cnt < DELAY_20MS) delay_cnt <= delay_cnt + 1;
                    else begin
                        delay_cnt <= 0;
                        state <= S_INIT_FUNC;
                    end
                end

                S_INIT_FUNC: begin
                    next_data <= CMD_FUNCTION_SET; next_rs <= 0;
                    start_send <= 1;
                    if (send_done) state <= S_INIT_DISP;
                end

                S_INIT_DISP: begin
                    next_data <= CMD_DISPLAY_ON; next_rs <= 0;
                    start_send <= 1;
                    if (send_done) state <= S_INIT_CLR;
                end

                S_INIT_CLR: begin
                    next_data <= CMD_CLEAR; next_rs <= 0;
                    start_send <= 1;
                    if (send_done) state <= S_INIT_ENTRY;
                end

                S_INIT_ENTRY: begin
                    next_data <= CMD_ENTRY_MODE; next_rs <= 0;
                    start_send <= 1;
                    if (send_done) begin
                        state <= S_LOAD_CGRAM;
                        send_idx <= 0;
                    end
                end

                // -------------------------------------------------------------
                // 커스텀 캐릭터(산지니) 등록 (CGRAM 0번지)
                // -------------------------------------------------------------
                S_LOAD_CGRAM: begin
                    if (send_idx == 0 && !start_send && !send_done) begin
                        // 1. CGRAM 주소 설정
                        next_data <= CMD_SET_CGRAM; next_rs <= 0; 
                        start_send <= 1;
                    end else if (send_idx < 8) begin
                        // 2. 캐릭터 데이터 8바이트 전송
                        // 드라이버가 Idle 상태일 때만 보냄
                        // (여기서는 간단하게 순차 처리 로직 생략, 실제로는 Handshake 필요)
                        // *간소화를 위해 이 부분은 구현 시 주의 필요 (타이밍)*
                        // 안전하게: send_done 체크 후 다음 바이트 전송
                        if (send_done) begin
                            // 방금 주소를 보냈거나 이전 데이터를 보냄
                            next_data <= cgram_sanjini[send_idx]; 
                            next_rs <= 1; // Data 모드
                            start_send <= 1;
                            send_idx <= send_idx + 1;
                        end
                    end else if (send_idx == 8 && send_done) begin
                         state <= S_READY; // 로딩 완료
                    end
                end

                // -------------------------------------------------------------
                // 화면 갱신 루프 (Main Loop)
                // -------------------------------------------------------------
                S_READY: begin
                    // 다음 그리기 준비 (상태에 따라 내용 결정)
                    // Line 1 그리기 시작 명령
                    next_data <= CMD_SET_DDRAM; // Line 1 (0x80)
                    next_rs <= 0;
                    start_send <= 1;
                    state <= S_DRAW_LINE1;
                    send_idx <= 0;
                end

                S_DRAW_LINE1: begin
                    if (send_done) begin
                        // 방금 커맨드(주소) 또는 이전 글자를 다 보냄
                        if (send_idx < 16) begin
                            // Line 1 데이터 결정 로직
                            next_data <= get_char_at(0, send_idx); // 함수 호출
                            next_rs <= 1; // Data
                            start_send <= 1;
                            send_idx <= send_idx + 1;
                        end else begin
                            // Line 2로 이동 준비
                            next_data <= CMD_SET_DDRAM2; // Line 2 (0xC0)
                            next_rs <= 0;
                            start_send <= 1;
                            state <= S_DRAW_LINE2;
                            send_idx <= 0;
                        end
                    end
                end

                S_DRAW_LINE2: begin
                    if (send_done) begin
                        if (send_idx < 16) begin
                            // Line 2 데이터 결정 로직
                            next_data <= get_char_at(1, send_idx);
                            next_rs <= 1;
                            start_send <= 1;
                            send_idx <= send_idx + 1;
                        end else begin
                            state <= S_DONE;
                            delay_cnt <= 0;
                        end
                    end
                end

                S_DONE: begin
                    // 100ms 정도 대기 후 다시 리프레시 (깜빡임 방지 및 게임 속도 조절)
                    if (delay_cnt < 5000000) delay_cnt <= delay_cnt + 1;
                    else begin
                        state <= S_READY;
                        delay_cnt <= 0;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // 4. 화면 내용 결정 함수 (Combinational Logic)
    // =========================================================================
    function [7:0] get_char_at;
        input integer row; // 0 or 1
        input integer col; // 0 ~ 15
        begin
            // 기본값: 공백
            get_char_at = " "; 

            if (current_state == 2'b00) begin // IDLE
                // "PRESS START   "
                if (row == 0) begin
                   case(col)
                       0: get_char_at = "P"; 1: get_char_at = "R"; 2: get_char_at = "E";
                       3: get_char_at = "S"; 4: get_char_at = "S"; 5: get_char_at = " ";
                       6: get_char_at = "S"; 7: get_char_at = "T"; 8: get_char_at = "A";
                       9: get_char_at = "R"; 10: get_char_at = "T";
                       default: get_char_at = " ";
                   endcase
                end
            end else if (current_state == 2'b11) begin // GAMEOVER
                 if (row == 0) begin
                   // "GAME OVER !!! "
                   case(col)
                       0: get_char_at = "G"; 1: get_char_at = "A"; 2: get_char_at = "M"; 3: get_char_at = "E";
                       5: get_char_at = "O"; 6: get_char_at = "V"; 7: get_char_at = "E"; 8: get_char_at = "R";
                       default: get_char_at = " ";
                   endcase
                end
            end else begin // RUN or COUNTDOWN
                // 1. 산지니 그리기 (0번 커스텀 캐릭터)
                // 산지니는 X=1 위치에 고정, Y는 char_y에 따름
                if (col == 1) begin 
                    if (row == char_y) get_char_at = 8'h00; // Custom Char 0 (Sanjini)
                end
                
                // 2. 장애물 그리기 ('X' 문자)
                // 장애물 좌표와 현재 그리는 좌표가 같으면 표시
                if (col == obs_x && row == obs_y) begin
                    get_char_at = "X"; // 장애물 문자
                end
                
                // 3. 바닥 그리기 (아랫줄이면 '_')
                if (row == 1 && col != 1 && !(col == obs_x && row == obs_y)) begin
                    get_char_at = "_";
                end
            end
        end
    endfunction

endmodule

// =============================================================================
// Internal Module: LCD Low-Level Driver (타이밍 맞춰서 신호 쏘는 기계)
// =============================================================================
module LCD_Driver (
    input wire clk,
    input wire rst_n,
    input wire [7:0] i_data,
    input wire i_rs,
    input wire i_start,
    output reg o_done,
    output reg [7:0] o_lcd_data,
    output reg o_lcd_rs,
    output reg o_lcd_rw,
    output reg o_lcd_en
);
    // 상태 정의
    localparam S_IDLE  = 0;
    localparam S_SETUP = 1; // RS, RW 세팅
    localparam S_EN_H  = 2; // Enable High
    localparam S_EN_L  = 3; // Enable Low (Hold)
    localparam S_WAIT  = 4; // 실행 시간 대기

    reg [2:0] state;
    reg [16:0] cnt; // 타이머

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            o_lcd_en <= 0;
            o_lcd_rw <= 0; // Write Only
            o_done <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    o_done <= 0;
                    if (i_start) begin
                        state <= S_SETUP;
                        o_lcd_data <= i_data;
                        o_lcd_rs <= i_rs;
                        cnt <= 0;
                    end
                end
                S_SETUP: begin
                    // 데이터 셋업 시간 (약 40ns 이상 필요 -> 50MHz에서 2클럭이면 충분)
                    if (cnt < 4) cnt <= cnt + 1;
                    else begin
                        state <= S_EN_H;
                        o_lcd_en <= 1; // Pulse 시작
                        cnt <= 0;
                    end
                end
                S_EN_H: begin
                    // Enable Pulse Width (약 230ns 이상 필요 -> 20클럭 넉넉히)
                    if (cnt < 20) cnt <= cnt + 1;
                    else begin
                        state <= S_EN_L;
                        o_lcd_en <= 0; // Pulse 끝
                        cnt <= 0;
                    end
                end
                S_EN_L: begin
                    // Hold Time
                    if (cnt < 10) cnt <= cnt + 1;
                    else begin
                        state <= S_WAIT;
                        cnt <= 0;
                    end
                end
                S_WAIT: begin
                    // 명령어 실행 시간 대기 (Data: 50us, Command: 2ms)
                    // 안전하게 모두 2ms 대기하거나, i_rs에 따라 구분 가능
                    // 여기선 간단하게 50us 대기 (Clear 명령은 상위 모듈에서 긴 대기 필요)
                    if (cnt < 2500) cnt <= cnt + 1; 
                    else begin
                        state <= S_IDLE;
                        o_done <= 1; // 완료 신호
                    end
                end
            endcase
        end
    end
endmodule
