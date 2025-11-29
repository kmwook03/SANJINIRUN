module lcd_controller (
    input wire clk,             // 50MHz System Clock
    input wire rst_n,           // Reset (Active High로 가정: 1일 때 리셋)
    
    // 게임 정보 입력
    input wire [1:0] current_state, // FSM 상태
    input wire [7:0] char_y,        // 캐릭터 Y 좌표
    input wire [7:0] obs_x,         // 장애물 X 좌표
    input wire [7:0] obs_y,         // 장애물 Y 좌표

    // LCD 하드웨어 제어 신호
    output wire [7:0] o_lcd_data, // Data Bus
    output wire o_lcd_rs,         // 0: Command, 1: Data
    output wire o_lcd_rw,         // 0: Write, 1: Read
    output wire o_lcd_en          // Enable Pulse
);

    // =========================================================================
    // 1. 파라미터 및 상태 정의
    // =========================================================================
    localparam CMD_FUNCTION_SET = 8'h38;
    localparam CMD_DISPLAY_ON   = 8'h0C;
    localparam CMD_CLEAR        = 8'h01;
    localparam CMD_ENTRY_MODE   = 8'h06;
    localparam CMD_SET_DDRAM    = 8'h80;
    localparam CMD_SET_DDRAM2   = 8'hC0;
    localparam CMD_SET_CGRAM    = 8'h40;

    // FSM State Definition
    localparam S_POWER_ON    = 0;
    localparam S_INIT_FUNC   = 1;
    localparam S_INIT_DISP   = 2;
    localparam S_INIT_CLR    = 3;
    localparam S_INIT_ENTRY  = 4;
    localparam S_LOAD_CGRAM  = 5;
    localparam S_READY       = 6;
    localparam S_DRAW_LINE1  = 7;
    localparam S_MOVE_LINE2  = 8; // [NEW] 줄바꿈 전용 상태
    localparam S_DRAW_LINE2  = 9;
    localparam S_DONE        = 10;

    reg [3:0] state;
    reg [4:0] send_idx; // 데이터 전송 인덱스 (0~15)
    
    // 타이밍 제어용
    reg [20:0] delay_cnt; 
    parameter DELAY_20MS = 1000000;

    // =========================================================================
    // 2. 커스텀 캐릭터 데이터 (산지니)
    // =========================================================================
    reg [7:0] cgram_sanjini [0:7];
    initial begin
        cgram_sanjini[0] = 5'b00110; cgram_sanjini[1] = 5'b01111;
        cgram_sanjini[2] = 5'b11111; cgram_sanjini[3] = 5'b11111;
        cgram_sanjini[4] = 5'b01110; cgram_sanjini[5] = 5'b11111;
        cgram_sanjini[6] = 5'b01110; cgram_sanjini[7] = 5'b01010;
    end

    // =========================================================================
    // 3. 메인 FSM & Driver 연결
    // =========================================================================
    
    // 내부 신호
    reg [7:0] next_data;
    reg next_rs;
    reg start_send;
    wire send_done;

    // [핵심] Handshake Flag: 1이면 드라이버가 일하는 중
    reg is_sent; 

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

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            state <= S_POWER_ON;
            delay_cnt <= 0;
            send_idx <= 0;
            start_send <= 0;
            is_sent <= 0;
        end else begin
            // Pulse 신호 자동 Off
            if (start_send) start_send <= 0;

            case (state)
                // -------------------------------------------------------------
                // 초기화 시퀀스 (Handshake 패턴 적용)
                // -------------------------------------------------------------
                S_POWER_ON: begin
                    if (delay_cnt < DELAY_20MS) delay_cnt <= delay_cnt + 1;
                    else begin
                        delay_cnt <= 0;
                        state <= S_INIT_FUNC;
                        is_sent <= 0;
                    end
                end

                S_INIT_FUNC: begin
                    if (!is_sent) begin
                        next_data <= CMD_FUNCTION_SET; next_rs <= 0;
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        state <= S_INIT_DISP; is_sent <= 0;
                    end
                end

                S_INIT_DISP: begin
                    if (!is_sent) begin
                        next_data <= CMD_DISPLAY_ON; next_rs <= 0;
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        state <= S_INIT_CLR; is_sent <= 0;
                    end
                end

                S_INIT_CLR: begin
                    if (!is_sent) begin
                        next_data <= CMD_CLEAR; next_rs <= 0;
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        state <= S_INIT_ENTRY; is_sent <= 0;
                    end
                end

                S_INIT_ENTRY: begin
                    if (!is_sent) begin
                        next_data <= CMD_ENTRY_MODE; next_rs <= 0;
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        state <= S_LOAD_CGRAM; 
                        is_sent <= 0; 
                        send_idx <= 0;
                    end
                end

                // -------------------------------------------------------------
                // CGRAM 로딩
                // -------------------------------------------------------------
                S_LOAD_CGRAM: begin
                    // 1. 주소 설정 (send_idx == 0)
                    if (send_idx == 0) begin
                        if (!is_sent) begin
                            next_data <= CMD_SET_CGRAM; next_rs <= 0;
                            start_send <= 1; is_sent <= 1;
                        end else if (send_done) begin
                            is_sent <= 0;
                            send_idx <= 1; // 데이터 전송 단계로 이동
                        end
                    end 
                    // 2. 데이터 8바이트 전송 (send_idx 1~8)
                    else if (send_idx <= 8) begin
                        if (!is_sent) begin
                            next_data <= cgram_sanjini[send_idx-1]; 
                            next_rs <= 1; // Data Mode
                            start_send <= 1; is_sent <= 1;
                        end else if (send_done) begin
                            is_sent <= 0;
                            send_idx <= send_idx + 1;
                        end
                    end 
                    // 3. 완료
                    else begin
                        state <= S_READY; 
                        is_sent <= 0;
                    end
                end

                // -------------------------------------------------------------
                // 화면 갱신 루프
                // -------------------------------------------------------------
                S_READY: begin
                    // Line 1 주소 설정
                    if (!is_sent) begin
                        next_data <= CMD_SET_DDRAM; next_rs <= 0;
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        state <= S_DRAW_LINE1;
                        is_sent <= 0;
                        send_idx <= 0;
                    end
                end

                S_DRAW_LINE1: begin
                    if (!is_sent) begin
                        next_data <= get_char_at(0, send_idx);
                        next_rs <= 1; // Data
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        is_sent <= 0;
                        if (send_idx < 15) begin
                            send_idx <= send_idx + 1;
                        end else begin
                            state <= S_MOVE_LINE2; // [이동] 줄바꿈 상태로
                        end
                    end
                end

                S_MOVE_LINE2: begin
                    // Line 2 주소 설정 (안정성 확보)
                    if (!is_sent) begin
                        next_data <= CMD_SET_DDRAM2; next_rs <= 0;
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        state <= S_DRAW_LINE2;
                        is_sent <= 0;
                        send_idx <= 0;
                    end
                end

                S_DRAW_LINE2: begin
                    if (!is_sent) begin
                        next_data <= get_char_at(1, send_idx);
                        next_rs <= 1; 
                        start_send <= 1; is_sent <= 1;
                    end else if (send_done) begin
                        is_sent <= 0;
                        if (send_idx < 15) begin
                            send_idx <= send_idx + 1;
                        end else begin
                            state <= S_DONE;
                            delay_cnt <= 0;
                        end
                    end
                end

                S_DONE: begin
                    // 100ms 대기 (Refresh Rate Control)
                    if (delay_cnt < 5000000) delay_cnt <= delay_cnt + 1;
                    else begin
                        state <= S_READY; 
                        delay_cnt <= 0;
                        is_sent <= 0;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // 4. 화면 내용 결정 함수
    // =========================================================================
    function [7:0] get_char_at;
        input integer row; 
        input integer col; 
        begin
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
                // 1. 산지니 (Custom Char 0)
                if (col == 1) begin 
                    if (row == char_y) get_char_at = 8'h00; 
                end
                // 2. 장애물 ('X')
                if (col == obs_x && row == obs_y) begin
                    get_char_at = "X"; 
                end
                // 3. 바닥 ('_')
                if (row == 1 && col != 1 && !(col == obs_x && row == obs_y)) begin
                    get_char_at = "_";
                end
            end
        end
    endfunction

