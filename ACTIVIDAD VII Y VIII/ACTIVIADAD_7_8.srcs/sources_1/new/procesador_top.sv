`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: procesador_top
// Descripcion: Modulo superior (Top) del proyecto.
//              Instancia todos los sub-modulos y los conecta a los
//              pines de la tarjeta Basys 3.
//////////////////////////////////////////////////////////////////////////////////

module procesador_top (
    // --- Pines Globales ---
    input logic clk,         // Reloj de 100MHz (Pin W5)
    input logic btnC,        // Boton de Reset (Pin U18)
    
    // --- Pines UART ---
    input logic uart_rxd,    // Recepcion (Pin B18)
    output logic uart_txd,   // Transmision (Pin A18)
    
    // --- Pines Opcionales (Switches y LEDs) ---
    input logic [15:0] sw,
    output logic [15:0] led
);

    // Ancho de datos para el procesador FSMD
    parameter WIDTH = 32;

    // --- Senal de Reset Global ---
    // Usamos el debouncer para limpiar la senal del boton de reset
    logic reset_global;
    
    debouncing i_reset_debouncer (
        .clk(clk),
        .reset(1'b0),     // El debouncer de reset no se resetea
        .sw_inp(btnC),    // Entrada ruidosa del boton
        .debounced_out(reset_global) // Salida limpia
    );


    // --- Senales de interconexion (cables internos) ---

    // Cables: Main Controller <-> UART RX
    logic [7:0] rx_data;
    logic       rx_rdrf;
    logic       rx_rdrf_clr;
    logic       rx_fe;
    
    // Cables: Main Controller <-> UART TX
    logic [7:0] tx_data;
    logic       tx_ready;
    logic       tx_tdre;
    
    // Cables: Main Controller <-> Procesador FSMD
    logic       fsmd_start;
    logic       fsmd_algo_select;
    logic [WIDTH-1:0] fsmd_n_in;
    logic       fsmd_done;
    logic [WIDTH-1:0] fsmd_result_out;
    
    // Cables: Control Unit <-> Datapath
    logic       load_a_en, load_b_en, load_c_en, load_n_en;
    logic [1:0] mux_a_sel, mux_b_sel, mux_c_sel, mux_n_sel;
    logic [1:0] alu_op_sel;
    logic       dp_n_is_zero, dp_n_msb_is_one;
    logic       dp_n_is_gt_2;
    
    
    // --- 1. Instanciacion del Receptor UART ---
    uart_rx i_uart_rx (
        .clk(clk),
        .reset(reset_global),
        .RxD(uart_rxd),
        .rx_data(rx_data),
        .rdrf(rx_rdrf),
        .FE(rx_fe),
        .rdrf_clr(rx_rdrf_clr)
    );
    
    // --- 2. Instanciacion del Transmisor UART ---
    uart_tx i_uart_tx (
        .clk(clk),
        .reset(reset_global),
        .tx_data(tx_data),
        .ready(tx_ready),
        .TxD(uart_txd),
        .tdre(tx_tdre)
    );
    
    // --- 3. Instanciacion del "Cerebro Maestro" ---
    main_controller_fsm #(
        .WIDTH(WIDTH)
    ) i_main_controller (
        .clk(clk),
        .reset(reset_global),
        // UART RX
        .rx_data_in(rx_data),
        .rx_rdrf(rx_rdrf),
        .rx_rdrf_clr(rx_rdrf_clr),
        // UART TX
        .tx_data_out(tx_data),
        .tx_ready(tx_ready),
        .tx_tdre(tx_tdre),
        // FSMD
        .fsmd_start(fsmd_start),
        .fsmd_algo_select(fsmd_algo_select),
        .fsmd_n_in(fsmd_n_in),
        .fsmd_done(fsmd_done),
        .fsmd_result_out(fsmd_result_out)
    );
    
    // --- 4. Instanciacion del Cerebro del FSMD (Control Unit) ---
    control_unit_fsmd #(
        .WIDTH(WIDTH)
    ) i_fsmd_control (
        .clk(clk),
        .reset(reset_global),
        // Interfaz con Main Controller
        .start_calc(fsmd_start),
        .algo_select(fsmd_algo_select),
        .n_in(fsmd_n_in),
        .done(fsmd_done),
        // Interfaz con Datapath (Flags)
        .n_is_zero(dp_n_is_zero),
        .n_msb_is_one(dp_n_msb_is_one),
        .n_is_gt_2(dp_n_is_gt_2),
        // Interfaz con Datapath (Control)
        .load_a_en(load_a_en),
        .load_b_en(load_b_en),
        .load_c_en(load_c_en),
        .load_n_en(load_n_en),
        .mux_a_sel(mux_a_sel),
        .mux_b_sel(mux_b_sel),
        .mux_c_sel(mux_c_sel),
        .mux_n_sel(mux_n_sel),
        .alu_op_sel(alu_op_sel)
    );
    
    // --- 5. Instanciacion del Musculo del FSMD (Datapath) ---
    datapath #(
        .WIDTH(WIDTH)
    ) i_datapath (
        .clk(clk),
        .reset(reset_global),
        // Interfaz con Control Unit
        .load_a_en(load_a_en),
        .load_b_en(load_b_en),
        .load_c_en(load_c_en),
        .load_n_en(load_n_en),
        .mux_a_sel(mux_a_sel),
        .mux_b_sel(mux_b_sel),
        .mux_c_sel(mux_c_sel),
        .mux_n_sel(mux_n_sel),
        .alu_op_sel(alu_op_sel),
        // Interfaz con Main Controller
        .n_in(fsmd_n_in),
        .result_out(fsmd_result_out),
        // Flags
        .n_is_zero(dp_n_is_zero),
        .n_msb_is_one(dp_n_msb_is_one),
        .n_is_gt_2(dp_n_is_gt_2)
    );
    
    // --- 6. Asignacion de LEDs Opcionales ---
    // (Puedes modificar esto como prefieras)
    assign led[15] = rx_rdrf; // LED se enciende cuando llega un byte
    assign led[14] = ~tx_tdre; // LED se enciende cuando TX esta ocupado
    assign led[13] = ~fsmd_done & fsmd_start; // LED se enciende durante el calculo
    assign led[12] = rx_fe;   // LED de Error de Framing
    assign led[7:0] = rx_data; // Muestra el ultimo byte recibido
    
endmodule
