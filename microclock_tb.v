module microclock_tb();
    reg clk = 0;
    reg rst = 0;
    microprocessor uut(.clk(clk), .rst(rst));
    always #5 clk = ~clk;

    initial begin
        rst = 1; #100 rst = 0;
        $display("--- Starting 8-bit Factorial Simulation ---");
        $monitor("Time: %t | PC: %d | R3: %d | R4 (Result): %d | FlagGT: %b", 
                 $time, uut.cu1.counter, uut.eu1.registers[3], 
                 uut.eu1.registers[4], uut.cu1.flag[4]);
        #15000;
        $display("========================================");
        $display("Final Result in R4: %d", uut.eu1.registers[4]);
        $display("========================================");
        $finish;
    end
endmodule