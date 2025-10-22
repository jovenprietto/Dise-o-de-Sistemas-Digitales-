`timescale 1ns / 1ps

/*
 * basys3_top.sv
 * Módulo superior para la tarjeta Basys 3.
 * Conecta el 'gcd_top' y el 'x7segmux' a los pines físicos (switches,
 * botones, LEDs y 7-segmentos).
 */
module basys3_top (
    input  logic       clk,
    input  logic       btnC,    // Usado como reset
    input  logic       btnU,    // Usado como 'go'
    input  logic [15:0] sw,
    output logic [3:0] an,
    output logic [6:0] sseg,
    output logic [0:0] led    // led[0] será el 'done'
);

    logic [7:0] xin, yin, gcd_out;
    logic       done_led_internal;
    logic       reset_sync; // Reset sincronizado
    
    // --- Sincronizar el Reset ---
    // btnC es asíncrono, lo pasamos por dos FFs para sincronizarlo
    logic reset_ff1, reset_ff2;
    always_ff @(posedge clk) begin
        reset_ff1 <= btnC;
        reset_ff2 <= reset_ff1;
    end
    assign reset_sync = reset_ff2; // Reset activo-alto sincronizado

    // --- Asignación de Entradas ---
    assign xin = sw[7:0];
    assign yin = sw[15:8];

    // --- Instancia del Módulo GCD (CU + DP) ---
    gcd_top u_gcd (
        .clk      (clk),
        .reset    (reset_sync),
        .go       (btnU), // btnU es 'go'
        .xin      (xin),
        .yin      (yin),
        .gcd_out  (gcd_out),
        .done_led (done_led_internal)
    );

    // Asignar LED de "listo"
    assign led[0] = done_led_internal;

    // --- Lógica de Visualización en 7-Segmentos ---
    logic [3:0] hex0_disp, hex1_disp, hex2_disp, hex3_disp;
    
    always_comb begin
        if (done_led_internal) begin
            // Cálculo listo: Mostrar "do" y el resultado GCD
            hex0_disp = gcd_out[3:0];  // Resultado (nibble bajo)
            hex1_disp = gcd_out[7:4];  // Resultado (nibble alto)
            hex2_disp = 4'h8;          // Letra 'o' (se parece al 0)
            hex3_disp = 4'hD;          // Letra 'd'
        end else begin
            // Esperando: Mostrar las entradas
            hex0_disp = sw[3:0];       // xin (nibble bajo)
            hex1_disp = sw[7:4];       // xin (nibble alto)
            hex2_disp = sw[11:8];      // yin (nibble bajo)
            hex3_disp = sw[15:12];     // yin (nibble alto)
        end
    end

    // --- Instancia del Módulo de 7-Segmentos ---
    x7segmux u_7seg (
        .clk     (clk),
        .reset   (reset_sync),
        .hex3    (hex3_disp),
        .hex2    (hex2_disp),
        .hex1    (hex1_disp),
        .hex0    (hex0_disp),
        .dp_in   (4'b0000), // No usamos puntos decimales
        .an      (an),
        .sseg    (sseg)
    );

endmodule