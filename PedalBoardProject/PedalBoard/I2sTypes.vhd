LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE I2sTypes IS
  CONSTANT MEMORY_NUM : INTEGER := 6;
  CONSTANT PHASE_TIME_VARIANTS : INTEGER := 4;
  CONSTANT PHASE_DEPTH : INTEGER := 6;
  CONSTANT PHASE_NUM : INTEGER := 12;
  TYPE LrData_t IS ARRAY(0 TO 1) OF STD_LOGIC_VECTOR(23 DOWNTO 0);
  TYPE TxFifo_t IS ARRAY(0 TO 1) OF LrData_t;
  TYPE TxMemory_t IS ARRAY(0 TO MEMORY_NUM - 1) OF signed(23 DOWNTO 0);
  TYPE coeff_array_t IS ARRAY(0 TO MEMORY_NUM) OF signed(3 DOWNTO 0);
  TYPE phase_pair_array_t IS ARRAY(0 TO 1) OF unsigned(3 DOWNTO 0);
  TYPE phase_minmax_array_t IS ARRAY(0 TO PHASE_DEPTH) OF phase_pair_array_t;
  TYPE phase_time_array_t IS ARRAY(0 TO PHASE_TIME_VARIANTS) OF unsigned(16 DOWNTO 0);
  TYPE phase_shift_array_t IS ARRAY (0 TO PHASE_NUM) OF unsigned(3 DOWNTO 0);
  CONSTANT IDLE_AXIS : unsigned(3 DOWNTO 0) := "0000";
  CONSTANT HIGH_PASS : unsigned(3 DOWNTO 0) := "0001";
  CONSTANT WAIT_FIFO_CLEAR : unsigned(3 DOWNTO 0) := "0010";
  CONSTANT WAIT_AXIS_FIFO_FULL : unsigned(3 DOWNTO 0) := "0011";
  CONSTANT CHECK_DISTORTION : unsigned(3 DOWNTO 0) := "0100";
  CONSTANT WAIT_RESTART : unsigned(3 DOWNTO 0) := "0101";
  CONSTANT PHASE_CYCLE_START : unsigned(3 DOWNTO 0) := "0110";
  CONSTANT PHASE_CYCLE : unsigned(3 DOWNTO 0) := "0111";
  CONSTANT LOW_PASS_START : unsigned(3 DOWNTO 0) := "1000";
  CONSTANT LOW_PASS : unsigned(3 DOWNTO 0) := "1001";

  CONSTANT IDLE_TX : unsigned(3 DOWNTO 0) := "0000";
  CONSTANT FILL_DATA : unsigned (3 DOWNTO 0) := "0001";
  CONSTANT DETECT_CHANNEL : unsigned (3 DOWNTO 0) := "0010";
  CONSTANT DEAD_CYCLE : unsigned (3 DOWNTO 0) := "0011";
  CONSTANT PADDING_DATA : unsigned (3 DOWNTO 0) := "0100";

  CONSTANT PHASE_TIME_ARRAY : phase_time_array_t := (
    to_unsigned(400, 17),
    to_unsigned(800, 17),
    to_unsigned(1600, 17),
    to_unsigned(3200, 17),
    to_unsigned(6400, 17)
  );

  CONSTANT PHASE_COEFF_ARRAY : phase_shift_array_t := ( --from 0.9 to 0.5 
   to_unsigned(14, 4), -- this is near 1
   to_unsigned(13, 4),
   to_unsigned(12, 4),
   to_unsigned(11, 4),
   to_unsigned(10, 4),
   to_unsigned(9, 4),
   to_unsigned(7, 4),
   to_unsigned(6, 4), 
   to_unsigned(5, 4), 
   to_unsigned(4, 4),
   to_unsigned(3, 4),
   to_unsigned(2, 4),
   to_unsigned(1, 4) -- this is the 0.5
  );

  CONSTANT PHASE_MIN_MAX_LUT : phase_minmax_array_t := (
  (to_unsigned(0, 4), to_unsigned(6, 4)),
    (to_unsigned(0, 4), to_unsigned(7, 4)),
    (to_unsigned(0, 4), to_unsigned(8, 4)),
    (to_unsigned(0, 4), to_unsigned(9, 4)),
    (to_unsigned(0, 4), to_unsigned(10, 4)),
    (to_unsigned(0, 4), to_unsigned(11, 4)),
    (to_unsigned(0, 4), to_unsigned(12, 4))
  );

  CONSTANT FIR_COEFF : coeff_array_t := (
    to_signed(-1, 4),
    to_signed(-1, 4),
    to_signed(2, 4),
    to_signed(5, 4),
    to_signed(2, 4),
    to_signed(-1, 4),
    to_signed(-1, 4)
  );
  -- HIGH PASS FILTER FUNCTION
  FUNCTION hp_filter(
    x_current : signed(23 DOWNTO 0);
    x_prev : signed(23 DOWNTO 0);
    y_prev : signed(23 DOWNTO 0);
    a_shift : unsigned(3 DOWNTO 0)
  ) RETURN signed;

  -- IIR LOW PASS FILTER FUNCTION
  FUNCTION lp_filter(
    x_current : signed(23 DOWNTO 0);
    y_prev : signed(23 DOWNTO 0);
    a_shift : unsigned(3 DOWNTO 0)
  ) RETURN signed;

  -- FIR FILTER FUNCTION
  FUNCTION fir_filter(
    sample_input : signed(23 DOWNTO 0);
    memory : TxMemory_t;
    coeff : coeff_array_t;
    memory_num : INTEGER
  ) RETURN signed;

  -- ALL PASS FILTER FUNCTION
  FUNCTION ap_filter(
    x_current : signed(23 DOWNTO 0);
    x_prev : signed(23 DOWNTO 0);
    y_prev : signed(23 DOWNTO 0);
    a_shift : unsigned(3 DOWNTO 0)
  ) RETURN signed;

  -- FUZZY TYPE DISTORTION
  FUNCTION apply_gain_clip(
    sample_input : signed(23 DOWNTO 0);
    gain_input : unsigned(3 DOWNTO 0);
    threshold_high : signed(23 DOWNTO 0);
    threshold_low : signed(23 DOWNTO 0);
    compThresh : signed(23 DOWNTO 0)
  ) RETURN signed;

  -- SOFT CLIP DISTORTION
  FUNCTION apply_soft_clip(
    sample_input : signed(23 DOWNTO 0);
    K : unsigned(3 DOWNTO 0);
    normalization : unsigned(4 DOWNTO 0);
    threshold_high : signed(23 DOWNTO 0);
    threshold_low : signed(23 DOWNTO 0);
    qubic_shift : unsigned(6 DOWNTO 0);
    compThresh : signed(23 DOWNTO 0);
    add_input : STD_LOGIC
  ) RETURN signed;

  PROCEDURE update_phase(
    VARIABLE a_shift_idx : INOUT unsigned(3 DOWNTO 0);
    SIGNAL a_shift_inc : IN unsigned(1 DOWNTO 0);
    VARIABLE dir : INOUT STD_LOGIC;
    VARIABLE phase_cnt : INOUT unsigned(16 DOWNTO 0);
    CONSTANT max_idx : IN unsigned(3 DOWNTO 0);
    CONSTANT min_idx : IN unsigned(3 DOWNTO 0);
    CONSTANT max_time : IN unsigned(16 DOWNTO 0)
  );

