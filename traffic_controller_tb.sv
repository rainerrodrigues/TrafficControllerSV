/*
Simple testbench for traffic_controller.sv
Simulates pedestrian push and emergency event.
*/
`timescale 1ns/1ps
module tb_traffic;

```
// clock
reg clk = 0;
always #5 clk = ~clk; // 100MHz pretend (irrelevant because prescaler)

reg rst_n = 0;
reg ped_req_btn = 0;
reg emergency = 0;
reg emergency_clear = 0;

// outputs
wire ns_green, ns_yellow, ew_green, ew_yellow, ped_walk;

// instantiate with small PRESCALE_MAX for fast sim
traffic_controller #(
    .PRESCALE_MAX(2), // every 2 clocks -> a tick (fast simulation)
    .T_NS_GREEN_TICKS(6),
    .T_NS_YELLOW_TICKS(2),
    .T_EW_GREEN_TICKS(5),
    .T_EW_YELLOW_TICKS(2),
    .T_PED_WALK_TICKS(4),
    .T_ALL_RED_TICKS(1),
    .T_EMG_GREEN_TICKS(8)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .ped_req_btn(ped_req_btn),
    .emergency(emergency),
    .emergency_clear(emergency_clear),
    .ns_green(ns_green),
    .ns_yellow(ns_yellow),
    .ew_green(ew_green),
    .ew_yellow(ew_yellow),
    .ped_walk(ped_walk)
);

initial begin
    $dumpfile("tb_traffic.vcd");
    $dumpvars(0, tb_traffic);

    // reset
    rst_n = 0;
    #20;
    rst_n = 1;

    // let normal sequence run a bit
    #200;

    // issue a pedestrian request
    $display("-> Pedestrian request at time %0t", $time);
    ped_req_btn = 1;
    #10 ped_req_btn = 0; // pulse

    #300;

    // trigger emergency
    $display("-> Emergency ON at time %0t", $time);
    emergency = 1;
    #200;

    // clear emergency
    $display("-> Emergency CLEAR at time %0t", $time);
    emergency_clear = 1;
    #10 emergency_clear = 0;
    emergency = 0;

    #400;

    $display("Simulation finished at time %0t", $time);
    $finish;
end
```

endmodule
