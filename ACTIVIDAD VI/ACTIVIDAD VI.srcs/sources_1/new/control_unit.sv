`timescale 1ns / 1ps

/*
 * control_unit.sv
 * Implementa la Máquina de Estados Finitos (FSM) que sigue el algoritmo.
 * Lee las banderas (eqflg, ltflg) y genera las señales de control.
 */
module control_unit (
    input  logic       clk, reset,
    input  logic       go,        // Botón para iniciar el cálculo
    // --- Banderas (desde el Datapath) ---
    input  logic       eqflg, ltflg,
    // --- Señales de Control (hacia el Datapath) ---
    output logic       xld, yld, gld,
    output logic       xsel, ysel,
    output logic       done_led  // LED para indicar que el cálculo terminó
);

    // Definición de los estados de la FSM
    typedef enum logic [2:0] {
        S_START,
        S_INPUT,
        S_TEST1,
        S_TEST2,
        S_SUB_Y,  // Estado para y = y - x
        S_SUB_X,  // Estado para x = x - y
        S_DONE
    } state_t;

    state_t current_state, next_state;

    // --- Registro de Estado (Secuencial) ---
    always_ff @(posedge clk, posedge reset) begin
        if (reset) current_state <= S_START;
        else       current_state <= next_state;
    end

    // --- Lógica de Próximo Estado (Combinacional) ---
    always_comb begin
        next_state = current_state; // Por defecto, se queda en el mismo estado
        case (current_state)
            S_START: if (go) next_state = S_INPUT;
            S_INPUT: next_state = S_TEST1;
            S_TEST1: if (eqflg) next_state = S_DONE;
                     else       next_state = S_TEST2;
            S_TEST2: if (ltflg) next_state = S_SUB_Y; // x < y
                     else       next_state = S_SUB_X; // x > y
            S_SUB_Y: next_state = S_TEST1;
            S_SUB_X: next_state = S_TEST1;
            S_DONE:  if (~go) next_state = S_START; // Espera a soltar el botón
        endcase
    end

    // --- Lógica de Salida (Combinacional) ---
    always_comb begin
        // Valores por defecto (todos en 0)
        xld = 1'b0; yld = 1'b0; gld = 1'b0;
        xsel = 1'b0; ysel = 1'b0;
        done_led = 1'b0;

        case (current_state)
            S_INPUT: begin
                xld  = 1'b1; // Cargar xreg
                yld  = 1'b1; // Cargar yreg
                xsel = 1'b1; // Seleccionar xin
                ysel = 1'b1; // Seleccionar yin
            end
            S_SUB_Y: begin // y = y - x
                yld  = 1'b1; // Cargar yreg
                ysel = 1'b0; // Seleccionar (y - x)
            end
            S_SUB_X: begin // x = x - y
                xld  = 1'b1; // Cargar xreg
                xsel = 1'b0; // Seleccionar (x - y)
            end
            S_DONE: begin
                gld      = 1'b1; // Cargar greg con el resultado
                done_led = 1'b1; // Encender el LED
            end
            // S_START, S_TEST1, S_TEST2 no necesitan activar señales
            default: begin
                xld = 1'b0; yld = 1'b0; gld = 1'b0;
                xsel = 1'b0; ysel = 1'b0;
                done_led = 1'b0;
            end
        endcase
    end

endmodule
