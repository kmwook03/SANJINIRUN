module seven_seg_controller (
    input wire [1:0] current_state,
    input wire [3:0] countdown_val,
    input wire [15:0] play_time,
    
    output reg [6:0] seg_out, // 개별 7-seg 패턴 (a~g)
    output reg [7:0] seg_en   // 8 Array 7-Seg 자리 선택
);
    // Hex to 7-Seg 디코딩 함수 (생략 가능하나 이해를 위해 포함)
    function [6:0] hex2seg;
        input [3:0] hex;
        case(hex)
            4'h0: hex2seg = 7'b1000000; // 0 (Active Low 기준)
            4'h1: hex2seg = 7'b1111001; // 1
            4'h2: hex2seg = 7'b0100100; // 2
            4'h3: hex2seg = 7'b0110000; // 3
            // ... 나머지 생략 ...
            default: hex2seg = 7'b1111111; // OFF
        endcase
    endfunction

    localparam S_COUNTDOWN = 2'b01;
    localparam S_RUN       = 2'b10;

    always @(*) begin
        seg_en = 8'b11111110; // 첫 번째 자리만 사용 예시 (Multiplexing 필요 시 확장)
        
        case (current_state)
            S_COUNTDOWN: begin
                // [cite: 74] 타이머 카운트다운 값 표시
                seg_out = hex2seg(countdown_val);
            end
            S_RUN: begin
                // [cite: 83] 플레이 시간 하위 4비트 표시 (예시)
                seg_out = hex2seg(play_time[3:0]);
            end
            default: seg_out = 7'b1111111; // OFF
        endcase
    end
endmodule