# ==============================================================
# SDC - img2row
# Ferramenta: Synopsys DC / Cadence Genus
# Frequência:  100 MHz  →  período = 10 ns
# ==============================================================

# --------------------------------------------------------------
# 1. Clock
# --------------------------------------------------------------
create_clock -name clk -period 10.0 [get_ports clk]

# Incerteza de clock (jitter + skew estimados)
set_clock_uncertainty -setup 0.2 [get_clocks clk]
set_clock_uncertainty -hold  0.1 [get_clocks clk]

# Latência estimada do clock tree (ajuste após CTS)
set_clock_latency -source 0.5 [get_clocks clk]

# --------------------------------------------------------------
# 2. Reset (síncrono ativo em baixo)
# --------------------------------------------------------------
set_input_delay  -clock clk -max 1.5 [get_ports rst_n_sync]
set_input_delay  -clock clk -min 0.5 [get_ports rst_n_sync]

# --------------------------------------------------------------
# 3. Entradas de controle
# --------------------------------------------------------------
set_input_delay  -clock clk -max 1.5 [get_ports valid_i]
set_input_delay  -clock clk -max 1.5 [get_ports rready_i]
set_input_delay  -clock clk -max 1.5 [get_ports ena_mc]

set_input_delay  -clock clk -min 0.5 [get_ports valid_i]
set_input_delay  -clock clk -min 0.5 [get_ports rready_i]
set_input_delay  -clock clk -min 0.5 [get_ports ena_mc]

# --------------------------------------------------------------
# 4. Entrada: img [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0] (WIDTH bits)
#    Para SIZE_WINDOW=6, WIDTH=4 → 144 bits
# --------------------------------------------------------------
set_input_delay  -clock clk -max 1.5 [get_ports {img[*][*]}]
set_input_delay  -clock clk -min 0.5 [get_ports {img[*][*]}]

# --------------------------------------------------------------
# 5. Saídas
# --------------------------------------------------------------
set_output_delay -clock clk -max 1.5 [get_ports ready_o]
set_output_delay -clock clk -max 1.5 [get_ports rvalid_o]
set_output_delay -clock clk -max 1.5 [get_ports {colout[*][*]}]

set_output_delay -clock clk -min 0.5 [get_ports ready_o]
set_output_delay -clock clk -min 0.5 [get_ports rvalid_o]
set_output_delay -clock clk -min 0.5 [get_ports {colout[*][*]}]

# --------------------------------------------------------------
# 6. Driving cell / Load (ajuste para a sua stdcell library)
# --------------------------------------------------------------
set_driving_cell -lib_cell BUFX4 -pin Y [all_inputs]
set_load 0.05 [all_outputs]

# --------------------------------------------------------------
# 7. Área / potência (opcional)
# --------------------------------------------------------------
# set_max_area 0