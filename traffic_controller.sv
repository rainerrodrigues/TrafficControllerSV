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
    
)
