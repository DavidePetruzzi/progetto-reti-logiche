# Progetto di Reti Logiche — Prova Finale
**Politecnico di Milano** · Anno Accademico 2024/2025  
Autore: Davide Petruzzi

Voto: 30L/30

---

## Descrizione

Implementazione in VHDL di un modulo hardware che applica un **filtro differenziale** a una sequenza di K valori interi (compresi tra -128 e +127, in complemento a 2), letti da una memoria RAM. Il risultato filtrato viene riscritto in memoria a partire dall'indirizzo `ADD + 17 + K`.

Il modulo supporta due filtri selezionabili tramite il byte `S` in memoria:

| Filtro | Ordine | Coefficienti | Normalizzazione |
|--------|--------|--------------|-----------------|
| Ordine 3 | `l = 2` | `[0, −1, 8, 0, −8, 1, 0]` | `n = 12` (≈ 1/16 + 1/64 + 1/256 + 1/1024) |
| Ordine 5 | `l = 3` | `[1, −9, 45, 0, −45, 9, −1]` | `n = 60` (≈ 1/64 + 1/1024) |

I valori fuori dall'intervallo [-128, 127] vengono **saturati** al limite corrispondente.

---

## Struttura della memoria

```
ADD      →  K1 (MSB lunghezza sequenza)
ADD+1    →  K2 (LSB lunghezza sequenza)
ADD+2    →  S  (bit LSB: 0 = ordine 3, 1 = ordine 5)
ADD+3    →  C0 ... C6  (coefficienti filtro ordine 3)
ADD+10   →  C0 ... C6  (coefficienti filtro ordine 5)
ADD+17   →  W1 ... WK  (sequenza di input)
ADD+17+K →  R1 ... RK  (risultati scritti dal modulo)
```

---

## Interfaccia del componente

```vhdl
entity project_reti_logiche is
  port (
    i_clk      : in  std_logic;
    i_rst      : in  std_logic;
    i_start    : in  std_logic;
    i_add      : in  std_logic_vector(15 downto 0);
    o_done     : out std_logic;
    o_mem_addr : out std_logic_vector(15 downto 0);
    i_mem_data : in  std_logic_vector(7 downto 0);
    o_mem_data : out std_logic_vector(7 downto 0);
    o_mem_we   : out std_logic;
    o_mem_en   : out std_logic
  );
end project_reti_logiche;
```

---

## Architettura

Il modulo è implementato come una **macchina a stati finiti (FSM)** con 10 stati, organizzata in tre processi VHDL:

- `state_reg` — sincrono, gestisce le transizioni di stato e l'aggiornamento dei registri interni
- `next_state_and_output_logic` — combinatorio, calcola lo stato prossimo e i segnali verso la memoria
- `o_done_logic` — sincrono, gestisce il segnale di uscita `o_done`

**Stati della FSM:**

```
IDLE → READ_K_MSB → READ_K_LSB → READ_S_HEADER → READ_C_HEADER
     ↓
READ_DATA ↔ ELABORATION_DATA → WRITE_DATA → WAIT_FOR_READ_DATA
     ↓
   DONE → (torna a IDLE quando i_start = 0)
```

---

## Risultati di sintesi

Target FPGA: **Artix-7 xc7a100tcsg324-3** · Tool: **Vivado 2016.1**

| Metrica | Valore |
|---------|--------|
| LUT utilizzate | 841 (1.33%) |
| Flip Flop | 183 (0.14%) |
| Latch | 0 |
| Worst Negative Slack (WNS) | 11.138 ns |
| Periodo di clock | 20 ns |
| Percorso critico | 8.862 ns |

---

## Come simulare in Vivado

1. Aprire **Vivado** e creare un nuovo progetto (RTL Project).
2. Aggiungere il file sorgente `<codice_persona>.vhd` come design source.
3. Aggiungere il testbench fornito dal docente (`tb2425.vhd`) come simulation source.
4. Selezionare il target FPGA (es. `xc7a100tcsg324-3`) oppure lasciare il default per simulazione.
5. Avviare la **Behavioral Simulation**:
   - `Flow Navigator → Simulation → Run Simulation → Run Behavioral Simulation`
6. Nella console Tcl, eseguire:
   ```tcl
   run all
   ```
7. Verificare nella waveform che il segnale `o_done` si alzi correttamente al termine dell'elaborazione e che i valori scritti in memoria corrispondano ai risultati attesi.

Per la simulazione **post-sintesi funzionale**:
1. Eseguire prima la sintesi: `Flow Navigator → Synthesis → Run Synthesis`
2. Poi: `Flow Navigator → Simulation → Run Simulation → Run Post-Synthesis Functional Simulation`

> **Nota:** nella simulazione post-sintesi i segnali interni come `current_state` vengono rappresentati in binario. Il completamento corretto si verifica analizzando la waveform.
> Nel repo è incluso solo il testbench ufficiale fornito dal docente (`tb2425.vhd`). Durante lo sviluppo sono stati utilizzati anche testbench aggiuntivi

---

## Note

- Il modulo è progettato per funzionare con un periodo di clock di almeno **20 ns**.
- Prima del primo `START=1` viene sempre fornito un segnale di `RESET`.
- Una seconda elaborazione può essere avviata senza reset, non appena `DONE` torna a 0.
- Il progetto è stato sviluppato individualmente come Prova Finale del corso di Reti Logiche (Prof. Fornaciari, Prof. Palermo, Prof. Salice).
