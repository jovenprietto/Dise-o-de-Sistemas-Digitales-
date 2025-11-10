`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: debouncing
// Descripcion: Filtra el rebote mecanico de un boton o switch.
//              Espera un tiempo estable (aprox. 10.4ms) antes de 
//              cambiar la salida.
//////////////////////////////////////////////////////////////////////////////////

module debouncing (
    input logic clk,           // Reloj principal (100MHz)
    input logic reset,         // Reset asincrono
    input logic sw_inp,        // Entrada ruidosa (boton)
    output logic debounced_out // Salida limpia
);

    // Parametros para el temporizador
    // 100MHz clock -> 10ns periodo
    // Para ~10ms tick: 10ms / 10ns = 1,000,000 ciclos
    // 2^N >= 1,000,000 -> N = 20 (da 1,048,576 ciclos, ~10.48ms)
    localparam N = 20;

    // Definicion de la maquina de estados (FSM)
    typedef enum logic [1:0] {
        ZERO,   // Estado estable en 0
        WAIT_1, // Esperando confirmacion de 1
        ONE,    // Estado estable en 1
        WAIT_0  // Esperando confirmacion de 0
    } state_t;

    // --- Señales Internas ---
    state_t state_reg, state_next; // Registros de estado
    logic [N-1:0] q_reg, q_next;   // Registro del contador
    logic m_tick;                 // Pulso del temporizador

    // --- 1. Contador del Temporizador ---
    // Este contador genera un pulso 'm_tick' cada ~10.48ms
    
    // El registro del contador se actualiza en el flanco de reloj
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            q_reg <= '0;
        else if (q_reg == (2**N - 1)) // Si el contador llega al maximo
            q_reg <= '0; // Se reinicia
        else
            q_reg <= q_reg + 1; // Incrementa normalmente
    end
    
    // La senal 'm_tick' es un pulso de 1 ciclo cuando el contador esta en su valor maximo
    assign m_tick = (q_reg == (2**N - 1));

    // --- 2. FSM de Debouncing ---
    // Registro del estado de la FSM
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state_reg <= ZERO;
        else
            state_reg <= state_next;
    end

    // Logica combinacional del proximo estado
    always_comb begin
        state_next = state_reg; // Valor por defecto: permanecer en el mismo estado
        debounced_out = 1'b0;   // Salida por defecto

        case (state_reg)
            ZERO: begin
                debounced_out = 1'b0;
                if (sw_inp) // Si la entrada sube
                    state_next = WAIT_1; // Mover a estado de espera
            end

            WAIT_1: begin
                debounced_out = 1'b0;
                if (~sw_inp) // Si fue ruido (volvio a 0)
                    state_next = ZERO; // Regresar
                else if (m_tick) // Si se mantuvo en 1 por 10.4ms
                    state_next = ONE; // Confirmar estado 1
            end

            ONE: begin
                debounced_out = 1'b1;
                if (~sw_inp) // Si la entrada baja
                    state_next = WAIT_0; // Mover a estado de espera
            end

            WAIT_0: begin
                debounced_out = 1'b1;
                if (sw_inp) // Si fue ruido (volvio a 1)
                    state_next = ONE; // Regresar
                else if (m_tick) // Si se mantuvo en 0 por 10.4ms
                    state_next = ZERO; // Confirmar estado 0
            end

            default: begin
                state_next = ZERO;
                debounced_out = 1'b0;
            end
        endcase
    end
endmodule