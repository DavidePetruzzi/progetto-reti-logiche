---------------------------------------------------------------------------
--
-- Prova Finale (Progetto di Reti Logiche)
-- Docente: Gianluca Palermo
--
-- Davide Petruzzi
--
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);

        o_done : out std_logic;

        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic
    );
end project_reti_logiche;

architecture behavioral of project_reti_logiche is
    type state_type is (IDLE, READ_K_MSB, READ_K_LSB, READ_S_HEADER, READ_C_HEADER, READ_DATA, ELABORATION_DATA, WRITE_DATA, WAIT_FOR_READ_DATA, DONE);
    signal next_state, current_state : state_type;

    signal byte_counter: unsigned(15 downto 0);
    signal addr_counter: unsigned(15 downto 0);
    signal coefficient_counter: integer range 0 to 6;

    signal next_addr_counter: unsigned(15 downto 0);
    signal next_byte_counter: unsigned(15 downto 0);
    signal next_coefficient_counter: integer range 0 to 6;

    signal K: std_logic_vector(15 downto 0);
    signal S: std_logic;
    signal C0, C1, C2, C3, C4, C5, C6: signed(7 downto 0);

    signal next_K: std_logic_vector(15 downto 0);
    signal next_S: std_logic;
    signal next_C0, next_C1, next_C2, next_C3, next_C4, next_C5, next_C6: signed(7 downto 0);

    type data_array is array(0 to 6) of signed(7 downto 0);
    signal data_sequence: data_array; 
    signal filter_result: signed(17 downto 0);

    signal next_filter_result: signed(17 downto 0);

