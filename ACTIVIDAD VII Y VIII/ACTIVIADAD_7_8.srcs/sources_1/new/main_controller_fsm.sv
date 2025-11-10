`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: main_controller_fsm
// Descripcion: El "Cerebro Maestro" del sistema.
//              Controla la comunicacion UART y la ejecucion del procesador FSMD.
//              Implementa la secuencia de 5 pasos del proyecto.
//////////////////////////////////////////////////////////////////////////////////

module main_controller_fsm #(
    parameter WIDTH = 32 // Ancho de datos del procesador
) (
    input logic clk,
    input logic reset,

    // --- Interfaz con UART RX ---
    input  logic [7:0] rx_data_in, // Dato recibido
    input  logic       rx_rdrf,    // Flag de "dato listo"
    output logic       rx_rdrf_clr,// Limpiar el flag

    // --- Interfaz con UART TX ---
    output logic [7:0] tx_data_out, // Dato a enviar
    output logic       tx_ready,    // "Go" para transmitir
    input  logic       tx_tdre,     // Flag de "listo para enviar"

    // --- Interfaz con el Procesador FSMD ---
    output logic       fsmd_start,      // "Go" para calcular
    output logic       fsmd_algo_select, // 0=Padovan, 1=Moser
    output logic [WIDTH-1:0] fsmd_n_in, // Valor de 'n' a calcular
    input  logic       fsmd_done,       // Flag de "calculo terminado"
    input  logic [WIDTH-1:0] fsmd_result_out // Resultado del calculo
);

    // --- Definicion de Estados de la FSM ---
    // Protocolo:
    // 1. Esperar 1 byte de Algoritmo ('P' o 'M')
    // 2. Esperar 1 byte de N (0-255)
    // 3. Enviar 4 bytes de Resultado
    typedef enum logic [3:0] {
        S_IDLE,         // Opcional: Enviar mensaje de bienvenida
        S_WAIT_ALGO,    // 1. Esperando byte de algoritmo
        S_ECHO_ALGO,    // 1b. Haciendo eco del algoritmo
        S_WAIT_N,       // 2. Esperando byte de 'n'
        S_ECHO_N,       // 2b. Haciendo eco de 'n'
        S_START_CALC,   // 3. Dando "Go" al procesador
        S_WAIT_CALC,    // 3b. Esperando a que termine el procesador
        S_SEND_R3,      // 4. Enviando Byte 3 del resultado (MSB)
        S_SEND_R2,      // 4. Enviando Byte 2
        S_SEND_R1,      // 4. Enviando Byte 1
        S_SEND_R0       // 4. Enviando Byte 0 (LSB) y volviendo a IDLE
    } state_t;

    // --- Senales Internas ---
    state_t state_reg, state_next;
    
    // Registros para almacenar los datos de la FSM
    logic [7:0]           reg_algo_choice;
    logic [WIDTH-1:0]     reg_n;
    logic [WIDTH-1:0] reg_result;
    
    // --- 1. Proceso Secuencial (Bloque de Registros) ---
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= S_IDLE;
            reg_algo_choice <= '0;
            reg_n           <= '0;
            reg_result      <= '0;
        end else begin
            state_reg <= state_next;
            
            // Logica de carga para los registros internos
            if (state_next == S_ECHO_ALGO)
                reg_algo_choice <= rx_data_in;
                
            if (state_next == S_ECHO_N)
                reg_n <= {24'b0, rx_data_in}; // Asumir 'n' de 8 bits
                
            if (state_next == S_SEND_R3)
                reg_result <= fsmd_result_out; // Capturar resultado
        end
    end

    // --- 2. Proceso Combinacional (Logica de Proximo Estado y Salidas) ---
    always_comb begin
        // Valores por defecto: No hacer nada
        state_next      = state_reg;
        rx_rdrf_clr     = 1'b0;
        tx_data_out     = '0;
        tx_ready        = 1'b0;
        fsmd_start      = 1'b0;
        fsmd_algo_select = 1'b0; // Default a Padovan
        fsmd_n_in       = reg_n; // Siempre pasar el 'n' almacenado

        // Logica de la FSM
        case (state_reg)
            S_IDLE: begin
                // (Opcional: se podria enviar un mensaje de bienvenida)
                // Punto 1: Ir a esperar datos
                state_next = S_WAIT_ALGO;
            end
            
            S_WAIT_ALGO: begin
                // Esperar a que llegue un byte del RX
                if (rx_rdrf) begin
                    rx_rdrf_clr = 1'b1; // Limpiar el flag de RX
                    state_next  = S_ECHO_ALGO;
                end
            end
            
            S_ECHO_ALGO: begin
                // Punto 3: Hacer eco. Esperar a que el TX este libre
                if (tx_tdre) begin
                    tx_ready    = 1'b1;
                    tx_data_out = reg_algo_choice;
                    state_next  = S_WAIT_N;
                end
            end
            
            S_WAIT_N: begin
                // Esperar a que llegue el byte de 'n'
                if (rx_rdrf) begin
                    rx_rdrf_clr = 1'b1;
                    state_next  = S_ECHO_N;
                end
            end
            
            S_ECHO_N: begin
                // Punto 3: Hacer eco de 'n'
                if (tx_tdre) begin
                    tx_ready    = 1'b1;
                    tx_data_out = reg_n[7:0]; // Enviar solo el byte LSB
                    state_next  = S_START_CALC;
                end
            end
            
            S_START_CALC: begin
                // Punto 4: Iniciar el calculo
                fsmd_start = 1'b1;
                // Asignar el algoritmo basado en el byte recibido
                if (reg_algo_choice == 8'h4D) // 'M' de Moser
                    fsmd_algo_select = 1'b1;
                else // Default a Padovan
                    fsmd_algo_select = 1'b0;
                    
                state_next = S_WAIT_CALC;
            end
            
            S_WAIT_CALC: begin
                // Esperar a que el FSMD termine
                if (fsmd_done) begin
                    state_next = S_SEND_R3;
                end
            end
            
            // --- Envio de Resultado (4 bytes) ---
            S_SEND_R3: begin // Byte 3 (MSB)
                if (tx_tdre) begin
                    tx_ready    = 1'b1;
                    tx_data_out = reg_result[31:24];
                    state_next  = S_SEND_R2;
                end
            end
            
            S_SEND_R2: begin // Byte 2
                if (tx_tdre) begin
                    tx_ready    = 1'b1;
                    tx_data_out = reg_result[23:16];
                    state_next  = S_SEND_R1;
                end
            end

            S_SEND_R1: begin // Byte 1
                if (tx_tdre) begin
                    tx_ready    = 1'b1;
                    tx_data_out = reg_result[15:8];
                    state_next  = S_SEND_R0;
                end
            end

            S_SEND_R0: begin // Byte 0 (LSB)
                if (tx_tdre) begin
                    tx_ready    = 1'b1;
                    tx_data_out = reg_result[7:0];
                    state_next  = S_IDLE; // Punto 5: Volver al inicio
                end
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

endmodule