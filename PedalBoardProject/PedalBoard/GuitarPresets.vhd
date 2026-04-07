LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY GuitarPresets IS
	GENERIC (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line
		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH : INTEGER := 32;
		C_S00_AXI_ADDR_WIDTH : INTEGER := 4;

		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S00_AXIS_TDATA_WIDTH : INTEGER := 32
	);
	PORT (
		-- Users to add ports here
		i2s_dataOut : OUT STD_LOGIC;
		i2s_sclk : OUT STD_LOGIC;
		i2s_lrclkRec : OUT STD_LOGIC;
		i2s_lrclkPbac : OUT STD_LOGIC;
		i2s_mclk : IN STD_LOGIC;
		i2s_reset_n : IN STD_LOGIC;
		i2s_dataIn : in std_logic;
		i2s_mute : out std_logic;
		-- User ports ends
		-- Do not modify the ports beyond this line
		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_clk : IN STD_LOGIC;
		s00_axi_reset_n : IN STD_LOGIC;
		s00_axi_awaddr : IN STD_LOGIC_VECTOR(C_S00_AXI_ADDR_WIDTH - 1 DOWNTO 0);
		s00_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
		s00_axi_awvalid : IN STD_LOGIC;
		s00_axi_awready : OUT STD_LOGIC;
		s00_axi_wdata : IN STD_LOGIC_VECTOR(C_S00_AXI_DATA_WIDTH - 1 DOWNTO 0);
		s00_axi_wstrb : IN STD_LOGIC_VECTOR((C_S00_AXI_DATA_WIDTH/8) - 1 DOWNTO 0);
		s00_axi_wvalid : IN STD_LOGIC;
		s00_axi_wready : OUT STD_LOGIC;
		s00_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		s00_axi_bvalid : OUT STD_LOGIC;
		s00_axi_bready : IN STD_LOGIC;
		s00_axi_araddr : IN STD_LOGIC_VECTOR(C_S00_AXI_ADDR_WIDTH - 1 DOWNTO 0);
		s00_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
		s00_axi_arvalid : IN STD_LOGIC;
		s00_axi_arready : OUT STD_LOGIC;
		s00_axi_rdata : OUT STD_LOGIC_VECTOR(C_S00_AXI_DATA_WIDTH - 1 DOWNTO 0);
		s00_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		s00_axi_rvalid : OUT STD_LOGIC;
		s00_axi_rready : IN STD_LOGIC
	);
END GuitarPresets;

