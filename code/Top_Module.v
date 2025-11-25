module Top_Module (
    input wire clk,
    input wire rst_n,
    input wire btn,
    output reg [6:0] seg
);

    // ----------------------------
    // 버튼 동기화 & 엣지 검출
    // ----------------------------
    reg btn_ff0, btn_ff1;

    always @(posedge clk or negedge rst_n) begin
        if (rst_n) begin
            btn_ff0 <= 1'b0;
            btn_ff1 <= 1'b0;
        end else begin
            btn_ff0 <= btn;
            btn_ff1 <= btn_ff0;
        end
    end

    wire btn_rise = btn_ff0 & ~btn_ff1;

    // ----------------------------
    // 상태 정의 (Verilog 방식)
    // ----------------------------
    parameter S_IDLE = 2'b00;
    parameter S_3    = 2'b01;
    parameter S_2    = 2'b10;
    parameter S_1    = 2'b11;

    reg [1:0] state, next_state;

    // ----------------------------
    // 딜레이 카운터
    // ----------------------------
    parameter DELAY = 25_000_000;

    reg [31:0] cnt;

    wire cnt_done = (cnt == DELAY - 1);

    always @(posedge clk or negedge rst_n) begin
        if (rst_n)
            cnt <= 32'd0;
        else begin
            if (state == S_IDLE)
                cnt <= 32'd0;
            else if (cnt_done)
                cnt <= 32'd0;
            else
                cnt <= cnt + 1;
        end
    end

    // ----------------------------
    // FSM next_state
    // ----------------------------
    always @(*) begin
        case (state)
            S_IDLE: begin
                if (btn_rise) next_state = S_3;
                else next_state = S_IDLE;
            end

            S_3: begin
                if (cnt_done) next_state = S_2;
                else next_state = S_3;
            end

            S_2: begin
                if (cnt_done) next_state = S_1;
                else next_state = S_2;
            end

            S_1: begin
                if (cnt_done) next_state = S_IDLE;
                else next_state = S_1;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // ----------------------------
    // 상태 레지스터
    // ----------------------------
    always @(posedge clk or negedge rst_n) begin
        if (rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // ----------------------------
    // 7세그 출력
    // ----------------------------
    localparam SEG_1   = 7'b0000110;
    localparam SEG_2   = 7'b1011011;
    localparam SEG_3   = 7'b1001111;
    localparam SEG_OFF = 7'b1111111; //

    always @(*) begin
        case (state)
            S_3: seg = SEG_3;
            S_2: seg = SEG_2;
            S_1: seg = SEG_1;
            default: seg = SEG_OFF;
        endcase
    end

endmodule
