/* 
Traffic light controller
Author: Rainer Rodrigues
Date: 2024-06-20
Keywords: SystemVerilog, Traffic Light, FSM
License: MIT
NS = north-south
EW = east-west
*/

// defining the top module for traffic light controller
module traffic_controller #(
    parameter integer PRESCALE_MAX = 1000, // clocks per cycle
    parameter integer T_NS_GREEN = 10,   // NS green time in cycles
    parameter integer T_NS_YELLOW = 3,   // NS yellow time in cycles
    parameter integer T_EW_GREEN = 8,   // EW green time in cycles
    parameter integer T_EW_YELLOW = 3    // EW yellow time in cycles
    parameter integer T_PEDESTRIAN = 6  // pedestrian crossing time in cycles
    parameter integer T_ALL_RED = 2     // all red time in cycles
    parameter integer T_EMERGENCY = 15 // emergency vehicle green time in cycles
) (
    input wire clk,
input wire rst_n,
// inputs
input wire ped_req_btn, // pedestrian request (level or pulse)
input wire emergency, // emergency signal (active-high)
input wire emergency_clear, // clear emergency (active-high)
// outputs (one-hot style for lights)
output reg ns_green,
output reg ns_yellow,
output reg ew_green,
output reg ew_yellow,
output reg ped_walk // pedestrian walk signal
);

// ---- prescaler/tick generator ----
reg [31:0] prescale_cnt;
wire tick;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prescale_cnt <= 0;
    end else begin
        if (prescale_cnt >= PRESCALE_MAX-1)
            prescale_cnt <= 0;
        else
            prescale_cnt <= prescale_cnt + 1;
    end
end
assign tick = (prescale_cnt == PRESCALE_MAX-1);

// ---- pedestrian request latch (debounce omitted) ----
reg ped_req;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) ped_req <= 1'b0;
    else if (ped_req_btn) ped_req <= 1'b1;
    else if (ped_walk) ped_req <= 1'b0; // cleared when walking served
end

// ---- emergency latch ----
reg emg_active;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) emg_active <= 1'b0;
    else if (emergency) emg_active <= 1'b1;
    else if (emergency_clear) emg_active <= 1'b0;
end

// ---- FSM states ----
typedef enum logic [3:0] {
    S_NS_GREEN,
    S_NS_YELLOW,
    S_ALL_RED_1,
    S_EW_GREEN,
    S_EW_YELLOW,
    S_ALL_RED_2,
    S_PED_WALK,
    S_EMG_ALL_RED,
    S_EMG_GREEN
} state_t;

state_t state, next_state;

// countdown timer on ticks
reg [31:0] timer;
wire timer_expired = (timer == 0);

// next-state logic (combinational)
always @(*) begin
    next_state = state; // default hold
    if (emg_active) begin
        // emergency preempts normal sequencing unless we're already handling it
        case (state)
            S_EMG_GREEN: if (timer_expired) next_state = S_EMG_GREEN; // keep until cleared externally
            default: next_state = S_EMG_ALL_RED;
        endcase
    end else begin
        case (state)
            S_NS_GREEN:  if (timer_expired) next_state = S_NS_YELLOW;
            S_NS_YELLOW: if (timer_expired) next_state = S_ALL_RED_1;
            S_ALL_RED_1: begin
                if (timer_expired) begin
                    // if pedestrian requested and safe to serve now, go to PED_WALK
                    if (ped_req) next_state = S_PED_WALK;
                    else next_state = S_EW_GREEN;
                end
            end
            S_EW_GREEN:  if (timer_expired) next_state = S_EW_YELLOW;
            S_EW_YELLOW: if (timer_expired) next_state = S_ALL_RED_2;
            S_ALL_RED_2: begin
                if (timer_expired) begin
                    if (ped_req) next_state = S_PED_WALK;
                    else next_state = S_NS_GREEN;
                end
            end
            S_PED_WALK: begin
                if (timer_expired) next_state = S_ALL_RED_2; // after walk, go to all-red then resume
            end
            default: next_state = S_NS_GREEN;
        endcase
    end
end

// synchronous state+timer update on ticks (we only decrement timer on ticks to simplify)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_NS_GREEN;
        timer <= T_NS_GREEN_TICKS;
    end else begin
        // synchronous state change on tick
        if (tick) begin
            // handle emergency immediate transitions
            if (emg_active && state != S_EMG_GREEN && state != S_EMG_ALL_RED) begin
                // go to EMG_ALL_RED buffer first
                state <= S_EMG_ALL_RED;
                timer <= T_ALL_RED_TICKS;
            end else begin
                // normal next-state when timer expires
                if (timer == 0) begin
                    // if entering emergency and allowed, we can also go to EMG_GREEN
                    if (emg_active) begin
                        if (state == S_EMG_ALL_RED) begin
                            state <= S_EMG_GREEN;
                            timer <= T_EMG_GREEN_TICKS;
                        end else state <= S_EMG_ALL_RED;
                    end else begin
                        // move to calculated next_state
                        state <= next_state;
                        // set timer for next state
                        case (next_state)
                            S_NS_GREEN:  timer <= T_NS_GREEN_TICKS;
                            S_NS_YELLOW: timer <= T_NS_YELLOW_TICKS;
                            S_ALL_RED_1: timer <= T_ALL_RED_TICKS;
                            S_EW_GREEN:  timer <= T_EW_GREEN_TICKS;
                            S_EW_YELLOW: timer <= T_EW_YELLOW_TICKS;
                            S_ALL_RED_2: timer <= T_ALL_RED_TICKS;
                            S_PED_WALK:  timer <= T_PED_WALK_TICKS;
                            S_EMG_ALL_RED: timer <= T_ALL_RED_TICKS;
                            S_EMG_GREEN: timer <= T_EMG_GREEN_TICKS;
                            default: timer <= T_NS_GREEN_TICKS;
                        endcase
                    end
                end else begin
                    // decrement timer
                    timer <= timer - 1;
                end
            end
        end // tick
    end
end

// outputs from state (combinatorial for clarity)
always @(*) begin
    // defaults
    ns_green  = 1'b0;
    ns_yellow = 1'b0;
    ew_green  = 1'b0;
    ew_yellow = 1'b0;
    ped_walk  = 1'b0;

    case (state)
        S_NS_GREEN: begin ns_green = 1'b1; end
        S_NS_YELLOW: begin ns_yellow = 1'b1; end
        S_EW_GREEN: begin ew_green = 1'b1; end
        S_EW_YELLOW: begin ew_yellow = 1'b1; end
        S_PED_WALK: begin ped_walk = 1'b1; end
        S_EMG_GREEN: begin
            // in emergency green give both NS & EW red? Choose to give NS green as example
            ns_green = 1'b1; // or route based on emergency direction input (not implemented here)
        end
        S_ALL_RED_1, S_ALL_RED_2, S_EMG_ALL_RED: begin /* all red */ end
        default: begin ns_green = 1'b0; end
    endcase
end
endmodule
