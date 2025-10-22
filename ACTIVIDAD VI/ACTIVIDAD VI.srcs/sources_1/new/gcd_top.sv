`timescale 1ns / 1ps

/*
 * gcd_top.sv
 * Módulo que instancia y conecta la Unidad de Control y la Ruta de Datos.
 */
module gcd_top (
    input  logic       clk, reset, go,
    input  logic [7:0] xin, yin,
    output logic [7:0] gcd_out,
    output logic       done_led
);

    // Señales internas para conectar CU y DP
    logic xld, yld, gld;
    logic xsel, ysel;
    logic eqflg, ltflg;

    // Instancia del Datapath
    datapath u_datapath (
        .clk     (clk),
        .reset   (reset),
        .xld     (xld),
        .yld     (yld),
        .gld     (gld),
        .xsel    (xsel),
        .ysel    (ysel),
        .xin     (xin),
        .yin     (yin),
        .eqflg   (eqflg),
        .ltflg   (ltflg),
        .gcd_out (gcd_out)
    );

    // Instancia de la Unidad de Control
    control_unit u_control_unit (
        .clk      (clk),
        .reset    (reset),
        .go       (go),
        .eqflg    (eqflg),
        .ltflg    (ltflg),
        .xld      (xld),
        .yld      (yld),
        .gld      (gld),
        .xsel     (xsel),
        .ysel     (ysel),
        .done_led (done_led)
    );

endmodule