ARCHITECTURE arch_imp OF GuitarPresets IS
	TYPE LrData_t IS ARRAY(0 TO 1) OF STD_LOGIC_VECTOR(23 DOWNTO 0);
	TYPE TxFifo_t IS ARRAY(0 TO 1) OF LrData_t;

	SIGNAL s00_axis_data : LrData_t;
	SIGNAL s00_axis_fifo_full : STD_LOGIC;
	SIGNAL s00_axis_release_fifo : STD_LOGIC;
	SIGNAL s00_axi_slave_reg0 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s00_axi_slave_reg1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s00_axi_slave_reg2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL axi_enableReg0Sync1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL axi_enableReg0Sync2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL axi_enableReg1Sync1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL axi_enableReg1Sync2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL axi_enableReg2Sync1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL axi_enableReg2Sync2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL axi_enableReg : STD_LOGIC;
	SIGNAL axi_distortionShift : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL axi_CompressorThreshold : STD_LOGIC_VECTOR(23 DOWNTO 0);

	SIGNAL axi_gainReg : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL axi_thresholdHigh : STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL axi_thresholdLow : STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL axi_OverdriveReg : STD_LOGIC_VECTOR(7 DOWNTO 0);

	SIGNAL sclk_i2sTxreg : STD_LOGIC;
	SIGNAL lrclk_i2sTxReg : STD_LOGIC;
	-- component declaration
	COMPONENT GuitarPresets_slave_lite_v1_0_S00_AXI IS
		GENERIC (
			C_S_AXI_DATA_WIDTH : INTEGER := 32;
			C_S_AXI_ADDR_WIDTH : INTEGER := 4
		);
		PORT (
			slv_reg0_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			slv_reg1_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			slv_reg2_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			S_AXI_ACLK : IN STD_LOGIC;
			S_AXI_ARESETN : IN STD_LOGIC;
			S_AXI_AWADDR : IN STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH - 1 DOWNTO 0);
			S_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			S_AXI_AWVALID : IN STD_LOGIC;
			S_AXI_AWREADY : OUT STD_LOGIC;
			S_AXI_WDATA : IN STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH - 1 DOWNTO 0);
			S_AXI_WSTRB : IN STD_LOGIC_VECTOR((C_S_AXI_DATA_WIDTH/8) - 1 DOWNTO 0);
			S_AXI_WVALID : IN STD_LOGIC;
			S_AXI_WREADY : OUT STD_LOGIC;
			S_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			S_AXI_BVALID : OUT STD_LOGIC;
			S_AXI_BREADY : IN STD_LOGIC;
			S_AXI_ARADDR : IN STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH - 1 DOWNTO 0);
			S_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			S_AXI_ARVALID : IN STD_LOGIC;
			S_AXI_ARREADY : OUT STD_LOGIC;
			S_AXI_RDATA : OUT STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH - 1 DOWNTO 0);
			S_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			S_AXI_RVALID : OUT STD_LOGIC;
			S_AXI_RREADY : IN STD_LOGIC
		);
	END COMPONENT GuitarPresets_slave_lite_v1_0_S00_AXI;

	COMPONENT I2sRx IS
		GENERIC (
			C_S_AXIS_TDATA_WIDTH : INTEGER := 32
		);
		PORT (
			-- AXI4Stream sink: Clock
			mclk_in : IN STD_LOGIC;

			sclk : IN STD_LOGIC;
			lrclk : IN STD_LOGIC;

			I2sData_In : IN STD_LOGIC;
			-- AXI4Stream sink: Reset
			I2sRx_Reset_n : IN STD_LOGIC;

			fifo_full : OUT STD_LOGIC;

			release_fifo : IN STD_LOGIC;
			stream_data_left : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
			stream_data_right : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
		);
	END COMPONENT I2sRx;
	COMPONENT I2sTx IS
  PORT (
    sclk_out : INOUT STD_LOGIC;
    lrclk_out : INOUT STD_LOGIC;
    mclk : IN STD_LOGIC;
    reset_n : IN STD_LOGIC;
    sdata_out : OUT STD_LOGIC;
    mute : OUT STD_LOGIC;
    axis_stream_data_left : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axis_stream_data_right : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axis_fifo_full : IN STD_LOGIC;
    axis_release_fifo : OUT STD_LOGIC;
    axi_enableIpReg : IN STD_LOGIC;
    axi_gain : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    axi_threshold_high : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axi_threshold_low : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axi_overdrive : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    axi_distShift : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		axi_compThresh : IN STD_LOGIC_VECTOR(23 DOWNTO 0)
		);
	END COMPONENT I2sTx;
