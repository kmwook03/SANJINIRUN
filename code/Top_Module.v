module Top_Sanjini_Run (
    input  wire       clk,          // 50MHz
    input  wire       rst,          // 보드 리셋 버튼 (Active High 가정)
    input  wire       i_btn_start,
    input  wire       i_btn_jump,

    output wire [7:0] o_lcd_data,
    output wire       o_lcd_rs,
    output wire       o_lcd_rw,
    output wire       o_lcd_en,
    
    output wire [7:0] o_seg_data,
    output wire [7:0] o_seg_sel,
    output wire       o_piezo
);

    // =========================================================================
    // 1. 내부 신호 및 리셋 처리
    // =========================================================================
    
    // [중요] 리셋 신호 반전 (Active High 버튼 -> Active Low 모듈 입력)
    wire rst_n;
    assign rst_n = ~rst;  // 버튼을 안 눌렀을 때(0) -> 1(동작), 누르면(1) -> 0(리셋)

    wire tick_1hz, tick_60hz;
    wire start_clean, jump_clean;
    wire [1:0] current_state;
    
    wire [3:0] timer_sec;
    wire [7:0] char_y;
    
    // [수정] 장애물 모듈이 없으므로 임시로 0 할당 (Floating 방지)
    wire [7:0] obs_x, obs_y;
    assign obs_x = 8'd0; 
    assign obs_y = 8'd0;

    // 기타 신호들
    wire timer_done, collision_flag;
    assign collision_flag = 0; // 충돌 없음 (무적 모드)

    // =========================================================================
    // 2. 모듈 연결 (rst 대신 rst_n 연결 확인!)
    // =========================================================================

    Clock_Divider u_clk_div (
        .clk(clk),
        .rst_n(rst_n),      // [수정] rst -> rst_n
        .tick_1hz(tick_1hz),
        .tick_60hz(tick_60hz)
    );

    Button_Debounce u_btn_start_inst (
        .clk(clk),
        .rst(rst),          // 디바운스는 내부 로직에 따라 rst/rst_n 맞춤 (여기선 rst 유지)
        .i_btn(i_btn_start),
        .o_btn_clean(start_clean)
    );

    Button_Debounce u_btn_jump_inst (
        .clk(clk),
        .rst(rst),
        .i_btn(i_btn_jump),
        .o_btn_clean(jump_clean)
    );

    game_state_controller u_fsm (
        .clk(clk),
        .rst(rst),          // FSM 코드 확인 필요 (Active High/Low) -> 보통 rst 쓰면 High
        .start_signal(start_clean),
        .collision_signal(collision_flag),
        .timer_done(timer_done),
        .current_state(current_state)
    );

    Timer u_timer (
        .clk(clk),
        .rst(rst),          // Timer 코드 확인 필요
        .tick_1hz(tick_1hz),
        .current_state(current_state),
        .o_time(timer_sec),
        .o_timer_done(timer_done)
    );

    Character_Controller u_char_ctrl (
        .clk(clk),
        .rst_n(rst_n),      // [수정] Active Low 입력 받음
        .tick_60hz(tick_60hz),
        .jump_signal(jump_clean),
        .current_state(current_state),
        .o_char_y(char_y)
    );

    LCD_Controller u_lcd (
        .clk(clk),
        .rst_n(rst_n),      // [수정] Active Low 입력 받음
        .current_state(current_state),
        .char_y(char_y),
        .obs_x(obs_x),      // 위에서 0으로 묶어둔 값 들어감
        .obs_y(obs_y),
        .o_lcd_data(o_lcd_data),
        .o_lcd_rs(o_lcd_rs),
        .o_lcd_en(o_lcd_en),
        .o_lcd_rw(o_lcd_rw)
    );

endmodule
