LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE I2sTypes IS
  TYPE LrData_t IS ARRAY(0 TO 1) OF STD_LOGIC_VECTOR(23 DOWNTO 0);
  TYPE TxFifo_t IS ARRAY(0 TO 1) OF LrData_t;

END I2sTypes;