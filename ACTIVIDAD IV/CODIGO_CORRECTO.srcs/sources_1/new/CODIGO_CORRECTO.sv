`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.09.2025 13:34:42
// Design Name: 
// Module Name: CODIGO_CORRECTO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module CODIGO_CORRECTO(
    input  logic       clk,      
    input  logic [7:0] sw,       // switches definen código secreto 
    input  logic       btnU,     // botón -> 1
    input  logic       btnR,     // botón -> 2
    input  logic       btnL,     // botón -> 3
    input  logic       btnD,     // botón -> 0
    input  logic       btnC,     // reset manual
    output logic [15:0] led      // led[0]=correcto, led[1]=incorrecto
);

    // -----------------------------
    // Código secreto (switches)
    // -----------------------------
    logic [1:0] secret [3:0];
    assign secret[0] = sw[7:6];
    assign secret[1] = sw[5:4];
    assign secret[2] = sw[3:2];
    assign secret[3] = sw[1:0];

    // -----------------------------
    // definición de estados
    // -----------------------------
    typedef enum logic [2:0] {
        q0, q1, q2, q3, q4, fail
    } state_type;

    state_type state_reg, state_next;

    // -----------------------------
    // Flip-flops por botón
    /*
    always_ff @(posedge clk) begin
    // Botón U
    ffU0 <= btnU;      // valor actual del botón
    ffU1 <= ffU0;      // valor del botón hace 1 ciclo
    ffU2 <= ffU1;      // valor del botón hace 2 ciclos

    // Botón R
    ffR0 <= btnR;
    ffR1 <= ffR0;
    ffR2 <= ffR1;

    // Botón L
    ffL0 <= btnL;
    ffL1 <= ffL0;
    ffL2 <= ffL1;

    // Botón D
    ffD0 <= btnD;
    ffD1 <= ffD0;
    ffD2 <= ffD1;

    // Botón C (reset)
    ffC0 <= btnC;
    ffC1 <= ffC0;
    ffC2 <= ffC1;
end

*/
    // -----------------------------
    logic [2:0] ffU, ffR, ffL, ffD, ffC;
    logic btnU_rise, btnR_rise, btnL_rise, btnD_rise, btnC_rise;

    always_ff @(posedge clk) begin
        ffU <= {ffU[1:0], btnU};
        ffR <= {ffR[1:0], btnR};
        ffL <= {ffL[1:0], btnL};
        ffD <= {ffD[1:0], btnD};
        ffC <= {ffC[1:0], btnC};
    end

    always_comb begin
        btnU_rise = ffU[1] & ~ffU[2];
        btnR_rise = ffR[1] & ~ffR[2];
        btnL_rise = ffL[1] & ~ffL[2];
        btnD_rise = ffD[1] & ~ffD[2];
        btnC_rise = ffC[1] & ~ffC[2];
    end

    // -----------------------------
    // Lógica de registro de estado
    // -----------------------------
    always_ff @(posedge clk or posedge btnC_rise) begin
        if (btnC_rise)
            state_reg <= q0;
        else
            state_reg <= state_next;
    end

    // -----------------------------
    // Contador de fallos
    // -----------------------------
    logic [2:0] fail_count;
    always_ff @(posedge clk or posedge btnC_rise) begin
        if (btnC_rise)
            fail_count <= 0;
        else if (state_next == fail)
            fail_count <= fail_count + 1;
        else if (state_next == q0)
            fail_count <= 0; // reinicio automático
    end

    // -----------------------------
    // Función para leer el valor de botón
    // -----------------------------
    function automatic logic [1:0] get_btn_value();
        if (btnU_rise) get_btn_value = 2'b01;
        else if (btnR_rise) get_btn_value = 2'b10;
        else if (btnL_rise) get_btn_value = 2'b11;
        else if (btnD_rise) get_btn_value = 2'b00;
        else get_btn_value = 2'bxx; 
    endfunction

    // -----------------------------
    // Lógica de transición (next-state)
    // -----------------------------
    logic [1:0] entered_value;

    always_comb begin
        state_next = state_reg;
        entered_value = get_btn_value();

        case(state_reg)
            q0: begin
                if (entered_value !== 2'bxx)
                    state_next = (entered_value == secret[0]) ? q1 : fail;
            end
            q1: begin
                if (entered_value !== 2'bxx)
                    state_next = (entered_value == secret[1]) ? q2 : fail;
            end
            q2: begin
                if (entered_value !== 2'bxx)
                    state_next = (entered_value == secret[2]) ? q3 : fail;
            end
            q3: begin
                if (entered_value !== 2'bxx)
                    state_next = (entered_value == secret[3]) ? q4 : fail;
            end
            fail: begin
                if (fail_count >= 3'd4)
                    state_next = q0; // reinicio automático el error tambien es un estado 
            end
            q4: begin
                // espera reset manual
                if (btnC_rise)
                    state_next = q0;
            end
            default: state_next = q0;
        endcase
    end

    // -----------------------------
    // Salidas
    // -----------------------------
    always_comb begin
        led = 16'b0;
        led[0] = (state_reg == q4);      // código correcto
        led[1] = (state_reg == fail);    // fallo
        led[11:9] = fail_count;          // número de fallos
    end

endmodule

