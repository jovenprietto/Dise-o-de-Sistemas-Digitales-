`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: uart_tx (Transmisor Asincrono Universal)
// Descripcion: Transmite 1 byte de datos (8-N-1) en serie.
//              - 8 bits de datos
//              - Sin paridad
//              - 1 bit de paro
//              Implementado con una FSM estandar de 2 procesos.
//////////////////////////////////////////////////////////////////////////////////

module uart_tx #(
    // Parametros calculados para 100MHz clk y 9600 baud rate
    parameter CLKS_PER_BIT = 10417,
    parameter CNT_WIDTH    = 14  // 2^14 = 16384, suficiente para 10417
) (
    input logic clk,       // Reloj (100MHz)
    input logic reset,     // Reset
    
    input logic [7:0] tx_data,   // El byte a transmitir
    input logic       ready,     // Senal "Go" para iniciar transmision
    
    output logic TxD,      // Pin de transmision (hacia la PC)
    output logic tdre      // "Transmit Data Ready" (1 = Listo para mas datos)
);

    // FSM de acuerdo a los apuntes
    typedef enum logic [2:0] {
        MARK,   // Estado 'Idle', linea en '1'. tdre = 1
        START,  // Enviando bit de inicio ('0')
        DELAY,  // Sosteniendo el bit actual por CLKS_PER_BIT
        STOP    // Enviando bit de paro ('1')
    } state_t;

    // --- Senales Internas ---
    state_t state_reg, state_next;
    
    logic [CNT_WIDTH-1:0] baud_count_reg, baud_count_next;
    logic [3:0]           bit_count_reg, bit_count_next;
    logic [7:0]           txbuff_reg, txbuff_next;
    
    logic txd_reg, txd_next;
    logic tdre_reg, tdre_next;


    // --- 1. Proceso Secuencial (Bloque de Registros) ---
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reiniciar todo
            state_reg      <= MARK;
            baud_count_reg <= '0;
            bit_count_reg  <= '0;
            txbuff_reg     <= '0;
            txd_reg        <= 1'b1; // Linea Idle es '1'
            tdre_reg       <= 1'b1; // Listo al inicio
        end else begin
            // Actualizar todos los registros con su "proximo" valor
            state_reg      <= state_next;
            baud_count_reg <= baud_count_next;
            bit_count_reg  <= bit_count_next;
            txbuff_reg     <= txbuff_next;
            txd_reg        <= txd_next;
            tdre_reg       <= tdre_next;
        end
    end

    // --- 2. Proceso Combinacional (Logica de Proximo Estado) ---
    always_comb begin
        // Valores por defecto: mantener todo igual
        state_next      = state_reg;
        baud_count_next = baud_count_reg;
        bit_count_next  = bit_count_reg;
        txbuff_next     = txbuff_reg;
        txd_next        = txd_reg;
        tdre_next       = tdre_reg;

        // Logica de la FSM
        case (state_reg)
            MARK: begin
                txd_next  = 1'b1; // Mantener linea en '1'
                tdre_next = 1'b1; // Indicar que estamos listos
                
                if (ready) begin // Si el controlador nos da 'Go'
                    state_next      = START;
                    txbuff_next     = tx_data; // Cargar el dato a transmitir
                    baud_count_next = '0;
                    tdre_next       = 1'b0; // Indicar que estamos ocupados
                end
            end
            
            START: begin
                txd_next = 1'b0; // Bit de inicio (Start)
                baud_count_next = baud_count_reg + 1;
                
                if (baud_count_reg == CLKS_PER_BIT) begin
                    state_next      = DELAY; // <-- IR A DELAY, NO A SHIFT
                    baud_count_next = '0;
                    bit_count_next  = '0;
                end
            end
            
            DELAY: begin
                // Sostener el bit actual en la linea (LSB primero)
                txd_next = txbuff_reg[0];
                baud_count_next = baud_count_reg + 1;

                if (baud_count_reg == CLKS_PER_BIT) begin
                    // El tiempo para este bit termino, prepararse para el siguiente
                    txbuff_next     = txbuff_reg >> 1; // Desplazar para exponer el proximo bit
                    bit_count_next  = bit_count_reg + 1;
                    baud_count_next = '0;
                    
                    // ¿Hemos enviado los 8 bits? (indices 0 a 7)
                    if (bit_count_reg == 7) // Si bit_count era 7, acabamos de enviar el 8vo bit
                        state_next = STOP;
                    else
                        state_next = DELAY; // Quedarse en DELAY para el proximo bit
                end
            end
            
            STOP: begin
                txd_next = 1'b1; // Bit de paro (Stop)
                baud_count_next = baud_count_reg + 1;

                if (baud_count_reg == CLKS_PER_BIT) begin
                    state_next = MARK; // Terminar y volver a Idle
                end
            end
            
            default: begin
                state_next = MARK;
            end
        endcase
    end
    
    // --- 3. Asignacion de Salidas ---
    assign TxD  = txd_reg;
    assign tdre = tdre_reg;

endmodule
