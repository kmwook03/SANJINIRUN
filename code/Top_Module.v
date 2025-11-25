module Top_Module (
    // 실제 FPGA 보드 핀과 연결되는 포트들
    input wire clk,                 // 시스템 클럭
    input wire rst_n,               // 리셋 버튼
    input wire i_btn_start,         // 시작 버튼 (외부 입력)
    input wire i_btn_jump,          // 점프 버튼 (외부 입력)
    
    // 외부로 나가는 실제 출력 (LED, 7-Segment, Piezo 등)
    output wire [6:0] o_seg_out,    // 7-Segment 패턴
    output wire [7:0] o_seg_en,     // 7-Segment 자리 선택
    output wire o_piezo             // 피에조 스피커
    // LCD 관련 핀 등은 여기에 추가
);

    // -------------------------------------------------------
    // 내부 연결용 와이어 (Wire) 선언
    // : 모듈끼리 신호를 주고받는 가상의 전선
    // -------------------------------------------------------
    wire [1:0] w_current_state;     // FSM 상태 신호
    wire w_game_active;             // 게임 활성 신호
    wire w_timer_en;                // 타이머 활성 신호
    wire w_system_init;             // 초기화 신호
    
    wire w_countdown_done;          // Timer -> FSM (카운트다운 끝)
    wire w_collision;               // Collision -> FSM (충돌 발생)
    
    wire [3:0] w_countdown_val;     // Timer -> 7-Seg
    wire [15:0] w_play_time;        // Timer -> 7-Seg
    
    wire [7:0] w_char_y;            // Char -> Collision
    wire [7:0] w_obs_x, w_obs_y;    // Obstacle -> Collision

    // -------------------------------------------------------
    // 1. Game State Controller (Main FSM) 인스턴스
    // -------------------------------------------------------
    game_state_controller u_fsm (
        .clk              (clk),
        .rst_n            (rst_n),
        .i_btn_start      (i_btn_start),      // 외부 버튼 연결
        .i_countdown_done (w_countdown_done), // 내부 와이어 연결 (Timer에서 옴)
        .i_collision      (w_collision),      // 내부 와이어 연결 (Collision에서 옴)
        
        .current_state    (w_current_state),  // 다른 모듈들로 뿌려줌
        .o_system_init    (w_system_init),
        .o_timer_en       (w_timer_en),
        .o_game_active    (w_game_active)     // Character, Obstacle 모듈로 감
    );

lcd_controller u_lcd (
        .clk            (clk),
        .rst_n          (rst_n),
        .current_state  (w_current_state), // FSM에서 상태 받기
        .char_y         (w_char_y),        // 캐릭터 위치 받기 (점프 확인용)
        .obs_x          (w_obs_x),         // 장애물 위치 받기 (표시용)
        
        // 실제 FPGA 핀으로 나가는 신호들
        .lcd_rs         (o_lcd_rs),
        .lcd_rw         (o_lcd_rw),
        .lcd_e          (o_lcd_e),
        .lcd_data       (o_lcd_data)
    );
    // -------------------------------------------------------
    // 2. Timer 모듈 인스턴스
    // -------------------------------------------------------
    timer u_timer (
        .clk            (clk),
        .rst_n          (rst_n),
        .current_state  (w_current_state),    // FSM에서 받아옴
        
        .countdown_val  (w_countdown_val),    // 7-Seg로 보냄
        .countdown_done (w_countdown_done),   // FSM으로 보냄
        .play_time      (w_play_time)         // 7-Seg로 보냄
    );

    // -------------------------------------------------------
    // 3. Character Controller 인스턴스
    // -------------------------------------------------------
    character_controller u_char (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_game_active  (w_game_active),      // FSM에서 받아옴
        .i_btn_jump     (i_btn_jump),         // 외부 버튼 연결
        
        .char_y         (w_char_y),           // Collision으로 보냄
        .char_x         ()                    // 고정값이면 연결 안 하거나 dummy 연결
    );
    
    // -------------------------------------------------------
    // 4. Obstacle Controller 인스턴스
    // -------------------------------------------------------
    obstacle_controller u_obs (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_game_active  (w_game_active),      // FSM에서 받아옴
        
        .obs_x          (w_obs_x),            // Collision으로 보냄
        .obs_y          (w_obs_y)             // Collision으로 보냄
    );

    // -------------------------------------------------------
    // 5. Collision Detector 인스턴스
    // -------------------------------------------------------
    collision_detector u_col (
        .char_x             (8'd20),          // 캐릭터 X는 고정값이라 가정
        .char_y             (w_char_y),       // Character 모듈에서 옴
        .obs_x              (w_obs_x),        // Obstacle 모듈에서 옴
        .obs_y              (w_obs_y),        // Obstacle 모듈에서 옴
        
        .collision_detected (w_collision)     // 결과값을 FSM으로 보냄!
    );

    // -------------------------------------------------------
    // 6. 7-Segment Controller & Sound Controller 연결
    // -------------------------------------------------------
    seven_seg_controller u_seg (
        .current_state  (w_current_state),
        .countdown_val  (w_countdown_val),
        .play_time      (w_play_time),
        
        .seg_out        (o_seg_out),          // 실제 외부 핀으로 나감!
        .seg_en         (o_seg_en)            // 실제 외부 핀으로 나감!
    );
    
    sound_controller u_sound (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_btn_jump     (i_btn_jump),
        .i_collision    (w_collision),
        
        .piezo_out      (o_piezo)             // 실제 외부 핀으로 나감!
    );

endmodule
