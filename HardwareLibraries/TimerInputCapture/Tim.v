module Tim (
    input  wire        Clk,
    input  wire        Reset_n,
    input  wire        Input,
    input  wire [2:0]  Mode,
    input  wire [31:0] Prescaler,
    input  wire        Enable,
    input  wire        Interrupt_Enable,
    output reg         Interrupt_Active,
    output reg [31:0]  Result1,
    output reg [31:0]  Result2,
    output reg         EdgeType,
    output wire        OverflowWarn
);

  localparam START_COUNT = 4'h0;
  localparam END_COUNTER = 4'h1;

  reg [3:0] edge_counterState = END_COUNTER;
  reg [3:0] fall_counterState = END_COUNTER;
  /* Interrupt internal */
  wire Interrupt_Wire;

  /* Input capture previous and current */
  reg Input_current;
  reg Input_prev;

  /* Mode results */
  wire RisingEdge_Res;
  wire FallingEgde_Res;
  wire BothEdges_Res;

  /* Internal Mode */
  wire [2:0] Mode_Internal;
  reg [63:0] count;

  reg [31:0] Prescaler_Cnt;

  /* Control Registers */
  assign Mode_Internal = Mode;
  assign Interrupt_Wire = (Interrupt_Enable) ? 1'b1 : 1'b0;

  assign RisingEdge_Res = ( (Input_current == 1'b1) && (Input_prev == 1'b0) );
  assign FallingEgde_Res = ((Input_current == 1'b0) && (Input_prev == 1'b1) );

  assign BothEdges_Res = ((Input_current) != (Input_prev));

  assign OverflowWarn = &count;

  /* Edge tracking */
  always @(posedge Clk) begin
    Input_prev <= Input_current;
    Input_current <= Input;
  end

  always @(posedge Clk) begin
    if (!Reset_n) begin
      count <= 64'd0;
      Result1 <= 32'd0;
      Result2 <= 32'd0;
      Prescaler_Cnt <= 32'd0;
      edge_counterState <= END_COUNTER;
      fall_counterState <= END_COUNTER;
    end else if (Enable) begin
      case (Mode_Internal)
        3'b001 : /* Rising edge */
          if (RisingEdge_Res) begin
            Result1 <= count[31:0];
            Result2 <= count[63:32];
            count <= 64'd0;
            Prescaler_Cnt <= 32'd0;
            Interrupt_Active <= Interrupt_Wire;
          end else begin
            Interrupt_Active <= 1'b0;
            if (Prescaler_Cnt == Prescaler) begin
              count <= count + 1'b1;
              Prescaler_Cnt <= 32'd0;
            end else begin
              Prescaler_Cnt <= Prescaler_Cnt + 1'b1;
            end
          end
          
        3'b010: /* Falling Edge */
          if (FallingEgde_Res) begin
            Result1 <= count[31:0];
            Result2 <= count[63:32];
            count <= 64'd0;
            Interrupt_Active <= Interrupt_Wire;
          end else begin
            Interrupt_Active <= 1'b0;
            if (Prescaler_Cnt == Prescaler) begin
              count <= count + 1'b1;
              Prescaler_Cnt <= 32'd0;
            end else begin
              Prescaler_Cnt <= Prescaler_Cnt + 1'b1;
            end
          end
        3'b011: /* Both edges */
          if (BothEdges_Res) begin
            Result1 <= count[31:0];
            Result2 <= count[63:32];
            count <= 64'd0;
            Interrupt_Active <= Interrupt_Wire;
          end else begin
            Interrupt_Active <= 1'b0;
            if (Prescaler_Cnt == Prescaler) begin
              count <= count + 1'b1;
              Prescaler_Cnt <= 32'd0;
            end else begin
              Prescaler_Cnt <= Prescaler_Cnt + 1'b1;
            end
          end

        3'b100:  begin/* High edge measure */
          case (edge_counterState)
            END_COUNTER: begin
              Interrupt_Active <= 1'b0;
              if (RisingEdge_Res) begin
                count <= 64'd0;
                edge_counterState <=  START_COUNT;
              end
            end
            
            START_COUNT: begin
              if (FallingEgde_Res) begin
                Result1 <= count[31:0];
                Result2 <= count[63:32];
                Interrupt_Active <= Interrupt_Wire;
                edge_counterState <= END_COUNTER;
              end else begin
                if (Prescaler_Cnt == Prescaler) begin
                  count <= count + 1'b1;
                  Prescaler_Cnt <= 32'd0;
                end else begin
                  Prescaler_Cnt <= Prescaler_Cnt + 1'b1;
                end
              end
            end
          endcase
        end

        3'b101: begin /* Low edge measure */
          case (fall_counterState)
            END_COUNTER: begin
              Interrupt_Active <= 1'b0;
              if (FallingEgde_Res) begin
                count <= 64'd0;
                fall_counterState <=  START_COUNT;
              end
            end
            
            START_COUNT: begin
              if (RisingEdge_Res) begin
                Result1 <= count[31:0];
                Result2 <= count[63:32];
                Interrupt_Active <= Interrupt_Wire;
                fall_counterState <= END_COUNTER;
              end else begin
                if (Prescaler_Cnt == Prescaler) begin
                  count <= count + 1'b1;
                  Prescaler_Cnt <= 32'd0;
                end else begin
                  Prescaler_Cnt <= Prescaler_Cnt + 1'b1;
                end
              end
            end
          endcase
        end

        default:
          count <= 64'd0;
      endcase
    end
  end

  /* Extra information about the current edge we are */
  always @(posedge Clk) begin
    if (!Reset_n) begin
      EdgeType <= Input;
    end else begin
      if (RisingEdge_Res) begin
        EdgeType <= 1'b1;
      end else if (FallingEgde_Res) begin
        EdgeType <= 1'b0;
      end
    end
  end

endmodule
