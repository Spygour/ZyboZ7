----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/22/2026 01:16:00 AM
-- Design Name: 
-- Module Name: I2s_Tx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.I2sTypes.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY I2sTx IS
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
    axi_gain : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    axi_normalizer : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    axi_threshold_high : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axi_threshold_low : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axi_distShift : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    axi_compThresh : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axi_highPassShift : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_lowPassShift : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_phaseCtrl : IN STD_LOGIC_VECTOR(8 DOWNTO 0)
  );
END I2sTx;

ARCHITECTURE Behavioral OF I2sTx IS
  SIGNAL configReg : STD_LOGIC;
  SIGNAL sclk_prev : STD_LOGIC;
  SIGNAL sclk_curr : STD_LOGIC;
  SIGNAL lrclk_prev : STD_LOGIC;
  SIGNAL lrclk_cur : STD_LOGIC;

  SIGNAL i2sRx_dataLoc : TxFifo_t := (OTHERS => (OTHERS => (OTHERS => '0')));
  SIGNAL i2sRx_dataLocReadIdx : unsigned(0 DOWNTO 0);
  SIGNAL i2sRx_dataLocWriteIdx : unsigned(0 DOWNTO 0);

  -- FIR FILTER
  SIGNAL left_channel_mem : TxMemory_t := (OTHERS => (OTHERS => '0'));
  SIGNAL right_channel_mem : TxMemory_t := (OTHERS => (OTHERS => '0'));
  SIGNAL memory_index : INTEGER;

  SIGNAL axis_control_state : unsigned(3 DOWNTO 0);

  SIGNAL i2sTx_Enable : STD_LOGIC;
  SIGNAL i2sTx_State : unsigned(3 DOWNTO 0);

  SIGNAL dataIdx : INTEGER;

  SIGNAL sclk_reg : STD_LOGIC;
  SIGNAL lrclk_reg : STD_LOGIC;
  SIGNAL sclk_cnt : INTEGER := 0;
  SIGNAL lrclk_cnt : INTEGER := 0;

  SIGNAL gain : unsigned(5 DOWNTO 0);
  SIGNAL threshold_high : signed(23 DOWNTO 0);
  SIGNAL threshold_low : signed(23 DOWNTO 0);
  SIGNAL normalizer : unsigned(4 DOWNTO 0);
  SIGNAL distortion_shift : unsigned(6 DOWNTO 0);
  SIGNAL compressor_thresh : signed(23 DOWNTO 0);
  SIGNAL lowPassShift : unsigned(3 DOWNTO 0);
  SIGNAL highPassShift : unsigned(3 DOWNTO 0);
  SIGNAL phaseCtrl : unsigned(8 DOWNTO 0);

  -- HIGH PASS FILTER
  SIGNAL hp_input_lprev : signed(23 DOWNTO 0);
  SIGNAL hp_input_rprev : signed(23 DOWNTO 0);
  SIGNAL hp_output_lprev : signed(23 DOWNTO 0);
  SIGNAL hp_output_rprev : signed(23 DOWNTO 0);
  -- LOW PASS FILTER
  SIGNAL lp_output_lprev : signed(23 DOWNTO 0);
  SIGNAL lp_output_rprev : signed(23 DOWNTO 0);

  -- PHASE FILTER = ALL PASS FILTER
  SIGNAL ap_output_lprev : signed(23 DOWNTO 0);
  SIGNAL ap_output_rprev : signed(23 DOWNTO 0);
  SIGNAL ap_input_lprev : signed(23 DOWNTO 0);
  SIGNAL ap_input_rprev : signed(23 DOWNTO 0);

