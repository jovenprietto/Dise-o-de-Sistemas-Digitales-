`timescale 1ns / 1ps

/*
 * datapath.sv
 * Contiene los registros, MUXes, y lógica aritmética (restadores/comparadores).
 * Recibe señales de control (xld, yld, etc.) y envía banderas (eqflg, ltflg).
 */
module datapath (
    input  logic       clk, reset,
    // --- Entradas de Control (desde la FSM) ---
    input  logic       xld, yld, gld,
    input  logic       xsel, ysel,
    // --- Entradas de Datos (desde los switches) ---
    input  logic [7:0] xin, yin,
    // --- Salidas de Banderas (hacia la FSM) ---
    output logic       eqflg, ltflg,
    // --- Salida Final (hacia los 7-seg) ---
    output logic [7:0] gcd_out
);

    logic [7:0] xreg, yreg, greg;
    logic [7:0] x_in_mux, y_in_mux;
    logic [7:0] sub_x_y, sub_y_x;

    // --- Lógica Aritmética ---
    assign sub_x_y = xreg - yreg; // Para x = x - y
    assign sub_y_x = yreg - xreg; // Para y = y - x

    // --- MUXes de Entrada para los Registros ---
    // xsel=1: Carga 'xin' (desde S_INPUT)
    // xsel=0: Carga 'x-y' (desde S_SUB_X)
    assign x_in_mux = (xsel) ? xin : sub_x_y;

    // ysel=1: Carga 'yin' (desde S_INPUT)
    // ysel=0: Carga 'y-x' (desde S_SUB_Y)
    assign y_in_mux = (ysel) ? yin : sub_y_x;

    // --- Registros ---
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            xreg <= 8'h00;
            yreg <= 8'h00;
            greg <= 8'h00;
        end else begin
            if (xld) xreg <= x_in_mux;
            if (yld) yreg <= y_in_mux;
            if (gld) greg <= xreg; // El resultado es el valor en xreg
        end
    end

    // --- Banderas de Comparación ---
    assign eqflg   = (xreg == yreg); // (x == y)
    assign ltflg   = (xreg < yreg);  // (x < y)
    
    // --- Salida Final ---
    assign gcd_out = greg;

endmodule