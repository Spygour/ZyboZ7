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
    axi_gain : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    axi_threshold_high : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axi_threshold_low : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    axi_overdrive : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    axi_distShift : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    axi_compThresh : IN STD_LOGIC_VECTOR(23 DOWNTO 0));
END I2sTx;

ARCHITECTURE Behavioral OF I2sTx IS
  CONSTANT IDLE_AXIS : unsigned(3 DOWNTO 0) := "0000";
  CONSTANT WAIT_AXIS_FIFO_FULL_START : unsigned(3 DOWNTO 0) := "0001";
  CONSTANT WAIT_FIFO_CLEAR : unsigned(3 DOWNTO 0) := "0010";
  CONSTANT WAIT_AXIS_FIFO_FULL : unsigned(3 DOWNTO 0) := "0011";
  CONSTANT WAIT_STORE : unsigned(3 DOWNTO 0) := "0100";
  CONSTANT WAIT_RESTART : unsigned(3 DOWNTO 0) := "0101";

  CONSTANT IDLE_TX : unsigned(3 DOWNTO 0) := "0000";
  CONSTANT FILL_DATA : unsigned (3 DOWNTO 0) := "0001";
  CONSTANT DETECT_CHANNEL : unsigned (3 DOWNTO 0) := "0010";
  CONSTANT DEAD_CYCLE : unsigned (3 DOWNTO 0) := "0011";
  CONSTANT PADDING_DATA : unsigned (3 DOWNTO 0) := "0100";

  CONSTANT MEMORY_NUM : INTEGER := 6;
  TYPE TxMemory_t IS ARRAY(0 TO MEMORY_NUM - 1) OF signed(23 DOWNTO 0);
  TYPE coeff_array_t IS ARRAY(0 TO MEMORY_NUM) OF signed(3 DOWNTO 0);
  CONSTANT FIR_COEFF : coeff_array_t := (
    to_signed(-1, 4),
    to_signed(-1, 4),
    to_signed(2, 4),
    to_signed(5, 4),
    to_signed(2, 4),
    to_signed(-1, 4),
    to_signed(-1, 4)
  );

  SIGNAL configReg : STD_LOGIC;
  SIGNAL sclk_prev : STD_LOGIC;
  SIGNAL sclk_curr : STD_LOGIC;
  SIGNAL lrclk_prev : STD_LOGIC;
  SIGNAL lrclk_cur : STD_LOGIC;

  SIGNAL i2sRx_dataLoc : TxFifo_t := (OTHERS => (OTHERS => (OTHERS => '0')));
  SIGNAL i2sRx_dataLocReadIdx : unsigned(0 DOWNTO 0);
  SIGNAL i2sRx_dataLocWriteIdx : unsigned(0 DOWNTO 0);
  SIGNAL stream_data_left_prev : signed(23 DOWNTO 0);
  SIGNAL stream_data_right_prev : signed(23 DOWNTO 0);

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

  SIGNAL gain : unsigned(6 DOWNTO 0);
  SIGNAL threshold_high : signed(23 DOWNTO 0);
  SIGNAL threshold_low : signed(23 DOWNTO 0);
  SIGNAL overdrive : signed(7 DOWNTO 0);
  SIGNAL distortion_shift : unsigned(6 DOWNTO 0);
  SIGNAL compressor_thresh : signed(23 DOWNTO 0);

  FUNCTION fir_filter(
    sample_input : signed(23 DOWNTO 0);
    memory : TxMemory_t;
    coeff : coeff_array_t;
    memory_num : INTEGER
  ) RETURN signed IS
    VARIABLE result : signed(23 DOWNTO 0);
    VARIABLE temp : signed(27 DOWNTO 0);
    VARIABLE idx : INTEGER;
  BEGIN
    temp := (OTHERS => '0');
    FOR idx IN 0 TO (memory_num - 1) LOOP
      temp := temp + memory(idx) * coeff(idx);
    END LOOP;
    temp := temp + sample_input * coeff(memory_num);
    temp := shift_right(temp, 3);
    result := resize(temp, 24);
    RETURN result;
  END FUNCTION;

  FUNCTION apply_gain_clip(
    sample_input : signed(23 DOWNTO 0);
    gain_input : signed(7 DOWNTO 0);
    threshold_high : signed(23 DOWNTO 0);
    threshold_low : signed(23 DOWNTO 0);
    compThresh : signed(23 DOWNTO 0)
  ) RETURN signed IS
    VARIABLE result : signed(23 DOWNTO 0);
    VARIABLE compressed : signed(23 DOWNTO 0);
    VARIABLE temp : signed(31 DOWNTO 0); -- 29-bit temp
  BEGIN
    -- multiply 24x5 -> 29 bits, resize to 29 for safety
    IF (ABS(sample_input) > compThresh) THEN
      compressed := sample_input - shift_right(sample_input, 1);
    ELSE
      compressed := sample_input + shift_right(sample_input, 1);
    END IF;
    temp := compressed * gain_input;
    -- clipping
    IF temp > resize(threshold_high, 32) THEN
      result := threshold_high;
    ELSIF temp < resize(threshold_low, 32) THEN
      result := threshold_low;
    ELSE
      result := resize(temp, 24);
    END IF;
    RETURN result;
  END FUNCTION;

  FUNCTION apply_soft_clip(
    sample_input : signed(23 DOWNTO 0);
    K : signed(7 DOWNTO 0);
    normalization : unsigned(4 DOWNTO 0);
    threshold_high : signed(23 DOWNTO 0);
    threshold_low : signed(23 DOWNTO 0);
    qubic_shift : unsigned(6 DOWNTO 0);
    compThresh : signed(23 DOWNTO 0);
    add_input : STD_LOGIC;
    tight_input : STD_LOGIC
  ) RETURN signed IS
    VARIABLE result : signed(23 DOWNTO 0); -- 24 bit temp
    VARIABLE pregain : signed(23 DOWNTO 0);
    VARIABLE compressed : signed(23 DOWNTO 0);
    VARIABLE temp : signed(31 DOWNTO 0);
    VARIABLE temp1 : signed(31 DOWNTO 0); -- 32 bit temp
    VARIABLE temp2 : signed(63 DOWNTO 0); -- 64-bit temp
    VARIABLE qubic_temp1 : signed(95 DOWNTO 0); -- 96 bit temp
    VARIABLE qubic_temp2 : signed(95 DOWNTO 0);
    VARIABLE normalize : INTEGER;
  BEGIN
    -- calculate the normalization
    normalize := to_integer(normalization);
    IF (tight_input = '1') THEN
      pregain := sample_input - shift_right(sample_input, 1);
    END IF;
    pregain := shift_left(pregain, 1);
    IF (ABS(pregain) > compThresh) THEN
      compressed := shift_right(pregain, 1);
    ELSE
      compressed := shift_left(pregain, 1);
    END IF;
    -- calculate the new sample gained and normalized
    temp := compressed * K;
    temp1 := shift_right(temp, normalize);

    -- calculate norm * norm
    temp2 := temp1 * temp1;
    -- calcualte the norm ^ 3
    qubic_temp1 := temp1 * temp2;
    -- remove the qubic from the sample
    qubic_temp2 := resize(temp1, 96) - shift_right(qubic_temp1, to_integer(qubic_shift));
    -- normalize back
    qubic_temp2 := shift_left(qubic_temp2, normalize);
    IF (add_input = '1') THEN
      qubic_temp2 := shift_right(qubic_temp2, 1) + shift_right(resize(sample_input, 96), 1);
    END IF;
    -- apply the thresholds
    IF (qubic_temp2 > resize(threshold_high, 96)) THEN
      result := threshold_high;
    ELSIF (qubic_temp2 < resize(threshold_low, 96)) THEN
      result := threshold_low;
    ELSE
      result := resize(qubic_temp2, 24);
    END IF;

    RETURN result;
  END FUNCTION;

