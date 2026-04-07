LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY I2sRx IS
	GENERIC (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- AXI4Stream sink: Data Width
		C_S_AXIS_TDATA_WIDTH : INTEGER := 32
	);
	PORT (
		-- Users to add ports here

		-- User ports ends
		-- Do not modify the ports beyond this line

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
END I2sRx;

ARCHITECTURE arch_imp OF I2sRx IS
	-- input stream data S_AXIS_TDATA 
	SIGNAL I2sReceive_Ready : STD_LOGIC;
	-- FIFO implementation signals
	SIGNAL byte_index : INTEGER;

	SIGNAL left_valid : STD_LOGIC;

	SIGNAL right_valid : STD_LOGIC;

	SIGNAL lrclk_prev_reg : STD_LOGIC;
	SIGNAL lrclk_cur_reg : STD_LOGIC;
    SIGNAL sclk_prev_reg : STD_LOGIC;
	SIGNAL sclk_cur_reg : STD_LOGIC;

	SIGNAL I2sReceive_DataIn : STD_LOGIC_VECTOR(C_S_AXIS_TDATA_WIDTH - 1 DOWNTO 0);
	SIGNAL i2sRxStart : STD_LOGIC_VECTOR (1 DOWNTO 0);

BEGIN
	-- 
	-- The example design sink is always ready to accept the S_AXIS_TDATA  until
	-- the FIFO is not filled with NUMBER_OF_INPUT_WORDS number of input words.
	I2sReceive_Ready <= '1' WHEN ((left_valid AND right_valid) /= '1') ELSE
		'0';

	-- Add user logic here
	PROCESS (mclk_in)
		VARIABLE dataIdx_cnt : INTEGER := 0;
	BEGIN
		IF rising_edge(mclk_in) THEN
			IF (I2sRx_Reset_n = '0') THEN
				I2sReceive_DataIn <= (OTHERS => '0');
				lrclk_prev_reg <= '0';
				lrclk_cur_reg <= '0';
				sclk_prev_reg <= '0';
				sclk_cur_reg <= '0';
				stream_data_left <= (OTHERS => '0');
				stream_data_right <= (OTHERS => '0');
				dataIdx_cnt := 0;
				left_valid <= '0';
				fifo_full <= '0';
				right_valid <= '0';
				i2sRxStart <= "00";
			ELSE
				-- update clocks
				sclk_prev_reg <= sclk_cur_reg;
				sclk_cur_reg <= sclk;
				lrclk_prev_reg <= lrclk_cur_reg;
				lrclk_cur_reg <= lrclk;

				-- WAIT TILL THE FIRST CYCLE
				if (lrclk_prev_reg = '0' and lrclk_cur_reg = '1' ) then
					i2sRxStart  <= "10";
				elsif (lrclk_prev_reg = '1' and lrclk_cur_reg = '0' ) then
					i2sRxStart <= "01";
				end if;

				-- capture data on rising SCLK
				IF ((sclk_prev_reg = '0' AND sclk_cur_reg = '1') AND (i2sRxStart = "01")) THEN
					I2sReceive_DataIn(31 - dataIdx_cnt) <= I2sData_In;
					IF dataIdx_cnt = 24 THEN
						stream_data_right <= I2sReceive_DataIn(30 DOWNTO 7);
						dataIdx_cnt := dataIdx_cnt + 1;
						right_valid <= '1';
					ELSIF (dataIdx_cnt = 31) THEN
						dataIdx_cnt := 0;
					ELSE
						dataIdx_cnt := dataIdx_cnt + 1;
					END IF;
				ELSIF ((sclk_prev_reg = '0' AND sclk_cur_reg = '1') AND (i2sRxStart = "10")) THEN
					I2sReceive_DataIn(31 - dataIdx_cnt) <= I2sData_In;
					IF dataIdx_cnt = 24 THEN
						stream_data_left <= I2sReceive_DataIn(30 DOWNTO 7);
						dataIdx_cnt := dataIdx_cnt + 1;
						left_valid <= '1';
					ELSIF (dataIdx_cnt = 31) THEN
						dataIdx_cnt := 0;
					ELSE
						dataIdx_cnt := dataIdx_cnt + 1;
					END IF;
				END IF;

				-- handle fifo release
				IF (I2sReceive_Ready = '0' AND release_fifo = '1') THEN
					left_valid <= '0';
					right_valid <= '0';
					fifo_full <= '0';
				ELSIF I2sReceive_Ready = '0' THEN
					fifo_full <= '1';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	-- User logic ends
END arch_imp;