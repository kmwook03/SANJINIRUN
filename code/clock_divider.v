module Clock_Divider (
    input wire clk,        // 50MHz System Clock
    input wire rst_n,      // Reset (Active Low)
    output reg tick_1hz,   // 1초에 한 번 1이 됨
    output reg tick_60hz   // 1초에 60번 1이 됨
);

    // 상수 정의 (50MHz 기준)
    parameter CNT_MAX_1HZ = 50000000 - 1; 
    parameter CNT_MAX_60HZ = 833333 - 1;

    reg [25:0] cnt_1hz;
    reg [19:0] cnt_60hz;

    // 1Hz 생성
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1hz <= 0;
            tick_1hz <= 0;
        end else begin
            if (cnt_1hz >= CNT_MAX_1HZ) begin
                cnt_1hz <= 0;
                tick_1hz <= 1;
            end else begin
                cnt_1hz <= cnt_1hz + 1;
                tick_1hz <= 0;
            end
        end
    end

    // 60Hz 생성
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_60hz <= 0;
            tick_60hz <= 0;
        end else begin
            if (cnt_60hz >= CNT_MAX_60HZ) begin
                cnt_60hz <= 0;
                tick_60hz <= 1;
            end else begin
                cnt_60hz <= cnt_60hz + 1;
                tick_60hz <= 0;
            end
        end
    end
endmodule