module Top_Module (
    // -------------------------------------------------------
    // [중요] 여기에 선언된 포트만 Vivado I/O Ports에 나타납니다.
    // -------------------------------------------------------
    input wire clk,                 // 시스템 클럭
    input wire rst_n,               // 리셋 버튼
    input wire i_btn_start,         // 시작 버튼
    input wire i_btn_jump,          // 점프 버튼
    
    // 7-Segment & Piezo 출력
    output wire [6:0] o_seg_out,    
    output wire [7:0] o_seg_en,     
    output wire o_piezo,             

    // [추가됨] Text LCD 출력 (이 부분이 빠져 있어서 안 떴던 겁니다)
    output wire o_lcd_rs,
    output wire o_lcd_rw,
    output wire o_lcd_e,
    output wire [7:0] o_lcd_data
);

    // -------------------------------------------------------
    // 내부 연결용 와이어 (Wire)
    // -------------------------------------------------------
    wire [1:0] w_current_state;     
    wire w_game_active;             
    wire w_timer_en;                
    wire w_system_init;             
    
    wire w_countdown_done;          
    wire w_collision;               
    
    wire [3:0] w_countdown_val;     
    wire [15:0] w_play_time;        
    
    wire [7:0] w_char_y;            
    wire [7:0] w_obs_x, w_obs_y;    

    // -------------------------------------------------------
    // 1. Game State Controller (Main FSM)
    // -------------------------------------------------------
    game_state_controller u_fsm (
        .clk              (clk),
        .rst_n            (rst_n),
        .i_btn_start      (i_btn_start),
        .i_countdown_done (w_countdown_done),
        .i_collision      (w_collision),
        
        .current_state    (w_current_state),
        .o_system_init    (w_system_init),
        .o_timer_en       (w_timer_en),
        .o_game_active    (w_game_active)
    );

    // -------------------------------------------------------
    // 2. Timer 모듈
    // -------------------------------------------------------
    timer u_timer (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_enable       (w_timer_en),
        .current_state  (w_current_state),
        
        .countdown_val  (w_countdown_val),
        .countdown_done (w_countdown_done),
        .play_time      (w_play_time)
    );

    // -------------------------------------------------------
    // 3. Character Controller
    // -------------------------------------------------------
    character_controller u_char (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_game_active  (w_game_active),
        .i_btn_jump     (i_btn_jump),
        
        .char_y         (w_char_y),
        .char_x         () 
    );
    
    // -------------------------------------------------------
    // 4. Obstacle Controller
    // -------------------------------------------------------
    obstacle_controller u_obs (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_game_active  (w_game_active),
        
        .obs_x          (w_obs_x),
        .obs_y          (w_obs_y)
    );

    // -------------------------------------------------------
    // 5. Collision Detector
    // -------------------------------------------------------
    collision_detector u_col (
        .char_x             (8'd20), 
        .char_y             (w_char_y),
        .obs_x              (w_obs_x),
        .obs_y              (w_obs_y),
        .collision_detected (w_collision)
    );

    // -------------------------------------------------------
    // 6. Output Controllers (Seg, Sound, LCD)
    // -------------------------------------------------------
    seven_seg_controller u_seg (
        .current_state  (w_current_state),
        .countdown_val  (w_countdown_val),
        .play_time      (w_play_time),
        .seg_out        (o_seg_out),
        .seg_en         (o_seg_en)
    );
    
    sound_controller u_sound (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_btn_jump     (i_btn_jump),
        .i_collision    (w_collision),
        .piezo_out      (o_piezo)
    );

    // [이 부분도 연결되어 있어야 합니다]
    lcd_controller u_lcd (
        .clk            (clk),
        .rst_n          (rst_n),
        .current_state  (w_current_state),
        .char_y         (w_char_y),
        .obs_x          (w_obs_x),
        
        // 여기가 Top Module의 출력 핀과 연결됨
        .lcd_rs         (o_lcd_rs),
        .lcd_rw         (o_lcd_rw),
        .lcd_e          (o_lcd_e),
        .lcd_data       (o_lcd_data)
    );

endmodule
