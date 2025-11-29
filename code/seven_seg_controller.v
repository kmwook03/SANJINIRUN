module seven_seg_controller (
    input wire clk,
    input wire rst_n,

    input wire [1:0] current_state,
    input wire [3:0] countdown_val,
    input wire [15:0] play_time,
    
    output reg [7:0] seg_out, // 개별 7-seg 패턴 (a~g)
    output reg [7:0] seg_en
);

    // -------------------------------------------------------
    // Hex to 7-Seg 디코딩 함수 (Active Low: 0이 켜짐)
    // -------------------------------------------------------
    function [6:0] hex2seg;
        input [3:0] hex;
        begin
            case(hex)
                4'h0: hex2seg = 7'b0111111; // 0
                4'h1: hex2seg = 7'b0000110; // 1
                4'h2: hex2seg = 7'b1011011; // 2
                4'h3: hex2seg = 7'b1001111; // 3
                4'h4: hex2seg = 7'b1100110; // 4
                4'h5: hex2seg = 7'b1101101; // 5
                4'h6: hex2seg = 7'b1111101; // 6
                4'h7: hex2seg = 7'b0000111; // 7 (or 1011000)
                4'h8: hex2seg = 7'b1111111; // 8
                4'h9: hex2seg = 7'b1101111; // 9
                
                default: hex2seg = 7'b0000000; // OFF
            endcase
        end
    endfunction

    localparam S_COUNTDOWN = 2'b01;
    localparam S_RUN       = 2'b10;
    
    reg [6:0] seg_buffer [0:7];
    integer i;

    reg [16:0] scan_cnt;
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) scan_cnt <= 0;
        else scan_cnt <= scan_cnt + 1;
    end

    wire [2:0] digit_idx = scan_cnt[16:14];
    
    always @(*) begin
        // 제안서에 따르면 8 Array 7-Segment를 사용합니다.
        // 현재는 첫 번째 자리(맨 오른쪽)만 켜도록 설정 (Active Low: 0이 켜짐)
         for(i=0; i<8; i=i+1) seg_buffer[i] = 7'b0000000;

        if (current_state == S_COUNTDOWN) begin
            // 0번(맨 오른쪽) 자리에 카운트다운 값 넣기
            seg_buffer[0] = hex2seg(countdown_val);
            
        end else if (current_state == S_RUN) begin
            // 플레이 시간 자릿수별로 쪼개서 넣기
            // seg_buffer[0] : 1의 자리
            // seg_buffer[1] : 10의 자리
            // seg_buffer[2] : 100의 자리 ...
            seg_buffer[0] = hex2seg(play_time % 10);
            seg_buffer[1] = hex2seg((play_time / 10) % 10);
            seg_buffer[2] = hex2seg((play_time / 100) % 10);
            seg_buffer[3] = hex2seg((play_time / 1000) % 10);
        end
        
        if (current_state != S_COUNTDOWN && current_state != S_RUN) begin
            seg_out = 8'b00000000;
            seg_en  = 8'b00000000;
        end
        else begin
            seg_out = {1'b0, seg_buffer[digit_idx]};
        
            case (digit_idx)
                3'd0: seg_en = 8'b00000001;
                3'd1: seg_en = 8'b00000010;
                3'd2: seg_en = 8'b00000100;
                3'd3: seg_en = 8'b00001000;
                3'd4: seg_en = 8'b00010000;
                3'd5: seg_en = 8'b00100000;
                3'd6: seg_en = 8'b01000000;
                3'd7: seg_en = 8'b10000000;
                default: seg_en = 8'b00000000;
            endcase
        end
    end            
endmodule
