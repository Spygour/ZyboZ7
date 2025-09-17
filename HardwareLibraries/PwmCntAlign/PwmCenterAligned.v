
`timescale 1 ns / 1 ps

module PwmCenterAligned #(
    // Users to add parameters here

    // User parameters ends
    // Do not modify the parameters beyond this line


    // Parameters of Axi Slave Bus Interface S00_AXI
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 5,

    // Parameters of Axi Slave Bus Interface S_AXI_INTR
    parameter integer C_S_AXI_INTR_DATA_WIDTH = 32,
    parameter integer C_S_AXI_INTR_ADDR_WIDTH = 5,
    parameter integer C_NUM_OF_INTR = 1,
    parameter C_INTR_SENSITIVITY = 32'hFFFFFFFF,
    parameter C_INTR_ACTIVE_STATE = 32'hFFFFFFFF,
    parameter integer C_IRQ_SENSITIVITY = 1,
    parameter integer C_IRQ_ACTIVE_STATE = 1
) (
    // Users to add ports here
    output reg [2:0] Pwm_OutPort,

    output reg [2:0] Pwm_OutPort_LSS,
    // User ports ends
    output reg Interrupt,
    // Do not modify the ports beyond this line


    // Ports of Axi Slave Bus Interface S00_AXI
    input wire s00_axi_aclk,
    input wire s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input wire [2 : 0] s00_axi_awprot,
    input wire s00_axi_awvalid,
    output wire s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire s00_axi_wvalid,
    output wire s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire s00_axi_bvalid,
    input wire s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input wire [2 : 0] s00_axi_arprot,
    input wire s00_axi_arvalid,
    output wire s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire s00_axi_rvalid,
    input wire s00_axi_rready
);
  // Instantiation of Axi Bus Interface S00_AXI
  wire [2:0] Pwm_Internal;
  wire [2:0] Pwm_Internal_LSS;
  wire        Interrupt_Reg;
  PwmCenterAligned_slave_lite_v1_0_S00_AXI #(
      .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
      .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
  ) PwmCenterAligned_slave_lite_v1_0_S00_AXI_inst (
      .S_AXI_ACLK(s00_axi_aclk),
      .S_AXI_ARESETN(s00_axi_aresetn),
      .S_AXI_AWADDR(s00_axi_awaddr),
      .S_AXI_AWPROT(s00_axi_awprot),
      .S_AXI_AWVALID(s00_axi_awvalid),
      .S_AXI_AWREADY(s00_axi_awready),
      .S_AXI_WDATA(s00_axi_wdata),
      .S_AXI_WSTRB(s00_axi_wstrb),
      .S_AXI_WVALID(s00_axi_wvalid),
      .S_AXI_WREADY(s00_axi_wready),
      .S_AXI_BRESP(s00_axi_bresp),
      .S_AXI_BVALID(s00_axi_bvalid),
      .S_AXI_BREADY(s00_axi_bready),
      .S_AXI_ARADDR(s00_axi_araddr),
      .S_AXI_ARPROT(s00_axi_arprot),
      .S_AXI_ARVALID(s00_axi_arvalid),
      .S_AXI_ARREADY(s00_axi_arready),
      .S_AXI_RDATA(s00_axi_rdata),
      .S_AXI_RRESP(s00_axi_rresp),
      .S_AXI_RVALID(s00_axi_rvalid),
      .S_AXI_RREADY(s00_axi_rready),
      .Pwm_Out(Pwm_Internal),
      .Pwm_Out_LSS(Pwm_Internal_LSS),
      .irq(Interrupt_Reg)
  );

  // Add user logic here
  always @(posedge s00_axi_aclk) begin
    if (!s00_axi_aresetn) begin
      Pwm_OutPort <= 3'b000;
      Pwm_OutPort_LSS <= 3'b000;
      Interrupt <= 1'b0;
    end else begin
      Pwm_OutPort <= Pwm_Internal;
      Pwm_OutPort_LSS <= Pwm_Internal_LSS;
      Interrupt <= Interrupt_Reg;
    end
  end
  // User logic ends
endmodule