BEGIN
  threshold_high <= signed(axi_threshold_high);
  threshold_low <= signed(axi_threshold_low);
  gain <= unsigned(axi_gain);
  configReg <= axi_enableIpReg;
  distortion_shift <= unsigned(axi_distShift);
  compressor_thresh <= signed(axi_compThresh);
  highPassShift <= unsigned(axi_highPassShift);
  lowPassShift <= unsigned(axi_lowPassShift);
  normalizer <= unsigned(axi_normalizer);
  phaseCtrl <= unsigned(axi_phaseCtrl);
  -- Add user logic here
  PROCESS (mclk)
  BEGIN
    IF rising_edge(mclk) THEN
      IF (reset_n = '0') THEN
        sclk_out <= '0';
        lrclk_out <= '1';
        sclk_cnt <= 0;
        lrclk_cnt <= 0;
      ELSE
        IF (sclk_cnt = 1) THEN
          sclk_cnt <= 0;
          -- take the data on rising edge since we set the sclk to be high when its 0
          -- Increment LRCLK only on SCLK rising edge
          IF (sclk_out = '1') THEN -- about to go 1 -> 0
            IF (lrclk_cnt = 31) THEN
              lrclk_cnt <= 0;
              lrclk_out <= NOT lrclk_out;
            ELSE
              lrclk_cnt <= lrclk_cnt + 1;
            END IF;
          END IF;
          sclk_out <= NOT sclk_out;
        ELSE
          sclk_cnt <= sclk_cnt + 1;
        END IF;
      END IF;
    END IF;
  END PROCESS;
  -- Clocks control process 
  PROCESS (mclk) IS
  BEGIN
    IF (rising_edge(mclk)) THEN
      IF (reset_n = '0') THEN
        sclk_prev <= '0';
        sclk_curr <= '0';
        lrclk_prev <= '0';
        lrclk_cur <= '0';
      ELSE
        sclk_prev <= sclk_curr;
        sclk_curr <= sclk_out;

        lrclk_prev <= lrclk_cur;
        lrclk_cur <= lrclk_out;
      END IF;
    END IF;
  END PROCESS;

  -- AXI CONTROL PROCESS
  PROCESS (mclk) IS
    VARIABLE i2sRxData_Left : signed(23 DOWNTO 0);
    VARIABLE i2sRxData_Right : signed(23 DOWNTO 0);

    VARIABLE distortionData_Left : signed(23 DOWNTO 0);
    VARIABLE distortionData_Right : signed(23 DOWNTO 0);

    VARIABLE PhaseCnt : unsigned(16 DOWNTO 0);
    VARIABLE PhaseShift : unsigned(3 DOWNTO 0);
    VARIABLE PhaseDirection : STD_LOGIC;
    VARIABLE mix_input : STD_LOGIC;
  BEGIN
    IF (rising_edge(mclk)) THEN
      IF (reset_n = '0') THEN
        i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
        i2sRx_dataLocReadIdx <= "0";
        i2sTx_Enable <= '0';
        -- keep the fifo always clear
        axis_release_fifo <= '1';
        i2sRxData_Left := (OTHERS => '0');
        i2sRxData_Right := (OTHERS => '0');
        left_channel_mem <= (OTHERS => (OTHERS => '0'));
        right_channel_mem <= (OTHERS => (OTHERS => '0'));
        hp_input_lprev <= (OTHERS => '0');
        hp_input_rprev <= (OTHERS => '0');
        hp_output_lprev <= (OTHERS => '0');
        hp_output_rprev <= (OTHERS => '0');
        ap_input_lprev <= (OTHERS => '0');
        ap_input_rprev <= (OTHERS => '0');
        ap_output_lprev <= (OTHERS => '0');
        ap_output_rprev <= (OTHERS => '0');
        distortionData_Left := (OTHERS => '0');
        distortionData_Right := (OTHERS => '0');
        lp_output_lprev <= (OTHERS => '0');
        lp_output_rprev <= (OTHERS => '0');
        PhaseCnt := (OTHERS => '0');
        PhaseShift := to_unsigned(6, 4);
        PhaseDirection := '0';
        mix_input := '0';
        axis_control_state <= IDLE_AXIS;
      ELSE
        CASE(axis_control_state) IS
          WHEN IDLE_AXIS =>
          IF (configReg = '1') THEN
            -- Stop the clearance of fifo , ready t get first data
            axis_release_fifo <= '0';
            mix_input := '1';
            axis_control_state <= WAIT_AXIS_FIFO_FULL_START;
          END IF;

          WHEN WAIT_AXIS_FIFO_FULL_START =>
          IF (axis_fifo_full = '1') THEN
            i2sRxData_Left := fir_filter(signed(axis_stream_data_left), left_channel_mem, FIR_COEFF, MEMORY_NUM);
            i2sRxData_Right := fir_filter(signed(axis_stream_data_right), right_channel_mem, FIR_COEFF, MEMORY_NUM);
            -- update the memory
            FOR memory_index IN 0 TO (MEMORY_NUM - 2) LOOP
              left_channel_mem(memory_index) <= left_channel_mem(memory_index + 1);
              right_channel_mem(memory_index) <= right_channel_mem(memory_index + 1);
            END LOOP;
            left_channel_mem(MEMORY_NUM - 1) <= signed(axis_stream_data_left);
            right_channel_mem(MEMORY_NUM - 1) <= signed(axis_stream_data_right);
            -- release the fifo
            axis_release_fifo <= '1';
            axis_control_state <= WAIT_FIFO_CLEAR;
          ELSIF (configReg = '0') THEN
            -- Stop the clearance of fifo , ready t get first data
            i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
            i2sRx_dataLocReadIdx <= "0";
            i2sTx_Enable <= '0';
            axis_release_fifo <= '1';
            axis_control_state <= IDLE_AXIS;
          END IF;

          WHEN WAIT_FIFO_CLEAR =>
          IF (axis_fifo_full = '0') THEN
            IF (gain(1 DOWNTO 0) = "01") THEN
              -- APPLY HP FILTER
              distortionData_Left := hp_filter(i2sRxData_Left, hp_input_lprev, hp_output_lprev, highPassShift);
              distortionData_Right := hp_filter(i2sRxData_Right, hp_input_rprev, hp_output_rprev, highPassShift);
              -- STORE PREVIOUS INPUT
              hp_input_lprev <= i2sRxData_Left;
              hp_input_rprev <= i2sRxData_Right;
              -- STORE PREVIOUS OUTPUT
              hp_output_lprev <= distortionData_Left;
              hp_output_rprev <= distortionData_Right;
              -- APPLY SOFT CLIP
              i2sRxData_Left := apply_soft_clip(distortionData_Left, unsigned(gain(5 DOWNTO 2)), normalizer, threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input);
              i2sRxData_Right := apply_soft_clip(distortionData_Right, unsigned(gain(5 DOWNTO 2)), normalizer, threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input);
            ELSIF ((gain(1 DOWNTO 0) = "10") OR (gain(1 DOWNTO 0) = "11")) THEN
              -- APPLY HP FILTER
              distortionData_Left := hp_filter(i2sRxData_Left, hp_input_lprev, hp_output_lprev, highPassShift);
              distortionData_Right := hp_filter(i2sRxData_Right, hp_input_rprev, hp_output_rprev, highPassShift);
              -- STORE PREVIOUS INPUT
              hp_input_lprev <= i2sRxData_Left;
              hp_input_rprev <= i2sRxData_Right;
              -- STORE PREVIOUS OUTPUT
              hp_output_lprev <= distortionData_Left;
              hp_output_rprev <= distortionData_Right;
              -- APPLY gain filter
              i2sRxData_Left := apply_gain_clip(distortionData_Left + lp_output_lprev, unsigned(gain(5 DOWNTO 2)), threshold_high, threshold_low, compressor_thresh);
              i2sRxData_Right := apply_gain_clip(distortionData_Right + lp_output_rprev, unsigned(gain(5 DOWNTO 2)), threshold_high, threshold_low, compressor_thresh);
              -- UPDATE THE FEEDBACK
              lp_output_lprev <= shift_right(distortionData_Left, 8);
              lp_output_rprev <= shift_right(distortionData_Right, 8);
            ELSE
              -- APPLY HP FILTER
              distortionData_Left := hp_filter(i2sRxData_Left, hp_input_lprev, hp_output_lprev, highPassShift);
              distortionData_Right := hp_filter(i2sRxData_Right, hp_input_rprev, hp_output_rprev, highPassShift);
              -- STORE PREVIOUS INPUT
              hp_input_lprev <= i2sRxData_Left;
              hp_input_rprev <= i2sRxData_Right;
              -- STORE PREVIOUS OUTPUT
              hp_output_lprev <= distortionData_Left;
              hp_output_rprev <= distortionData_Right;
              -- STORE BACK THE VALUES
              i2sRxData_Left := distortionData_Left;
              i2sRxData_Right := distortionData_Right;
            END IF;
            -- set the fifo read to be full
            axis_release_fifo <= '0';
            axis_control_state <= LOW_PASS_START;
          ELSIF (configReg = '0') THEN
            -- Stop the clearance of fifo , ready t get first data
            i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
            i2sRx_dataLocReadIdx <= "0";
            i2sTx_Enable <= '0';
            axis_release_fifo <= '1';
            axis_control_state <= IDLE_AXIS;
          END IF;

          WHEN LOW_PASS_START =>
          -- APPLY LP FILTER
          distortionData_Left := lp_filter(i2sRxData_Left, lp_output_lprev, lowPassShift);
          distortionData_Right := lp_filter(i2sRxData_Right, lp_output_rprev, lowPassShift);
          lp_output_lprev <= distortionData_Left;
          lp_output_rprev <= distortionData_Right;
          -- CHECK IF PHASE HERE
          IF (phaseCtrl(0) = '1') THEN
            update_phase(PhaseShift, phaseCtrl(2 DOWNTO 1), PhaseDirection, PhaseCnt,
            PHASE_MIN_MAX_LUT(to_integer(phaseCtrl(5 DOWNTO 3)))(1), PHASE_MIN_MAX_LUT(to_integer(phaseCtrl(5 DOWNTO 3)))(0),
            PHASE_TIME_ARRAY(to_integer(phaseCtrl(8 DOWNTO 6))) );
          ELSE
            PhaseDirection := '0';
            PhaseCnt := (OTHERS => '0');
            PhaseShift := to_unsigned(6, 4);
          END IF;
          axis_control_state <= PHASE_CYCLE_START;

          WHEN PHASE_CYCLE_START =>
          IF (phaseCtrl(0) = '1') THEN
            i2sRxData_Left := ap_filter(distortionData_Left, ap_input_lprev, ap_output_lprev, PHASE_COEFF_ARRAY(to_integer(PhaseShift)));
            i2sRxData_Right := ap_filter(distortionData_Right, ap_input_rprev, ap_output_rprev, PHASE_COEFF_ARRAY(to_integer(PhaseShift)));
            ap_input_lprev <= distortionData_Left;
            ap_input_rprev <= distortionData_Right;
            ap_output_lprev <= i2sRxData_Left;
            ap_output_rprev <= i2sRxData_Right;
          ELSE
            i2sRxData_Left := distortionData_Left;
            i2sRxData_Right := distortionData_Right;
          END IF;
          -- STORE THE DATA
          i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(0) <= STD_LOGIC_VECTOR(i2sRxData_Left);
          i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(1) <= STD_LOGIC_VECTOR(i2sRxData_Right);
          i2sRx_dataLocReadIdx <= i2sRx_dataLocReadIdx + 1;
          axis_control_state <= WAIT_AXIS_FIFO_FULL;

          WHEN WAIT_AXIS_FIFO_FULL =>
          IF (axis_fifo_full = '1') THEN
            i2sRxData_Left := fir_filter(signed(axis_stream_data_left), left_channel_mem, FIR_COEFF, MEMORY_NUM);
            i2sRxData_Right := fir_filter(signed(axis_stream_data_right), right_channel_mem, FIR_COEFF, MEMORY_NUM);
            -- update the memory
            FOR memory_index IN 0 TO (MEMORY_NUM - 2) LOOP
              left_channel_mem(memory_index) <= left_channel_mem(memory_index + 1);
              right_channel_mem(memory_index) <= right_channel_mem(memory_index + 1);
            END LOOP;
            -- add the input signal
            left_channel_mem(MEMORY_NUM - 1) <= signed(axis_stream_data_left);
            right_channel_mem(MEMORY_NUM - 1) <= signed(axis_stream_data_right);
            -- release the fifo
            axis_release_fifo <= '1';
            axis_control_state <= WAIT_STORE;
          ELSIF (configReg = '0') THEN
            -- Stop the clearance of fifo , ready t get first data
            i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
            i2sRx_dataLocReadIdx <= "0";
            i2sTx_Enable <= '0';
            axis_release_fifo <= '1';
            axis_control_state <= IDLE_AXIS;
          END IF;

          WHEN WAIT_STORE =>
          IF (axis_fifo_full = '0') THEN
            IF (gain(1 DOWNTO 0) = "01") THEN
              -- APPLY HP FILTER
              distortionData_Left := hp_filter(i2sRxData_Left, hp_input_lprev, hp_output_lprev, highPassShift);
              distortionData_Right := hp_filter(i2sRxData_Right, hp_input_rprev, hp_output_rprev, highPassShift);
              -- STORE PREVIOUS INPUT
              hp_input_lprev <= i2sRxData_Left;
              hp_input_rprev <= i2sRxData_Right;
              -- STORE PREVIOUS OUTPUT
              hp_output_lprev <= distortionData_Left;
              hp_output_rprev <= distortionData_Right;
              -- APPLY SOFT CLIP
              i2sRxData_Left := apply_soft_clip(distortionData_Left, unsigned(gain(5 DOWNTO 2)), normalizer, threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input);
              i2sRxData_Right := apply_soft_clip(distortionData_Right, unsigned(gain(5 DOWNTO 2)), normalizer, threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input);
            ELSIF ((gain(1 DOWNTO 0) = "10") OR (gain(1 DOWNTO 0) = "11")) THEN
              -- APPLY HP FILTER
              distortionData_Left := hp_filter(i2sRxData_Left, hp_input_lprev, hp_output_lprev, highPassShift);
              distortionData_Right := hp_filter(i2sRxData_Right, hp_input_rprev, hp_output_rprev, highPassShift);
              -- STORE PREVIOUS INPUT
              hp_input_lprev <= i2sRxData_Left;
              hp_input_rprev <= i2sRxData_Right;
              -- STORE PREVIOUS OUTPUT
              hp_output_lprev <= distortionData_Left;
              hp_output_rprev <= distortionData_Right;
              -- APPLY gain filter
              i2sRxData_Left := apply_gain_clip(distortionData_Left + lp_output_lprev, unsigned(gain(5 DOWNTO 2)), threshold_high, threshold_low, compressor_thresh);
              i2sRxData_Right := apply_gain_clip(distortionData_Right + lp_output_rprev, unsigned(gain(5 DOWNTO 2)), threshold_high, threshold_low, compressor_thresh);
              -- UPDATE THE FEEDBACK
              lp_output_lprev <= shift_right(distortionData_Left, 8);
              lp_output_rprev <= shift_right(distortionData_Right, 8);
            ELSE
              -- APPLY HP FILTER
              distortionData_Left := hp_filter(i2sRxData_Left, hp_input_lprev, hp_output_lprev, highPassShift);
              distortionData_Right := hp_filter(i2sRxData_Right, hp_input_rprev, hp_output_rprev, highPassShift);
              -- STORE PREVIOUS INPUT
              hp_input_lprev <= i2sRxData_Left;
              hp_input_rprev <= i2sRxData_Right;
              -- STORE PREVIOUS OUTPUT
              hp_output_lprev <= distortionData_Left;
              hp_output_rprev <= distortionData_Right;
              -- STORE BACK THE VALUES
              i2sRxData_Left := distortionData_Left;
              i2sRxData_Right := distortionData_Right;
            END IF;
            i2sTx_Enable <= '1';
            axis_release_fifo <= '0';
            axis_control_state <= LOW_PASS;
          ELSIF (configReg = '0') THEN
            -- Stop the clearance of fifo , ready t get first data
            i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
            i2sRx_dataLocReadIdx <= "0";
            i2sTx_Enable <= '0';
            axis_release_fifo <= '1';
            axis_control_state <= IDLE_AXIS;
          END IF;

          WHEN LOW_PASS =>
          -- APPLY LP FILTER
          distortionData_Left := lp_filter(i2sRxData_Left, lp_output_lprev, lowPassShift);
          distortionData_Right := lp_filter(i2sRxData_Right, lp_output_rprev, lowPassShift);
          lp_output_lprev <= distortionData_Left;
          lp_output_rprev <= distortionData_Right;
          -- CHECK IF PHASE HERE
          IF (phaseCtrl(0) = '1') THEN
            update_phase(PhaseShift, phaseCtrl(2 DOWNTO 1), PhaseDirection, PhaseCnt,
            PHASE_MIN_MAX_LUT(to_integer(phaseCtrl(5 DOWNTO 3)))(1), PHASE_MIN_MAX_LUT(to_integer(phaseCtrl(5 DOWNTO 3)))(0),
            PHASE_TIME_ARRAY(to_integer(phaseCtrl(8 DOWNTO 6))) );
          ELSE
            PhaseDirection := '0';
            PhaseCnt := (OTHERS => '0');
            PhaseShift := to_unsigned(6, 4);
          END IF;
          axis_control_state <= PHASE_CYCLE;

          WHEN PHASE_CYCLE =>
          IF (phaseCtrl(0) = '1') THEN
            i2sRxData_Left := ap_filter(distortionData_Left, ap_input_lprev, ap_output_lprev, PHASE_COEFF_ARRAY(to_integer(PhaseShift)));
            i2sRxData_Right := ap_filter(distortionData_Right, ap_input_rprev, ap_output_rprev, PHASE_COEFF_ARRAY(to_integer(PhaseShift)));
            ap_input_lprev <= distortionData_Left;
            ap_input_rprev <= distortionData_Right;
            ap_output_lprev <= i2sRxData_Left;
            ap_output_rprev <= i2sRxData_Right;
          ELSE
            i2sRxData_Left := distortionData_Left;
            i2sRxData_Right := distortionData_Right;
          END IF;
          -- STORE THE DATA
          i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(0) <= STD_LOGIC_VECTOR(i2sRxData_Left);
          i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(1) <= STD_LOGIC_VECTOR(i2sRxData_Right);
          axis_control_state <= WAIT_RESTART;

          WHEN WAIT_RESTART =>
          -- here we have reached the same data to be written
          IF (i2sRx_dataLocReadIdx = i2sRx_dataLocWriteIdx) THEN
            i2sRx_dataLocReadIdx <= i2sRx_dataLocReadIdx + 1;
            axis_control_state <= WAIT_AXIS_FIFO_FULL;
          ELSIF (configReg = '0') THEN
            -- Stop the clearance of fifo , ready t get first data
            i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
            i2sRx_dataLocReadIdx <= "0";
            i2sTx_Enable <= '0';
            axis_release_fifo <= '1';
            axis_control_state <= IDLE_AXIS;
          END IF;

          WHEN OTHERS => NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;

  -- DATA CONTROL PROCESS
  PROCESS (mclk) IS
    VARIABLE paddingIdx : INTEGER := 0;
    VARIABLE channelNum : unsigned(0 DOWNTO 0) := "0";
    VARIABLE dataTmp : LrData_t := (OTHERS => (OTHERS => '0'));
    VARIABLE changeCounter : unsigned(0 DOWNTO 0) := "0";

  BEGIN
    IF (rising_edge(mclk)) THEN
      IF (reset_n = '0') THEN
        sdata_out <= '0';
        i2sRx_dataLocWriteIdx <= (OTHERS => '0');
        mute <= '0';
        dataIdx <= 0;
        i2sTx_State <= IDLE_TX;
      ELSE
        CASE(i2sTx_State) IS
          WHEN IDLE_TX =>
          IF (i2sTx_Enable = '1') THEN
            changeCounter := "0";
            paddingIdx := 6;
            mute <= '1';
            i2sTx_State <= DETECT_CHANNEL;
          END IF;

          WHEN DETECT_CHANNEL =>
          IF ((lrclk_prev = '0') AND (lrclk_cur = '1')) THEN
            channelNum := "0"; -- LEFT CHANNEL
            IF (changeCounter = "1") THEN
              changeCounter := "0";
              i2sRx_dataLocWriteIdx <= i2sRx_dataLocWriteIdx + 1; -- in that case we set the write idx to be equal with the read and the first process checks our actual process
            ELSE
              -- store the data to a buffer
              IF (i2sRx_dataLocReadIdx = i2sRx_dataLocWriteIdx) THEN
                dataTmp := (OTHERS => (OTHERS => '0'));
              ELSE
                dataTmp := i2sRx_dataLoc(to_integer(i2sRx_dataLocWriteIdx));
              END IF;
              changeCounter := changeCounter + 1;
            END IF;
            dataIdx <= 0;
            i2sTx_State <= FILL_DATA;
          ELSIF ((lrclk_prev = '1') AND (lrclk_cur = '0')) THEN
            channelNum := "1"; -- RIGHT CHANNEL
            IF (changeCounter = "1") THEN
              changeCounter := "0";
              i2sRx_dataLocWriteIdx <= i2sRx_dataLocWriteIdx + 1; -- in that case we set the write idx to be equal with the read and the first process checks our actual process
            ELSE
              -- store the data to a buffer
              IF (i2sRx_dataLocReadIdx = i2sRx_dataLocWriteIdx) THEN
                dataTmp := (OTHERS => (OTHERS => '0'));
              ELSE
                dataTmp := i2sRx_dataLoc(to_integer(i2sRx_dataLocWriteIdx));
              END IF;
              changeCounter := changeCounter + 1;
            END IF;
            dataIdx <= 0;
            i2sTx_State <= FILL_DATA;
          END IF;

          WHEN FILL_DATA =>
          IF ((sclk_prev = '0') AND (sclk_curr = '1')) THEN
            sdata_out <= dataTmp(to_integer(channelNum))(23 - dataIdx);
            IF (dataIdx = 23) THEN
              dataIdx <= 0;
              i2sTx_State <= PADDING_DATA;
            ELSE
              dataIdx <= dataIdx + 1;
              i2sTx_State <= FILL_DATA;
            END IF;
          END IF;

          WHEN PADDING_DATA =>
          IF ((sclk_prev = '0') AND (sclk_curr = '1')) THEN
            sdata_out <= '0';
            IF (paddingIdx = 6) THEN -- EXTRA DELAY 
              paddingIdx := 0;
              IF (i2sTx_Enable = '0') THEN
                sdata_out <= '0';
                i2sRx_dataLocWriteIdx <= (OTHERS => '0');
                i2sTx_State <= IDLE_TX;
              ELSE
                i2sTx_State <= DETECT_CHANNEL;
              END IF;
            ELSE
              paddingIdx := paddingIdx + 1;
              i2sTx_State <= PADDING_DATA;
            END IF;
          END IF;

          WHEN OTHERS => NULL;
        END CASE;
      END IF;

    END IF;
  END PROCESS;

END Behavioral;