END I2sTypes;

PACKAGE BODY I2sTypes IS
  -- HIGH PASS FILTER FUNCTION
  FUNCTION hp_filter(
    x_current : signed(23 DOWNTO 0);
    x_prev : signed(23 DOWNTO 0);
    y_prev : signed(23 DOWNTO 0);
    a_shift : unsigned(3 DOWNTO 0)
  ) RETURN signed IS
    VARIABLE temp : signed(31 DOWNTO 0);
    VARIABLE temp2 : signed(31 DOWNTO 0);
    VARIABLE result : signed(23 DOWNTO 0);
  BEGIN
    temp2 := resize(x_current, 32) - resize(x_prev, 32);
    IF (a_shift(3) = '1') THEN
      temp := temp2 - shift_right(temp2,to_integer(a_shift(2 DOWNTO 0)))  + resize(y_prev, 32) - shift_right(resize(y_prev, 32), to_integer(a_shift(2 DOWNTO 0)));
    ELSE
      temp := shift_right(temp2,to_integer(a_shift(2 DOWNTO 0))) + shift_right(resize(y_prev, 32), to_integer(a_shift(2 DOWNTO 0))); --multiply both of them
    END IF;
    result := resize(temp, 24);
    RETURN result;
  END FUNCTION;

  -- IIR LOW PASS FILTER FUNCTION
  FUNCTION lp_filter(
    x_current : signed(23 DOWNTO 0);
    y_prev : signed(23 DOWNTO 0);
    a_shift : unsigned(3 DOWNTO 0)
  ) RETURN signed IS
    VARIABLE temp : signed(31 DOWNTO 0);
    VARIABLE result : signed(23 DOWNTO 0);
  BEGIN
    IF (a_shift(3) = '1') THEN
      temp := shift_right(resize(x_current, 32), to_integer(a_shift(2 DOWNTO 0))) + resize(y_prev, 32) - shift_right(resize(y_prev, 32), to_integer(a_shift(2 DOWNTO 0)));
    ELSE
      temp := resize(x_current, 32) - shift_right(resize(x_current, 32), to_integer(a_shift(2 DOWNTO 0))) + shift_right(resize(y_prev, 32), to_integer(a_shift(2 DOWNTO 0)));
    END IF;
    result := resize(temp, 24);
    RETURN result;
  END FUNCTION;

  -- FIR FILTER FUNCTION
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

  -- ALL PASS FILTER FUNCTION
  FUNCTION ap_filter(
    x_current : signed(23 DOWNTO 0);
    x_prev : signed(23 DOWNTO 0);
    y_prev : signed(23 DOWNTO 0);
    a_shift : unsigned(3 DOWNTO 0)
  ) RETURN signed IS
    VARIABLE temp1 : signed(24 DOWNTO 0);
    VARIABLE temp2 : signed(24 DOWNTO 0);
    VARIABLE result : signed(23 DOWNTO 0);
  BEGIN
    temp1 :=   resize(y_prev, 25) - resize(x_current,25);
    temp2 := temp1 - shift_right(temp1, to_integer(a_shift)); -- we want the filter to be much greater than 0.5 to work for phaser so its value - (vallue >> num) where num > 1
    temp2 := temp2 + resize(x_prev, 25);
    result := resize(temp2, 24);
    RETURN result;
  END FUNCTION;

  -- FUZZY TYPE DISTORTION
  FUNCTION apply_gain_clip(
    sample_input : signed(23 DOWNTO 0);
    gain_input : unsigned(3 DOWNTO 0);
    threshold_high : signed(23 DOWNTO 0);
    threshold_low : signed(23 DOWNTO 0);
    compThresh : signed(23 DOWNTO 0)
  ) RETURN signed IS
    VARIABLE result : signed(23 DOWNTO 0);
    VARIABLE compressed : signed(23 DOWNTO 0);
  BEGIN
    -- multiply 24x5 -> 29 bits, resize to 29 for safety
    IF (ABS(sample_input) > compThresh) THEN
      compressed := sample_input - shift_right(sample_input, 1);
    ELSE
      compressed := sample_input + shift_right(sample_input, 1);
    END IF;
    compressed := shift_left(compressed, to_integer(gain_input));
    IF compressed > threshold_high THEN
      result := threshold_high;
    ELSIF compressed < threshold_low THEN
      result := threshold_low;
    ELSE
      result := compressed;
    END IF;
    RETURN result;
  END FUNCTION;

  -- SOFT CLIP DISTORTION
  FUNCTION apply_soft_clip(
    sample_input : signed(23 DOWNTO 0);
    K : unsigned(3 DOWNTO 0);
    normalization : unsigned(4 DOWNTO 0);
    threshold_high : signed(23 DOWNTO 0);
    threshold_low : signed(23 DOWNTO 0);
    qubic_shift : unsigned(6 DOWNTO 0);
    compThresh : signed(23 DOWNTO 0);
    add_input : STD_LOGIC
  ) RETURN signed IS
    VARIABLE result : signed(23 DOWNTO 0); -- 24 bit temp
    VARIABLE pregain : signed(23 DOWNTO 0);
    VARIABLE compressed : signed(23 DOWNTO 0);
    VARIABLE temp : signed(39 DOWNTO 0);
    VARIABLE temp1 : signed(39 DOWNTO 0); -- 32 bit temp
    VARIABLE temp2 : signed(79 DOWNTO 0); -- 64-bit temp
    VARIABLE qubic_temp1 : signed(119 DOWNTO 0); -- 96 bit temp
    VARIABLE qubic_temp2 : signed(119 DOWNTO 0);
    VARIABLE normalize : INTEGER;
  BEGIN
    -- calculate the normalization
    normalize := to_integer(normalization);
    IF (ABS(sample_input) > compThresh) THEN
      compressed := shift_right(sample_input, 1);
    ELSE
      compressed := shift_left(sample_input, 1);
    END IF;
    pregain := shift_left(compressed, 1);
    -- calculate the new sample gained and normalized
    temp := shift_left(resize(pregain, 40), to_integer(K));
    temp1 := shift_right(temp, normalize);
    -- calculate norm * norm
    temp2 := temp1 * temp1;
    -- calcualte the norm ^ 3
    qubic_temp1 := temp1 * temp2;
    -- remove the qubic from the sample
    qubic_temp2 := resize(temp1, 119) - shift_right(qubic_temp1, to_integer(qubic_shift));
    IF (add_input = '1') THEN
      qubic_temp2 := shift_right(qubic_temp2, 1) + shift_right(resize(temp1, 119), 1);
    END IF;
    -- normalize back
    qubic_temp2 := shift_left(qubic_temp2, normalize);
    -- apply the thresholds
    IF (qubic_temp2 > resize(threshold_high, 119)) THEN
      result := threshold_high;
    ELSIF (qubic_temp2 < resize(threshold_low, 119)) THEN
      result := threshold_low;
    ELSE
      result := resize(qubic_temp2, 24);
    END IF;

    RETURN result;
  END FUNCTION;

  PROCEDURE update_phase(
    VARIABLE a_shift_idx : INOUT unsigned(3 DOWNTO 0);
    SIGNAL a_shift_inc : IN unsigned(1 DOWNTO 0);
    VARIABLE dir : INOUT STD_LOGIC;
    VARIABLE phase_cnt : INOUT unsigned(16 DOWNTO 0);
    CONSTANT max_idx : IN unsigned(3 DOWNTO 0);
    CONSTANT min_idx : IN unsigned(3 DOWNTO 0);
    CONSTANT max_time : IN unsigned(16 DOWNTO 0)
  ) IS
  BEGIN
    IF (phase_cnt >= max_time) THEN
      phase_cnt := (OTHERS => '0');
      IF (dir = '0') THEN --increase
        a_shift_idx := a_shift_idx + resize(a_shift_inc, 4) + to_unsigned(1, 4); -- add extra increment
        IF (a_shift_idx >= max_idx) THEN
          a_shift_idx := max_idx;
          dir := '1'; -- start decreasing back
        END IF;
      ELSE --decrease
        a_shift_idx := a_shift_idx - resize(a_shift_inc, 4) - to_unsigned(1, 4); -- add extra decrement
        IF (a_shift_idx <= min_idx) OR (a_shift_idx > max_idx) THEN --oveflow happened
          a_shift_idx := min_idx;
          dir := '0'; --start increasing back
        END IF;
      END IF;
    ELSE
      phase_cnt := phase_cnt + 1;
    END IF;
  END PROCEDURE;

END PACKAGE BODY;