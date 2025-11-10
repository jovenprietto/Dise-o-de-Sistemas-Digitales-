`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: control_unit_fsmd
// Descripcion: El "cerebro" del FSMD. Es una FSM que le dice al
//              Datapath que operaciones hacer y en que orden.
//              Controla la ejecucion de Padovan y Moser-de Bruijn.
//////////////////////////////////////////////////////////////////////////////////

module control_unit_fsmd #(
    parameter WIDTH = 32 // Debe coincidir con el Datapath
) (
    input logic clk,
    input logic reset,

    // --- Interfaz con el Main Controller ---
    input logic start_calc,        // "Go" desde el cerebro maestro
    input logic algo_select,       // 0=Padovan, 1=Moser
    input logic [WIDTH-1:0] n_in,  // 'n' a calcular
    output logic done,             // "He terminado"

    // --- Interfaz con el Datapath (Entradas de Flags) ---
    input logic n_is_zero,
    input logic n_msb_is_one,
    input logic n_is_gt_2,

    // --- Interfaz con el Datapath (Salidas de Control) ---
    output logic load_a_en,
    output logic load_b_en,
    output logic load_c_en,
    output logic load_n_en,
    
    output logic [1:0] mux_a_sel,
    output logic [1:0] mux_b_sel,
    output logic [1:0] mux_c_sel,
    output logic [1:0] mux_n_sel,
    
    output logic [1:0] alu_op_sel
);

    // --- Definicion de Estados de la FSM ---
    typedef enum logic [3:0] {
        IDLE,
        INIT_LOAD,
        // Estados de Padovan
        PADOVAN_INIT,
        PADOVAN_CHECK,
        PADOVAN_CALC_SHIFT,
        PADOVAN_DECR_N,
        // Estados de Moser
        MOSER_INIT,
        MOSER_CHECK,
        MOSER_CALC,
        MOSER_SHIFT_N,
        // Estado final
        DONE_STATE
    } state_t;

    // --- Senales Internas ---
    state_t state_reg, state_next;
    
    // Contador de bits para el algoritmo de Moser
    logic [5:0] bit_count_reg, bit_count_next; // 6 bits para contar hasta 32

    // --- 1. Proceso Secuencial (Registros de Estado) ---
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg     <= IDLE;
            bit_count_reg <= '0;
        end else begin
            state_reg     <= state_next;
            bit_count_reg <= bit_count_next;
        end
    end

    // --- 2. Proceso Combinacional (Logica de Proximo Estado y Salidas) ---
    always_comb begin
        // Valores por defecto: No hacer nada (mantener estado, no cargar registros)
        state_next      = state_reg;
        bit_count_next  = bit_count_reg;
        done            = 1'b0;
        
        load_a_en    = 1'b0;
        load_b_en    = 1'b0;
        load_c_en    = 1'b0;
        load_n_en    = 1'b0;
        
        mux_a_sel    = '0;
        mux_b_sel    = '0;
        mux_c_sel    = '0;
        mux_n_sel    = '0;
        
        alu_op_sel   = '0;

        // Logica de la FSM
        case (state_reg)
            IDLE: begin
                if (start_calc) begin
                    state_next = INIT_LOAD;
                end
            end
            
            INIT_LOAD: begin
                // Cargar el valor de 'n' en el reg_n del datapath
                load_n_en = 1'b1;
                mux_n_sel = 'd0; // Seleccionar n_in
                
                if (algo_select == 1'b0) // 0 = Padovan
                    state_next = PADOVAN_INIT;
                else // 1 = Moser
                    state_next = MOSER_INIT;
            end

            // --- RAMA PADOVAN ---
            PADOVAN_INIT: begin
                // Cargar casos base: a=P(2)=1, b=P(1)=1, c=P(0)=1
                load_a_en = 1'b1; mux_a_sel = 'd0; // Cargar 1
                load_b_en = 1'b1; mux_b_sel = 'd0; // Cargar 1
                load_c_en = 1'b1; mux_c_sel = 'd0; // Cargar 1
                state_next = PADOVAN_CHECK;
            end
            
            PADOVAN_CHECK: begin
                // n se compara con '2' (n=0, 1, 2 son casos base)
                if (n_is_gt_2) begin // if (n > 2)
                    state_next = PADOVAN_DECR_N;
                end else begin // if (n <= 2)
                    state_next = DONE_STATE; // El resultado (1) ya esta en reg_a
                end
            end

            PADOVAN_DECR_N: begin
                // Decrementar n: n = n - 1
                load_n_en  = 1'b1;
                mux_n_sel  = 'd1;    // Seleccionar alu_out
                alu_op_sel = 'd1;    // ALU = n - 1
                state_next = PADOVAN_CALC_SHIFT;
            end
            
            PADOVAN_CALC_SHIFT: begin
                // Calcular P_nuevo y hacer el shift al mismo tiempo
                // a = b + c (P_nuevo = P(n-2) + P(n-3))
                load_a_en  = 1'b1;
                mux_a_sel  = 'd1;    // Seleccionar alu_out
                alu_op_sel = 'd0;    // ALU = b + c
                
                // b = a (P(n-1) se vuelve P(n-2))
                load_b_en  = 1'b1;
                mux_b_sel  = 'd1;    // Seleccionar reg_a
                
                // c = b (P(n-2) se vuelve P(n-3))
                load_c_en  = 1'b1;
                mux_c_sel  = 'd1;    // Seleccionar reg_b
                
                state_next = PADOVAN_CHECK;
            end
            
            // --- RAMA MOSER-DE BRUIJN ---
            MOSER_INIT: begin
                // S = 0
                load_a_en      = 1'b1;
                mux_a_sel      = 'd2; // Cargar 0
                bit_count_next = '0; // Reiniciar contador de bits
                state_next     = MOSER_CHECK;
            end
            
            MOSER_CHECK: begin
                if (bit_count_reg == WIDTH) // Si ya procesamos 32 bits
                    state_next = DONE_STATE;
                else
                    state_next = MOSER_CALC;
            end
            
            MOSER_CALC: begin
                // S = (S*4) o S = (S*4)+1, basado en el MSB de n
                load_a_en = 1'b1;
                mux_a_sel = 'd3; // Seleccionar alu_out
                
                if (n_msb_is_one)
                    alu_op_sel = 'd3; // S = (S*4) + 1
                else
                    alu_op_sel = 'd2; // S = (S*4)
                
                state_next = MOSER_SHIFT_N;
            end

            MOSER_SHIFT_N: begin
                // Shift n a la izquierda para exponer el siguiente bit
                load_n_en = 1'b1;
                mux_n_sel = 'd2; // n = n << 1
                
                // Incrementar nuestro contador de bits
                bit_count_next = bit_count_reg + 1;
                
                state_next = MOSER_CHECK;
            end

            // --- ESTADO FINAL ---
            DONE_STATE: begin
                done = 1'b1;
                state_next = IDLE;
            end
            
            default: begin
                state_next = IDLE;
            end
        endcase
    end

endmodule
