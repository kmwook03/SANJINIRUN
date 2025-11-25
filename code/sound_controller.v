module sound_controller (
    input wire clk,
    input wire rst_n,
    input wire i_btn_jump,
    input wire i_collision,
    
    output reg piezo_out
);
    // 주파수 분주를 위한 카운터 값 (50MHz 기준)
    // 도(C4) ~ 261Hz, 솔(G4) ~ 392Hz 등
    localparam TONE_JUMP = 18'd95000; // 높은 음
    localparam TONE_OVER = 18'd190000; // 낮은 음
    
    reg [17:0] tone_cnt;
    reg [17:0] tone_target;
    reg sound_en;
    reg [24:0] duration_cnt; // 소리 지속 시간

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tone_target <= 0;
            sound_en <= 0;
            duration_cnt <= 0;
        end else begin
            // 우선순위: 충돌(게임오버) > 점프
            if (i_collision) begin // [cite: 94]
                tone_target <= TONE_OVER;
                sound_en <= 1;
                duration_cnt <= 25'd25_000_000; // 0.5초 지속
            end else if (i_btn_jump && !sound_en) begin // [cite: 93]
                tone_target <= TONE_JUMP;
                sound_en <= 1;
                duration_cnt <= 25'd5_000_000; // 0.1초 지속
            end

            // 소리 지속 시간 카운트
            if (sound_en) begin
                if (duration_cnt > 0) duration_cnt <= duration_cnt - 1;
                else sound_en <= 0;
            end
        end
    end

    // 주파수 생성 (Square Wave)
    always @(posedge clk) begin
        if (sound_en && tone_target > 0) begin
            if (tone_cnt >= tone_target) begin
                tone_cnt <= 0;
                piezo_out <= ~piezo_out;
            end else begin
                tone_cnt <= tone_cnt + 1;
            end
        end else begin
            piezo_out <= 0;
        end
    end
endmodule