BEGIN

	-- Instantiation of Axi Bus Interface S00_AXI
	GuitarPresets_slave_lite_v1_0_S00_AXI_inst : GuitarPresets_slave_lite_v1_0_S00_AXI
	GENERIC MAP(
		C_S_AXI_DATA_WIDTH => C_S00_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
	)
	PORT MAP(
		slv_reg0_out => s00_axi_slave_reg0,
		slv_reg1_out => s00_axi_slave_reg1,
		slv_reg2_out => s00_axi_slave_reg2,
		S_AXI_ACLK => s00_axi_clk,
		S_AXI_ARESETN => s00_axi_reset_n,
		S_AXI_AWADDR => s00_axi_awaddr,
		S_AXI_AWPROT => s00_axi_awprot,
		S_AXI_AWVALID => s00_axi_awvalid,
		S_AXI_AWREADY => s00_axi_awready,
		S_AXI_WDATA => s00_axi_wdata,
		S_AXI_WSTRB => s00_axi_wstrb,
		S_AXI_WVALID => s00_axi_wvalid,
		S_AXI_WREADY => s00_axi_wready,
		S_AXI_BRESP => s00_axi_bresp,
		S_AXI_BVALID => s00_axi_bvalid,
		S_AXI_BREADY => s00_axi_bready,
		S_AXI_ARADDR => s00_axi_araddr,
		S_AXI_ARPROT => s00_axi_arprot,
		S_AXI_ARVALID => s00_axi_arvalid,
		S_AXI_ARREADY => s00_axi_arready,
		S_AXI_RDATA => s00_axi_rdata,
		S_AXI_RRESP => s00_axi_rresp,
		S_AXI_RVALID => s00_axi_rvalid,
		S_AXI_RREADY => s00_axi_rready
	);

	-- Instantiation of Axi Bus Interface S00_AXIS
	I2sRx_inst : I2sRx
	GENERIC MAP(
		C_S_AXIS_TDATA_WIDTH => C_S00_AXIS_TDATA_WIDTH
	)
	PORT MAP(
		mclk_in => i2s_mclk,
		sclk => sclk_i2sTxreg,
		lrclk => lrclk_i2sTxReg,
		I2sData_In => i2s_dataIn,
		I2sRx_Reset_n => i2s_reset_n,
		fifo_full => s00_axis_fifo_full,
		release_fifo => s00_axis_release_fifo,
		stream_data_left => s00_axis_data(1),
		stream_data_right => s00_axis_data(0)
	);

	-- Add user logic here
	I2sTxInst : I2sTx
	PORT MAP(
		sclk_out => sclk_i2sTxreg,
		lrclk_out => lrclk_i2sTxReg,
		mclk => i2s_mclk,
		reset_n => i2s_reset_n,
		sdata_out => i2s_dataOut,
		mute => i2s_mute,
		axis_stream_data_left => s00_axis_data(1),
		axis_stream_data_right => s00_axis_data(0),
		axis_fifo_full => s00_axis_fifo_full,
		axis_release_fifo => s00_axis_release_fifo,
		axi_enableIpReg => axi_enableReg,
		axi_gain => axi_gainReg,
		axi_threshold_high => axi_thresholdHigh,
		axi_threshold_low => axi_thresholdLow,
		axi_overdrive => axi_OverdriveReg,
		axi_distShift => axi_distortionShift,
		axi_compThresh => axi_CompressorThreshold
	);

	PROCESS (i2s_mclk) IS
	BEGIN
		IF (rising_edge(i2s_mclk)) THEN
			IF i2s_reset_n = '0' THEN
				axi_enableReg0Sync1 <= (OTHERS => '0');
				axi_enableReg0Sync2 <= (OTHERS => '0');
				axi_enableReg1Sync1 <= (OTHERS => '0');
				axi_enableReg1Sync2 <= (OTHERS => '0');
				axi_enableReg2Sync1 <= (OTHERS => '0');
				axi_enableReg2Sync2 <= (OTHERS => '0');
				axi_gainReg <= (OTHERS => '0');
				axi_thresholdHigh <= (OTHERS => '0');
				axi_thresholdLow <= (OTHERS => '0');
				axi_enableReg <= '0';
				axi_OverdriveReg <= (OTHERS => '0');
				axi_distortionShift <= (OTHERS => '0');
				axi_CompressorThreshold <= (OTHERS => '0');
			ELSE
				axi_enableReg0Sync1 <= s00_axi_slave_reg0;
				axi_enableReg0Sync2 <= axi_enableReg0Sync1;
				axi_enableReg <= axi_enableReg0Sync2(0);
				axi_gainReg <= axi_enableReg0Sync2(7 DOWNTO 1);
				axi_thresholdHigh <= axi_enableReg0Sync2(31 downto 8);

				axi_enableReg1Sync1 <= s00_axi_slave_reg1;
				axi_enableReg1Sync2 <= axi_enableReg1Sync1;
				axi_thresholdLow <= axi_enableReg1Sync2(23 downto 0);
				axi_OverdriveReg <= axi_enableReg1Sync2(31 downto 24);

				axi_enableReg2Sync1 <= s00_axi_slave_reg2;
				axi_enableReg2Sync2 <= axi_enableReg1Sync1;
				axi_distortionShift <= axi_enableReg2Sync2(6 downto 0);
				axi_CompressorThreshold <= axi_enableReg2Sync2(30 downto 7);
			END IF;
		END IF;
	END PROCESS;

	i2s_sclk <= sclk_i2sTxreg;
	i2s_lrclkRec <= lrclk_i2sTxReg;
	i2s_lrclkPbac <= lrclk_i2sTxReg;
	-- User logic ends
	

END arch_imp;