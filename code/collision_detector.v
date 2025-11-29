module collision_detector (
    input wire [7:0] char_x,
    input wire [7:0] char_y,
    input wire [7:0] obs_x,
    input wire [7:0] obs_y,
    
    output reg collision_detected
);
    // 충돌 박스 크기 정의 (예: 5x5 픽셀)
    localparam SIZE = 5;

    always @(*) begin
        // AABB (Axis-Aligned Bounding Box) 충돌 감지 로직
        // X축이 겹치고 AND Y축이 겹치면 충돌 [cite: 91]
        if ( (char_x == obs_x) && (char_y == obs_y) ) begin
            collision_detected = 1'b1;
        end else begin
            collision_detected = 1'b0;
        end
    end
endmodule