endmodule


// =============================================================================
// LCD Driver (타이밍 안전성 강화됨)
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
    localparam S_IDLE  = 0;
    localparam S_SETUP = 1;
    localparam S_EN_H  = 2;
    localparam S_EN_L  = 3;
    localparam S_WAIT  = 4;

    reg [2:0] state;
    reg [17:0] cnt; // 카운터 비트 수 증가 (17bit -> 18bit)

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            state <= S_IDLE;
            o_lcd_en <= 0;
            o_lcd_rw <= 0;
            o_done <= 0;
            cnt <= 0;
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
                S_SETUP: begin // 40ns Setup
                    if (cnt < 4) cnt <= cnt + 1;
                    else begin
                        state <= S_EN_H;
                        o_lcd_en <= 1;
                        cnt <= 0;
                    end
                end
                S_EN_H: begin // 230ns Enable Pulse
                    if (cnt < 20) cnt <= cnt + 1;
                    else begin
                        state <= S_EN_L;
                        o_lcd_en <= 0;
                        cnt <= 0;
                    end
                end
                S_EN_L: begin // Hold Time
                    if (cnt < 10) cnt <= cnt + 1;
                    else begin
                        state <= S_WAIT;
                        cnt <= 0;
                    end
                end
                S_WAIT: begin 
                    // [중요 수정] 대기 시간 대폭 증가 (2ms)
                    // Clear 명령(1.53ms) 등 느린 명령도 안전하게 커버하기 위함
                    // 50MHz * 0.002s = 100,000 cycles
                    if (cnt < 100_000) cnt <= cnt + 1; 
                    else begin
                        state <= S_IDLE;
                        o_done <= 1; // 완료 신호 발송
                    end
                end
            endcase
        end
    end
endmodule
