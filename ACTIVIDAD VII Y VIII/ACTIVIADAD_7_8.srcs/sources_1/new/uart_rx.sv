`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: uart_rx (Receptor Asincrono Universal)
// Descripcion: Recibe 1 byte de datos (8-N-1) en serie.
//              Implementado con una FSM estandar de 2 procesos.
// CORRECCION: Se reemplazo el literal ambiguo '0' por '{0} 
//             para asignaciones de vectores.
//////////////////////////////////////////////////////////////////////////////////

module uart_rx #(
    // Parametros calculados para 100MHz clk y 9600 baud rate
    parameter CLKS_PER_BIT = 10417,
    parameter HALF_BIT     = 5208,
    parameter CNT_WIDTH    = 14  // 2^14 = 16384, suficiente para 10417
) (
    input logic clk,         // Reloj (100MHz)
    input logic reset,       // Reset
    input logic RxD,         // Pin de recepcion (desde la PC)
    
    output logic [7:0] rx_data,     // El byte de datos recibido
    output logic       rdrf,        // "Received Data Ready Flag"
    output logic       FE,          // "Framing Error"
    input logic        rdrf_clr     // Senal para limpiar la bandera 'rdrf'
);

    // FSM de acuerdo a los apuntes
    typedef enum logic [2:0] {
        MARK,   // Estado 'Idle', linea en '1'
        START,  // Detecto bit de inicio, esperando medio bit
        DELAY,  // Esperando un tiempo de bit completo
        SHIFT,  // Muestreando y desplazando el bit
        STOP    // Verificando el bit de paro
    } state_t;

    // --- Senales Internas ---
    // Usamos el sufijo _reg para "valor actual" y _next para "proximo valor"
    state_t state_reg, state_next;
    
    logic [CNT_WIDTH-1:0] baud_count_reg, baud_count_next;
    logic [3:0]           bit_count_reg, bit_count_next;
    logic [7:0]           rxbuff_reg, rxbuff_next;
    
    logic rdrf_reg, rdrf_next;
    logic fe_reg, fe_next;

    // --- 1. Proceso Secuencial (Bloque de Registros) ---
    // Este bloque solo actualiza los registros en el flanco de reloj.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reiniciar todo
            state_reg      <= MARK;
            baud_count_reg <= '0; // <-- CORREGIDO
            bit_count_reg  <= '0; // <-- CORREGIDO
            rxbuff_reg     <= '0; // <-- CORREGIDO
            rdrf_reg       <= 1'b0;
            fe_reg         <= 1'b0;
        end else begin
            // Actualizar todos los registros con su "proximo" valor
            state_reg      <= state_next;
            baud_count_reg <= baud_count_next;
            bit_count_reg  <= bit_count_next;
            rxbuff_reg     <= rxbuff_next;
            rdrf_reg       <= rdrf_next;
            fe_reg         <= fe_next;
        end
    end

    // --- 2. Proceso Combinacional (Logica de Proximo Estado) ---
    // Este bloque calcula TODOS los "proximos" valores basados
    // en los valores "actuales" (_reg) y las entradas.
    always_comb begin
        // Valores por defecto: mantener todo igual
        state_next      = state_reg;
        baud_count_next = baud_count_reg;
        bit_count_next  = bit_count_reg;
        rxbuff_next     = rxbuff_reg;
        rdrf_next       = rdrf_reg;
        fe_next         = fe_reg;

        // Limpiar la bandera 'rdrf' (tiene prioridad)
        if (rdrf_clr) begin
            rdrf_next = 1'b0;
        end

        // Logica de la FSM
        case (state_reg)
            MARK: begin
                bit_count_next = '0; // <-- CORREGIDO (Reiniciar contador de bits)
                fe_next = 1'b0;       // Limpiar error de frame
                
                if (~RxD) begin // Si detecta bit de inicio (bajada)
                    state_next = START;
                    baud_count_next = '0; // <-- CORREGIDO (Reiniciar contador de baud)
                end
            end
            
            START: begin
                // Esperar medio bit
                baud_count_next = baud_count_reg + 1;
                if (baud_count_reg == HALF_BIT) begin
                    if (~RxD) // Confirmar que sigue bajo
                        state_next = DELAY;
                    else // Falso inicio (glitch)
                        state_next = MARK;
                end
            end
            
            DELAY: begin
                // Esperar un tiempo de bit completo
                baud_count_next = baud_count_reg + 1;
                if (baud_count_reg == CLKS_PER_BIT) begin
                    state_next = SHIFT;
                    // Muestrear y desplazar el bit
                    // El LSB (primer bit) entra por la izquierda (MSB) y se desplaza a la derecha
                    rxbuff_next = {RxD, rxbuff_reg[7:1]}; 
                    bit_count_next = bit_count_reg + 1;
                    baud_count_next = '0; // <-- CORREGIDO (Reiniciar contador de baud)
                end
            end
            
            SHIFT: begin
                // Estado de transicion (dura 1 ciclo)
                if (bit_count_reg == 8) // Ya recibimos los 8 bits
                    state_next = STOP;
                else
                    state_next = DELAY; // Volver a esperar por el siguiente bit
            end
            
            STOP: begin
                // Esperar un tiempo de bit completo para el bit de paro
                baud_count_next = baud_count_reg + 1;
                if (baud_count_reg == CLKS_PER_BIT) begin
                    state_next = MARK;
                    rdrf_next = 1'b1;     // Levantar bandera "listo"
                    fe_next   = ~RxD;     // Comprobar bit de paro (debe ser '1')
                end
            end
            
            default: begin
                state_next = MARK;
            end
        endcase
    end
    
    // --- 3. Asignacion de Salidas ---
    // Las salidas son el valor "actual" de los registros
    assign rx_data = rxbuff_reg;
    assign rdrf    = rdrf_reg;
    assign FE      = fe_reg;

endmodule