BEGIN
  threshold_high <= signed(axi_threshold_high);
  threshold_low <= signed(axi_threshold_low);
  gain <= unsigned(axi_gain);
  configReg <= axi_enableIpReg;
  overdrive <= signed(axi_overdrive);
  distortion_shift <= unsigned(axi_distShift);
  compressor_thresh <= signed(axi_compThresh);

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
    VARIABLE mix_input : STD_LOGIC;
    VARIABLE tight_en : STD_LOGIC;
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
        stream_data_left_prev <= (OTHERS => '0');
        stream_data_right_prev <= (OTHERS => '0');
        left_channel_mem <= (OTHERS => (OTHERS => '0'));
        right_channel_mem <= (OTHERS => (OTHERS => '0'));
        mix_input := '0';
        tight_en := '0';
        axis_control_state <= IDLE_AXIS;
      ELSE
        CASE(axis_control_state) IS
          WHEN IDLE_AXIS =>
          IF (configReg = '1') THEN
            -- Stop the clearance of fifo , ready t get first data
            axis_release_fifo <= '0';
            tight_en := '1';
            mix_input := '1';
            axis_control_state <= WAIT_AXIS_FIFO_FULL_START;
          END IF;

          WHEN WAIT_AXIS_FIFO_FULL_START =>
          IF (axis_fifo_full = '1') THEN
            i2sRxData_Left := fir_filter(signed(axis_stream_data_left), left_channel_mem, FIR_COEFF, MEMORY_NUM);
            i2sRxData_Right := fir_filter(signed(axis_stream_data_right), right_channel_mem, FIR_COEFF, MEMORY_NUM);
            IF (gain(1 DOWNTO 0) = "01") THEN
              i2sRxData_Left := apply_soft_clip(i2sRxData_Left + stream_data_left_prev, overdrive, unsigned(gain(6 DOWNTO 2)), threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input, tight_en);
              i2sRxData_Right := apply_soft_clip(i2sRxData_Right + stream_data_right_prev, overdrive, unsigned(gain(6 DOWNTO 2)), threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input, tight_en);
            ELSIF ((gain(1 DOWNTO 0) = "10") OR (gain(1 DOWNTO 0) = "11")) THEN
              i2sRxData_Left := apply_gain_clip(i2sRxData_Left + stream_data_left_prev, overdrive, threshold_high, threshold_low, compressor_thresh);
              i2sRxData_Right := apply_gain_clip(i2sRxData_Right + stream_data_right_prev, overdrive, threshold_high, threshold_low, compressor_thresh);
            ELSIF (gain (1 DOWNTO 0) = "00") THEN
              i2sRxData_Left := i2sRxData_Left;
              i2sRxData_Right := i2sRxData_Right;
            END IF;
            stream_data_left_prev <= shift_right(i2sRxData_Left, 8);
            stream_data_right_prev <= shift_right(i2sRxData_Right, 8);
            i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(0) <= STD_LOGIC_VECTOR(i2sRxData_Left);
            i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(1) <= STD_LOGIC_VECTOR(i2sRxData_Right);
            i2sRx_dataLocReadIdx <= i2sRx_dataLocReadIdx + 1;
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
            -- set the fifo read to be full
            axis_release_fifo <= '0';
            axis_control_state <= WAIT_AXIS_FIFO_FULL;
          ELSIF (configReg = '0') THEN
            -- Stop the clearance of fifo , ready t get first data
            i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
            i2sRx_dataLocReadIdx <= "0";
            i2sTx_Enable <= '0';
            axis_release_fifo <= '1';
            axis_control_state <= IDLE_AXIS;
          END IF;

          WHEN WAIT_AXIS_FIFO_FULL =>
          IF (axis_fifo_full = '1') THEN
            i2sRxData_Left := fir_filter(signed(axis_stream_data_left), left_channel_mem, FIR_COEFF, MEMORY_NUM);
            i2sRxData_Right := fir_filter(signed(axis_stream_data_right), right_channel_mem, FIR_COEFF, MEMORY_NUM);
            IF (gain(1 DOWNTO 0) = "01") THEN
              i2sRxData_Left := apply_soft_clip(i2sRxData_Left + stream_data_left_prev, overdrive, unsigned(gain(6 DOWNTO 2)), threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input, tight_en);
              i2sRxData_Right := apply_soft_clip(i2sRxData_Right + stream_data_right_prev, overdrive, unsigned(gain(6 DOWNTO 2)), threshold_high, threshold_low, distortion_shift(6 DOWNTO 0), compressor_thresh, mix_input, tight_en);
            ELSIF ((gain(1 DOWNTO 0) = "10") OR (gain(1 DOWNTO 0) = "11")) THEN
              i2sRxData_Left := apply_gain_clip(i2sRxData_Left + stream_data_left_prev, overdrive, threshold_high, threshold_low, compressor_thresh);
              i2sRxData_Right := apply_gain_clip(i2sRxData_Right + stream_data_right_prev, overdrive, threshold_high, threshold_low, compressor_thresh);
            ELSIF (gain (1 DOWNTO 0) = "00") THEN
              i2sRxData_Left := i2sRxData_Left;
              i2sRxData_Right := i2sRxData_Right;
            END IF;
            stream_data_left_prev <= shift_right(i2sRxData_Left, 8);
            stream_data_right_prev <= shift_right(i2sRxData_Right, 8);
            i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(0) <= STD_LOGIC_VECTOR(i2sRxData_Left);
            i2sRx_dataLoc(to_integer(i2sRx_dataLocReadIdx))(1) <= STD_LOGIC_VECTOR(i2sRxData_Right);
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
            i2sTx_Enable <= '1';
            axis_release_fifo <= '0';
            axis_control_state <= WAIT_RESTART;
          ELSIF (configReg = '0') THEN
            -- Stop the clearance of fifo , ready t get first data
            i2sRx_dataLoc <= (OTHERS => (OTHERS => (OTHERS => '0')));
            i2sRx_dataLocReadIdx <= "0";
            i2sTx_Enable <= '0';
            axis_release_fifo <= '1';
            axis_control_state <= IDLE_AXIS;
          END IF;

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