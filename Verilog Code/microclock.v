module microprocessor(input clk, input rst);
    wire [7:0] Flag;
    wire [4:0] address;
    wire [7:0] databus11, databus1, databus2;
    wire read, write, store, load, ldi;
    wire [2:0] controllines;
    reg [7:0] databus;

    mainmemory mm1(clk, address, databus1, read, write, load, store, databus2);		
    CU cu1(clk, rst, Flag, write, read, address, store, load, controllines, ldi, databus11);
    EU eu1(clk, rst, read, write, store, load, ldi, address, controllines, databus, Flag, databus1);

    always @(*) databus = (ldi) ? databus11 : databus2;
endmodule

module mainmemory(input clk, input [4:0] address, input [7:0] data_in, 
                  input read, input write, input load, input store, output reg [7:0] data_out);
    reg [7:0] RAM [31:0];
    always @(posedge clk) if(store && write) RAM[address] <= data_in;
    always @(*) if(read && load) data_out = RAM[address]; else data_out = 8'bz;
endmodule

// Control Unit Module
module CU(
    input clk,                  // clock สัญญาณนาฬิกา
    input rst,                  // reset รีเซ็ตระบบ
    input [7:0] flag,           // flag จาก ALU เช่น zero, carry ฯลฯ
    output reg write, read,     // ควบคุมการเขียน/อ่าน memory
    output reg [4:0] address,   // address สำหรับ memory/register
    output reg store, load,     
    output reg [2:0] control,   // control ส่งไป ALU
    output reg ldi,             // load immediate
    output reg [7:0] databus    // bus สำหรับส่งข้อมูล
);
    // memory เก็บโปรแกรม (32 คำสั่ง แต่ละคำสั่ง 19 bit)
    reg [18:0] program [31:0];
    // opcode = ประเภทคำสั่ง
    // state = สถานะของ FSM (Finite State Machine)
    reg [3:0] opcode, state;
    // operand ของคำสั่ง
    reg [4:0] op1, op2, op3;
    // program counter (counter)
    reg [4:0] counter;
    // instruction ปัจจุบัน
    reg [18:0] ins;
    // โหลด machine code จากไฟล์
    initial $readmemb("machinecode.txt", program);
    // ทำงานทุกขอบขาขึ้นของ clock หรือ reset
    always @(posedge clk or posedge rst) begin

        // ================= RESET =================
        if (rst) begin
            state <= 0;
            counter <= 0;
            write <= 0;
            read <= 0;
            load <= 0;
            store <= 0;
            ldi <= 0;

            ins <= 0;
            opcode <= 0;
            op1 <= 0;
            op2 <= 0;
            op3 <= 0;

        end else begin
            case(state)
                // ================= FETCH =================
                4'd0: begin
                    // ดึงคำสั่งจาก memory
                    ins = program[counter];
                    // แยก instruction
                    opcode = ins[18:15];  // ประเภทคำสั่ง
                    op1 = ins[14:10];     // operand 1
                    op2 = ins[9:5];       // operand 2
                    op3 = ins[4:0];       // operand 3
                    // reset control signal
                    write <= 0;
                    read <= 0;
                    ldi <= 0;
                    store <= 0;
                    load <= 0;
                    // ถ้าไม่ใช่ nop (opcode = 0) ให้ไปคำสั่งถัดไป
                    if (opcode != 4'b0)
                        counter <= counter + 1;
                    // เลือก state ถัดไปตาม opcode
                    state <= (opcode == 4'd1) ? 1 :         // (ยังไม่ได้ implement)
                             (opcode == 4'd4) ? 7 :         // LDI
                             (opcode[3] == 1) ? 9 :         // ALU
                             (opcode == 4'd5) ? 16 :        // jump
                             0;
                    // ===== JUMP =====
                    if (opcode == 4'd5) begin
                        // ถ้าเงื่อนไขตรง ให้กระโดดไป address ใหม่
                        if (op1 == 0 || (op1 == 5'd4 && flag[4]))
                            counter <= op2;
                        state <= 0;
                    end
                end
                // ================= LDI (Load Immediate) =================
                4'd7: begin
                    databus <= ins[7:0]; // เอาค่าทันทีใส่ bus
                    ldi <= 1;            // signal โหลดค่า
                    state <= 8;
                end
                4'd8: begin
                    address <= op1;      // เขียนไป register ที่ op1
                    write <= 1;
                    state <= 0;
                end
                // ================= ALU PROCESS =================
                4'd9: begin
                    address <= op2;      // อ่าน operand 1
                    read <= 1;
                    state <= 10;
                end
                4'd10: begin
                    address <= 5'd0;     // เก็บไว้ temp register 0
                    write <= 1;
                    read <= 0;
                    state <= 11;
                end

                4'd11: begin
                    address <= op3;      // อ่าน operand 2
                    read <= 1;
                    write <= 0;
                    state <= 12;
                end
                4'd12: begin
                    address <= 5'd1;     // เก็บ temp register 1
                    write <= 1;
                    read <= 0;
                    state <= 13;
                end

                4'd13: begin
                    control <= opcode[2:0]; // ส่งคำสั่งไป ALU
                    write <= 0;
                    state <= 14;
                end

                4'd14: begin
                    address <= 5'd2;     // อ่านผลลัพธ์จาก ALU
                    read <= 1;
                    state <= 15;
                end

                4'd15: begin
                    address <= op1;      // เขียนผลกลับไป register ปลายทาง
                    write <= 1;
                    read <= 0;
                    state <= 0;
                end
                // default กลับไป fetch ใหม่
                default: state <= 0;
            endcase
        end
    end
endmodule

module EU(input clk, rst, read, write, store, load, ldi, input [4:0] address, 
          input [2:0] control, input [7:0] datain, output [7:0] flag, output reg [7:0] dataout);
    reg [7:0] registers [15:0];
    reg [7:0] internalbus;
    wire [7:0] alu_out;
    integer k; 

    always @(*) if (read && !store) internalbus = registers[address];
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for(k=0; k<16; k=k+1) registers[k] <= 0;
        end else if (write) begin
            if (load || ldi) registers[address] <= datain;
            else registers[address] <= internalbus;
        end
        registers[2] <= alu_out;
    end
    ALU alu_inst(control, registers[0], registers[1], flag, alu_out);
endmodule

module ALU(input [2:0] ctrl, input [7:0] A, B, output reg [7:0] flag, output reg [7:0] C);
    always @(*) begin
        case(ctrl)
            3'd0: {flag[0], C} = A + B;
            3'd1: {flag[1], C} = A - B;
            3'd6: begin flag[4] = (A >= B); C = 0; end 
            3'd7: C = A * B; 
            default: C = 0;
        endcase
        flag[3] = (C == 0);
    end
endmodule
