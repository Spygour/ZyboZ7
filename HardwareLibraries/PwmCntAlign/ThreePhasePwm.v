module ThreePhasePwm (
    input  wire        Clk,
    input  wire        Reset_n,
    input  wire [31:0] Period,
    input  wire [31:0] Duty_0, Duty_1, Duty_2,
    input  wire        Enable,
    input  wire        CenterAlligned,
    output reg  [2:0]  PWM
);

    reg [31:0] count;
    reg [31:0] CM0_0, CM0_1, CM0_2;
    reg [31:0] CM1_0, CM1_1, CM1_2;
    wire [31:0] Duty_0_internal, Duty_1_internal, Duty_2_internal;
    wire [31:0] SR0_0, SR0_1, SR0_2;
    wire [31:0] SR1_0, SR1_1, SR1_2;

    assign Duty_0_internal  = (Duty_0 < Period) ? Duty_0 : Period;
    assign Duty_1_internal  = (Duty_1 < Period) ? Duty_1 : Period;
    assign Duty_2_internal  = (Duty_2 < Period) ? Duty_2 : Period;

    assign SR0_0 = (CenterAlligned == 1'b0) ? ((Period >> 1'b1) - (Duty_0_internal >> 1'b1)) : 1'b0;
    assign SR0_1 = (CenterAlligned == 1'b0) ? ((Period >> 1'b1) - (Duty_1_internal >> 1'b1)) : 1'b0;
    assign SR0_2 = (CenterAlligned == 1'b0) ? ((Period >> 1'b1) - (Duty_2_internal >> 1'b1)) : 1'b0;

    assign SR1_0 = (CenterAlligned == 1'b0) ? ((Period >> 1'b1) + (Duty_0_internal >> 1'b1)) : Duty_0_internal;
    assign SR1_1 = (CenterAlligned == 1'b0) ? ((Period >> 1'b1) + (Duty_1_internal >> 1'b1)) : Duty_1_internal;
    assign SR1_2 = (CenterAlligned == 1'b0) ? ((Period >> 1'b1) + (Duty_2_internal >> 1'b1)) : Duty_2_internal;

    always @(posedge Clk) begin
        if (!Reset_n) begin
            count  <= 32'd0;
            CM0_0  <= 32'd0;
            CM0_1  <= 32'd0;
            CM0_2  <= 32'd0;
            CM1_0  <= 32'd0;
            CM1_1  <= 32'd0;
            CM1_2  <= 32'd0;
        end else if (count >= Period) begin
            count  <= 32'b0;
            CM0_0  <= SR0_0; 
            CM0_1  <= SR0_1; 
            CM0_2  <= SR0_2;
            CM1_0  <= SR1_0; 
            CM1_1  <= SR1_1; 
            CM1_2  <= SR1_2;
        end else begin
            count <= count + 1'b1;
        end
    end

    always @(posedge Clk) begin
        if (!Reset_n) begin
            PWM <= 3'b000;
        end else begin
            if (Enable) begin
                PWM[0] <= (count >= CM0_0 && count < CM1_0);
                PWM[1] <= (count >= CM0_1 && count < CM1_1);
                PWM[2] <= (count >= CM0_2 && count < CM1_2);
            end else begin
                PWM <= 3'b000;
            end
        end
    end

endmodule