begin
    -- Registro di stato e segnali su clock
    state_reg: process (i_clk, i_rst)
    begin
        if i_rst='1' then
            current_state <= IDLE;
            -- Reset dei segnali
            coefficient_counter <= 0;
            addr_counter <= (others => '0');
            byte_counter <= (others => '0');
            K <= (others => '0');
            S <= '0';
            C0 <= (others => '0');
            C1 <= (others => '0');
            C2 <= (others => '0');
            C3 <= (others => '0');
            C4 <= (others => '0');
            C5 <= (others => '0');
            C6 <= (others => '0');
            data_sequence <= (others => (others => '0'));
            filter_result <= (others => '0');
        elsif rising_edge(i_clk) then
            current_state <= next_state;

            coefficient_counter <= next_coefficient_counter; 
            addr_counter <= next_addr_counter; 
            byte_counter <= next_byte_counter;
            K <= next_K;
            S <= next_S;
            C0 <= next_C0;
            C1 <= next_C1;
            C2 <= next_C2;
            C3 <= next_C3;
            C4 <= next_C4;
            C5 <= next_C5;
            C6 <= next_C6;
            filter_result <= next_filter_result;
            case current_state is
                when READ_DATA =>
                    if byte_counter <= 3 then
                        case to_integer(byte_counter) is
                            when 1 => 
                                data_sequence(4) <= signed(i_mem_data); --posiziono il primo byte in posizione 4, perché poi shiftando lo metto in posizione 3
                            when 2 => data_sequence(5) <= signed(i_mem_data);
                            when 3 => data_sequence(6) <= signed(i_mem_data);
                            when others => null;
                        end case;
                    elsif byte_counter <= unsigned(K) then
                        -- Shift della sequenza e nuovo dato
                        data_sequence(0) <= data_sequence(1);
                        data_sequence(1) <= data_sequence(2);
                        data_sequence(2) <= data_sequence(3);
                        data_sequence(3) <= data_sequence(4);
                        data_sequence(4) <= data_sequence(5);
                        data_sequence(5) <= data_sequence(6);
                        data_sequence(6) <= signed(i_mem_data);
                    elsif byte_counter > unsigned(K) then
                        data_sequence(0) <= data_sequence(1);
                        data_sequence(1) <= data_sequence(2);
                        data_sequence(2) <= data_sequence(3);
                        data_sequence(3) <= data_sequence(4);
                        data_sequence(4) <= data_sequence(5);
                        data_sequence(5) <= data_sequence(6);
                        data_sequence(6) <= (others => '0'); --quando ho finito di leggere il byte di dati, pongo a zero gli ultimi byte del data_sequence
                    end if;
                when READ_C_HEADER =>
                    if coefficient_counter = 6 then
                        -- Preparo la sequenza per il primo dato (che arriverà nel prossimo ciclo)
                        data_sequence(0) <= (others => '0');
                        data_sequence(1) <= (others => '0');
                        data_sequence(2) <= (others => '0');
                        data_sequence(3) <= (others => '0');
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process state_reg;
            
    -- Processo per la logica di stato prossimo e output
    next_state_and_output_logic: process (current_state, i_start, addr_counter, i_mem_data, i_add, 
                                 coefficient_counter, byte_counter, data_sequence, filter_result,
                                 K, S, C0, C1, C2, C3, C4, C5, C6)
    variable result: signed(17 downto 0);
    variable result_address: unsigned(15 downto 0);
    variable shift1, shift2, shift3, shift4: signed(17 downto 0);
    
    begin
        -- Valori di default per i segnali next_
        next_state<=current_state;
        next_coefficient_counter <= coefficient_counter;
        next_addr_counter <= addr_counter;
        next_byte_counter <= byte_counter;
        next_K <= K;
        next_S <= S;
        next_C0 <= C0;
        next_C1 <= C1;
        next_C2 <= C2;
        next_C3 <= C3;
        next_C4 <= C4;
        next_C5 <= C5;
        next_C6 <= C6;
        next_filter_result <= filter_result;
        
        o_mem_en <= '0'; -- posto a '0' per disabilitare la memoria di default
        o_mem_we <= '0'; -- posto a '0' per disabilitare la scrittura di default
        o_mem_addr <= (others => '0'); -- indirizzo di memoria di default
        o_mem_data <= (others => '0'); -- dati di memoria di default

        case current_state is 
            when IDLE =>
                if i_start = '1' then
                    next_state <= READ_K_MSB;
                    next_addr_counter <= unsigned(i_add); -- setto l'indirizzo iniziale
                    next_coefficient_counter <= 0; -- resetto il coefficient counter
                    o_mem_en <= '1';                     
                    o_mem_addr <= i_add; 
                    
                else
                    next_state <= IDLE;
                    next_addr_counter <= (others => '0'); 
                    next_byte_counter <= (others => '0');
                    next_coefficient_counter <= 0; 
                end if;

            when READ_K_MSB =>
                next_state <= READ_K_LSB;
                next_K(15 downto 8) <= i_mem_data; 
                o_mem_en <= '1'; 
                next_addr_counter <= addr_counter +to_unsigned(1, 16); 
                o_mem_addr <= std_logic_vector(addr_counter +to_unsigned(1, 16)); 
                                
            when READ_K_LSB =>
                next_state <= READ_S_HEADER;
                next_K(7 downto 0) <= i_mem_data; 
                o_mem_en <= '1'; 
                next_addr_counter <= addr_counter +to_unsigned(1, 16); 
                o_mem_addr <= std_logic_vector(addr_counter +to_unsigned(1, 16)); 
                       
            when READ_S_HEADER =>
                next_state <= READ_C_HEADER;
                next_S <= i_mem_data(0); -- salvo il bit finale di S
                o_mem_en <= '1'; 
                if (i_mem_data(0)='1') then 
                    next_addr_counter <=addr_counter+8;
                    o_mem_addr <= std_logic_vector(addr_counter+to_unsigned(8, 16)); 
                else
                    next_addr_counter <= addr_counter +to_unsigned(1, 16);
                    o_mem_addr <= std_logic_vector(addr_counter +to_unsigned(1, 16)); 
                end if;
                
            when READ_C_HEADER =>
                --carico i coefficienti in base al contatore
                case coefficient_counter is
                    when 0 =>
                        next_C0 <= signed(i_mem_data);
                    when 1 =>
                        next_C1 <= signed(i_mem_data);
                    when 2 =>
                        next_C2 <= signed(i_mem_data);
                    when 3 =>
                        next_C3 <= signed(i_mem_data);
                    when 4 =>
                        next_C4 <= signed(i_mem_data);
                    when 5 =>
                        next_C5 <= signed(i_mem_data);
                    when 6 =>
                        next_C6 <= signed(i_mem_data);
                    when others =>
                        null; -- non dovrebbe mai succedere, ma è buona norma gestire il caso
                end case;
                --lettura del byte successivo
                o_mem_en <= '1'; 
                if (coefficient_counter = 6) then
                    next_state <= READ_DATA; -- se ho letto tutti i coefficienti, passo alla lettura del primo byte di dati
                    next_addr_counter <= unsigned(i_add)+to_unsigned(17, 16); 
                    o_mem_addr <= std_logic_vector(unsigned(i_add)+to_unsigned(17, 16)); 
                    next_byte_counter <= byte_counter + to_unsigned(1, 16); 
                else
                    next_state <= READ_C_HEADER; -- resto in READ_C_HEADER finché non leggo tutti i coefficienti
                    next_addr_counter <= addr_counter +to_unsigned(1, 16);
                    next_coefficient_counter <= coefficient_counter + 1; 
                    o_mem_addr <= std_logic_vector(addr_counter +to_unsigned(1, 16)); 
                end if;
            
            when READ_DATA =>
                if (byte_counter<=3) then --condizione per gestire i primi byte
                    next_addr_counter <= addr_counter +to_unsigned(1, 16); 
                    next_byte_counter <= byte_counter + to_unsigned(1, 16); 
                    o_mem_en <= '1'; 
                    o_mem_addr <= std_logic_vector(addr_counter +to_unsigned(1, 16)); 
                    next_state <= READ_DATA; 

                elsif byte_counter>unsigned(K) then --condizione per gestire gli ultimi byte
                    if (byte_counter <= unsigned(K)+to_unsigned(3, 16)) then
                        next_state <= ELABORATION_DATA; 
                    else
                        next_state <= DONE; --dopo che ho elaborato tutti i dati, vado in DONE
                    end if;
                elsif byte_counter<=unsigned(K) then
                    next_state <= ELABORATION_DATA; 
                end if;

            when ELABORATION_DATA =>
                if S = '1' then
                    next_filter_result <= resize(data_sequence(0)*C0, 18) + 
                    resize(data_sequence(1)*C1, 18) + 
                    resize(data_sequence(2)*C2, 18) + 
                    resize(data_sequence(3)*C3, 18) + 
                    resize(data_sequence(4)*C4, 18) + 
                    resize(data_sequence(5)*C5, 18) + 
                    resize(data_sequence(6)*C6, 18);     
                else
                    next_filter_result <= resize(data_sequence(1)*C1, 18) + 
                    resize(data_sequence(2)*C2, 18) + 
                    resize(data_sequence(3)*C3, 18) + 
                    resize(data_sequence(4)*C4, 18) + 
                    resize(data_sequence(5)*C5, 18);
                end if;
                next_state <= WRITE_DATA;
            
            when WRITE_DATA =>
                -- prima di scrivere il dato in memoria, normalizzo il risultato
                result := filter_result;
                if S='0' then 
                    shift1:= shift_right(result, 4);
                    shift2:= shift_right(result, 6);
                    shift3:= shift_right(result, 8);
                    shift4:= shift_right(result, 10);
                    if (result<0) then
                        shift1:= shift1 + to_signed(1, 18);
                        shift2:= shift2 + to_signed(1, 18);
                        shift3:= shift3 + to_signed(1, 18);
                        shift4:= shift4 + to_signed(1, 18);
                    end if;
                    result:= shift1 + shift2 + shift3 + shift4;
                else 
                    shift1:= shift_right(result, 6);
                    shift2:= shift_right(result, 10);
                    if (result<0) then
                        shift1:= shift1 + to_signed(1, 18);
                        shift2:= shift2 + to_signed(1, 18);
                    end if;
                    result:= shift1 + shift2;
                end if;
                if (result<to_signed(-128, 18)) then
                    result:= to_signed(-128, 18); -- saturo il risultato a -128
                elsif (result> to_signed(127, 18)) then
                    result:= to_signed(127, 18); -- saturo il risultato a 127
                end if;
                -- scrivo il risultato in memoria
                o_mem_en <= '1'; 
                o_mem_we <= '1'; 
                result_address := unsigned(i_add)+to_unsigned(17, 16)+unsigned(K)+byte_counter-to_unsigned(4, 16); 
                o_mem_addr <=std_logic_vector(result_address); 
                o_mem_data <= std_logic_vector(result(7 downto 0)); 
                next_state <= WAIT_FOR_READ_DATA; --aspetto di leggere il dato successivo, per evitare di leggere il dato che ho appena scritto

            when WAIT_FOR_READ_DATA =>
                if byte_counter<=unsigned(K) then
                    next_addr_counter <= addr_counter +to_unsigned(1, 16); 
                    o_mem_en <= '1'; 
                    o_mem_addr <= std_logic_vector(addr_counter +to_unsigned(1, 16)); 
                    next_byte_counter <= byte_counter + to_unsigned(1, 16);
                elsif byte_counter>unsigned(K) then
                    next_byte_counter <= byte_counter + to_unsigned(1, 16);
                end if;
                next_state <= READ_DATA; --torno a leggere i dati

            when DONE =>
                if i_start = '0' then
                    next_state <= IDLE;
                else
                    next_state <= DONE; --se i_start è ancora '1', resta in DONE
                end if;
        end case;
    end process next_state_and_output_logic;

    --per rimuovere il warning di latch su o_done
    o_done_logic: process (i_clk, i_rst)
    begin
        if i_rst = '1' then
            o_done <= '0';
        elsif rising_edge(i_clk) then
            if current_state = DONE then
                o_done <= '1';
            else
                o_done <= '0';
            end if;
        end if;
    end process o_done_logic;

end behavioral;