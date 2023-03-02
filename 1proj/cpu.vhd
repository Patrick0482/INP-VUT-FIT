-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): xfrust00 <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
    
    --PC
    signal pc_increment: std_logic;
    signal pc_decrement: std_logic;
    signal pc_output: std_logic_vector(12 downto 0);
    
    --PTR
    signal ptr_increment: std_logic;
    signal ptr_decrement: std_logic;
    signal ptr_output: std_logic_vector(11 downto 0);
    
    --MX1
    signal mux1_selector: std_logic;
    
    --MX2
    signal mux2_selector: std_logic_vector(1 downto 0);
    
    --FSM
    type fsm_state is (
      IDLE,
      FETCH,
      DECODE,
    
      STATE_NEXT, 
      STATE_PREVIOUS,
    
      INCREMENT,
      INCREMENT_VAL,
    
      DECREMENT,
      DECREMENT_VALUE,
    
      PRINT,
      PRINT_VALUE,
    
      STATE_INPUT,
    
      WHILE_START,
      WHILE_CHECK,
      WHILE_NOT_END,
      WHILE_END,
      WHILE_END_CHECK,
      WHILE_NOT_START,
    
      DOWHILE_START,   
      DOWHILE_END,      
      DOWHILE_END_CHECK,
      DOWHILE_NOT_START,
    
      STATE_NULL,
      STATE_OTHER
    );
    signal state: fsm_state;
    signal next_state: fsm_state;
    
    
    begin
    
    PC: process(CLK, RESET) is
    begin
     if RESET = '1' then
       pc_output <= "0000000000000";
     elsif CLK'event and CLK = '1' then
       if pc_increment = '1' and pc_decrement = '1' then
         pc_output <= pc_output + 1;
       elsif pc_increment = '1' then
         pc_output <= pc_output + 1;
       elsif pc_decrement = '1' then
         pc_output <= pc_output - 1;
       end if;
     end if;
    end process;
    
    PTR: process(CLK, RESET) is
     begin
     if RESET = '1' then
       ptr_output <= "000000000000";
     elsif CLK'event and CLK = '1' then
       if ptr_increment = '1' then
         ptr_output <= ptr_output + 1;
       elsif ptr_decrement = '1'  then
         ptr_output <= ptr_output - 1;
       end if;
     end if; 
    end process;
    
    
    -- MUX1
    MUX1: process(CLK, RESET, mux1_selector) is
     begin
     if mux1_selector = '0' then
         DATA_ADDR <= pc_output;
         elsif mux1_selector = '1' then
             DATA_ADDR <= "1" & ptr_output;
         else 
             DATA_ADDR <= "0000000000000";
         end if;
     end process;
    
    --MUX2
    MUX2: process(CLK, RESET, mux2_selector) is
     begin
     if mux2_selector = "00" then
         DATA_WDATA <= IN_DATA;
         elsif mux2_selector = "01" then
             DATA_WDATA <= DATA_RDATA + 1;
         elsif mux2_selector = "10" then
             DATA_WDATA <= DATA_RDATA - 1; 
         else 
             DATA_WDATA <= "00000000";
         end if;
     end process; 



  -- FSM state register
  STATEREG: process(CLK, RESET) is
  begin
    if RESET = '1' then
      state <= IDLE;
    elsif CLK'event and CLK = '1' and EN = '1' then
      state <= next_state;
    end if;
  end process;
    
  -- FSM next state logic 
  FSM_LOGIC: process(state, IN_VLD, OUT_BUSY, DATA_RDATA, EN) is
  begin
    -- Initialization
    IN_REQ <= '0';
    OUT_WE <= '0';
    DATA_RDWR <= '0';
    DATA_EN <= '0';

    pc_increment <= '0';
    pc_decrement <= '0';
    
    ptr_increment <= '0';
    ptr_decrement <= '0';
    
    mux1_selector <= '0'; 
    mux2_selector <= "00";  

    if EN = '1' then
      case state is
        when IDLE =>
          next_state <= FETCH;
        when FETCH =>
          next_state <= DECODE;
          DATA_EN <= '1';
        when DECODE =>
          case DATA_RDATA is
            -- >
            when X"3E" =>
              next_state <= STATE_NEXT;
            -- <
            when X"3C" =>
              next_state <= STATE_PREVIOUS;
            -- +
            when X"2B" =>
              next_state <= INCREMENT;
            -- -
            when X"2D" =>
              next_state <= DECREMENT;
            -- .
            when X"2E" =>
              next_state <= PRINT;
            -- ,
            when X"2C" =>
              next_state <= STATE_INPUT;
            -- [
            when X"5B" =>
              next_state <= WHILE_START;
            -- ]
            when X"5D" =>
              next_state <= WHILE_END;
            -- (
            when X"28" =>
              next_state <= DOWHILE_START;
            -- )
            when X"29" =>
              next_state <= DOWHILE_END;
            when X"00" =>
              next_state <= STATE_NULL;
            when others =>
              next_state <= STATE_OTHER;
          end case;

        when STATE_NEXT => 
            next_state <= FETCH;
            ptr_increment <= '1';
            pc_increment <= '1';

        when STATE_PREVIOUS =>
            next_state <= FETCH;
            ptr_decrement <= '1';
            pc_increment <= '1';

          
        when DECREMENT =>
            next_state <= DECREMENT_VALUE;
            DATA_EN <= '1'; 
            mux1_selector <= '1'; 
            
        when DECREMENT_VALUE =>
            next_state <= FETCH;
            DATA_EN <= '1'; 
            DATA_RDWR <= '1'; 
            mux1_selector <= '1'; 
            mux2_selector <= "10"; 
            pc_increment <= '1'; 
          
        when INCREMENT =>
            next_state <= INCREMENT_VAL;
            DATA_EN <= '1';
            mux1_selector <= '1'; 
        
        when INCREMENT_VAL =>
            next_state <= FETCH;
            DATA_EN <= '1'; 
            DATA_RDWR <= '1'; 
            mux1_selector <= '1'; 
            mux2_selector <= "01"; 
            pc_increment <= '1'; 
          
        when STATE_INPUT =>
            IN_REQ <= '1';
            if IN_VLD = '1' then
                next_state <= FETCH;
                DATA_EN <= '1';
                DATA_RDWR <= '1';
                mux1_selector <= '1';
                pc_increment <= '1';
            else
                next_state <= STATE_INPUT;
            end if;

        when PRINT =>
          if OUT_BUSY = '1' then
            next_state <= PRINT;
          else
            next_state <= PRINT_VALUE;
            DATA_EN <= '1';
            mux1_selector <= '1';
          end if;
            
        when PRINT_VALUE =>
          if OUT_BUSY = '1' then
            next_state <= PRINT;
          else
            next_state <= FETCH;
            OUT_WE <= '1';
            OUT_DATA <= DATA_RDATA;
            pc_increment <= '1';
          end if;

        when WHILE_START =>
            next_state <= WHILE_CHECK;
            DATA_EN <= '1';
            mux1_selector <= '1';
            pc_increment <= '1';
            
        when WHILE_CHECK =>
          if DATA_RDATA = X"00" then
            next_state <= WHILE_NOT_END;
            DATA_EN <= '1';
            else
            next_state <= FETCH;
          end if;

        when WHILE_NOT_END =>
            pc_increment <= '1';
            
            if DATA_RDATA = X"5D" then
                next_state <= FETCH;
            else
                next_state <= WHILE_NOT_END;
                DATA_EN <= '1';
            end if;
        
        when WHILE_END =>
            next_state <= WHILE_END_CHECK;
            mux1_selector <= '1';
            DATA_EN <= '1';
        
        when WHILE_END_CHECK =>
            if DATA_RDATA = X"00" then
                next_state <= FETCH;
                pc_increment <= '1';
            else
                next_state <= WHILE_NOT_START;
                DATA_EN <= '1';
            end if;

        when WHILE_NOT_START =>
            if pc_output = X"00" then
                pc_decrement <= '0';
            else
                pc_decrement <= '1';
            end if;
            -- [
            if DATA_RDATA = X"5B" then
                next_state <= FETCH;
                pc_increment <= '1';
            else
                next_state <= WHILE_NOT_START;
                DATA_EN <= '1';
            end if;
        
        when DOWHILE_START =>
                next_state <= FETCH;
                pc_increment <= '1';
        
        when DOWHILE_END =>
                next_state <= DOWHILE_END_CHECK;
                DATA_EN <= '1';
                mux1_selector <= '1';

        when DOWHILE_END_CHECK =>
            if DATA_RDATA = X"00" then
                next_state <= FETCH;
                pc_increment <= '1';
            else
                next_state <= DOWHILE_NOT_START;
                DATA_EN <= '1';
            end if;
        
        when DOWHILE_NOT_START =>
            if pc_output = X"00" then
                pc_decrement <= '0';
            else
                pc_decrement <= '1';
            end if;
            -- (
            if DATA_RDATA = X"28" then
                next_state <= FETCH;
                pc_increment <= '1';
            else
                DATA_EN <= '1';
                next_state <= DOWHILE_NOT_START;
            end if;
          
        when STATE_OTHER =>
            next_state <= FETCH;
            pc_increment <= '1';

        when STATE_NULL => null;
        
        when others => null;
      end case;
    end if;
  end process;
end behavioral;