module game_state_controller(
    input wire clk,
    input wire rst,
    input wire start_signal,
    input wire collision_signal,
    input wire timer_done,
    output reg [1:0] current_state
);

    localparam IDLE = 2'b00;
    localparam COUNTDOWN = 2'b01;
    localparam RUN = 2'b10;
    localparam GAMEOVER = 2'b11;
    
    reg [1:0] next_state;
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end
    
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start_signal) next_state = COUNTDOWN;
                else next_state = IDLE;
            end
            COUNTDOWN: begin
                if (timer_done) next_state = RUN;
                else next_state = COUNTDOWN;
            end
            RUN: begin
                if (collision_signal) next_state = GAMEOVER;
                else next_state = RUN;
            end
            GAMEOVER: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
endmodule
