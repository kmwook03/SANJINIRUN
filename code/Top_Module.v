module Top_Module (
    input wire clk,
    input wire rst_n,
    input wire btn,
    input wire jump_btn,
    
    output wire [4:0] life,
    output wire [6:0] stage_seg,
    output wire [6:0] seg,
    output wire [7:0] seg_en,
    output wire [7:0] o_lcd_data,
    output wire o_lcd_rs,
    output wire o_lcd_rw,
    output wire o_lcd_en,
    output wire piezo
);

    wire [2:0] w_current_state;     // FSM 상태 신호
    wire w_game_active;             // 게임 활성 신호
    wire w_timer_en;                // 타이머 활성 신호
    wire w_system_init;             // 초기화 신호
    wire [2:0] w_stage;             // 스테이지 3개
    wire w_stage_cleared;
    
    wire w_countdown_done;          // Timer -> FSM (카운트다운 끝)
    wire w_collision;               // Collision -> FSM (충돌 발생)
    
    wire [3:0] w_countdown_val;     // Timer -> 7-Seg
    wire [15:0] w_play_time;        // Timer -> 7-Seg
    
    wire w_char_y;            // Char -> Collision
    wire [7:0] w_obs_x, w_obs_y;
    
    game_state_controller u_fsm (
        .clk              (clk),
        .rst_n            (rst_n),
        .i_btn_start      (btn),      // 외부 버튼 연결
        .i_countdown_done (w_countdown_done), // 내부 와이어 연결 (Timer에서 옴)
        .i_collision      (w_collision),      // 내부 와이어 연결 (Collision에서 옴)
        .i_stage_cleared  (w_stage_cleared),
        .stage            (w_stage),
        .life             (life),
        .current_state    (w_current_state),  // 다른 모듈들로 뿌려줌
        .o_system_init    (w_system_init),
        .o_game_active    (w_game_active)     // Character, Obstacle 모듈로 감
    );  
  
    timer u_timer(
        .clk    (clk),
        .rst_n  (rst_n),
        .current_state  (w_current_state),
        .o_system_init  (w_system_init),
        .countdown_val  (w_countdown_val),
        .countdown_done (w_countdown_done),
        .stage          (w_stage),
        .play_time  (w_play_time),
        .stage_cleared (w_stage_cleared)
     );

     seven_seg_controller u_seg(
        .clk    (clk),
        .rst_n  (rst_n),
        
        .current_state  (w_current_state),
        .countdown_val  (w_countdown_val),
        .play_time  (w_play_time),
        
        .stage      (w_stage),
        .stage_seg  (stage_seg),
        .seg_out    (seg),
        .seg_en     (seg_en)
    );
    
    lcd_controller u_lcd (
        .clk            (clk),
        .rst_n          (rst_n),
        .current_state  (w_current_state), // FSM에서 상태 받기
        .stage          (w_stage),
        .char_y         (w_char_y),        // 캐릭터 위치 받기 (점프 확인용)
        .obs_x          (w_obs_x),         // 장애물 위치 받기 (표시용)
        .obs_y          (w_obs_y),

        .o_lcd_data     (o_lcd_data),
        .o_lcd_rs       (o_lcd_rs),
        .o_lcd_rw       (o_lcd_rw),
        .o_lcd_en       (o_lcd_en)
    );  
    character_controller u_char (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_game_active  (w_game_active),      // FSM에서 받아옴
        .i_btn_jump     (jump_btn),         // 외부 버튼 연결
        
        .char_y         (w_char_y),           // Collision으로 보냄
        .char_x         (w_char_x)                    // 고정값이면 연결 안 하거나 dummy 연결
    );
    sound_controller u_sound (
        .clk            (clk),
        .rst          (rst_n),
        .i_btn_jump     (jump_btn),
        .i_collision    (w_collision),
        .current_state    (w_current_state),
        .i_stage_cleared  (w_stage_cleared),
        .piezo_out      (piezo)             // 실제 외부 핀으로 나감!
    );

    obstacle_controller u_obs(
        .clk            (clk),
        .rst_n          (rst_n),
        .i_game_active  (w_game_active),
        .current_state  (w_current_state),
        .stage          (w_stage), 
        .obs_x  (w_obs_x),
        .obs_y  (w_obs_y)
    
    );
    
    collision_detector  u_det(
        .char_x         (w_char_x),           // Collision으로 보냄
        .char_y         (w_char_y),    
        .obs_x  (w_obs_x),
        .obs_y  (w_obs_y),
        
        .collision_detected (w_collision)
    );
endmodule
