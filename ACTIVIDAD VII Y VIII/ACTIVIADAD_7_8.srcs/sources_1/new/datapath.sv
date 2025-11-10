`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: datapath
// Descripcion: El "musculo" del FSMD. Contiene los registros y la ALU.
//              Ejecuta las operaciones indicadas por la Unidad de Control.
//////////////////////////////////////////////////////////////////////////////////

module datapath #(
    parameter WIDTH = 32 // Ancho de los datos (32 bits)
) (
    input logic clk,
    input logic reset,

    // --- Senales de Control (desde la Unidad de Control) ---
    input logic load_a_en,     // Habilitar carga para reg_a
    input logic load_b_en,
    input logic load_c_en,
    input logic load_n_en,
    
    input logic [1:0] mux_a_sel, // Selector para la entrada de reg_a
    input logic [1:0] mux_b_sel,
    input logic [1:0] mux_c_sel,
    input logic [1:0] mux_n_sel,
    
    input logic [1:0] alu_op_sel,  // Selector de operacion de la ALU
    
    // --- Entradas/Salidas de Datos ---
    input  logic [WIDTH-1:0] n_in,       // Valor inicial de 'n' (desde el Main Controller)
    output logic [WIDTH-1:0] result_out, // Resultado final (para el Main Controller)
    
    // --- Flags (hacia la Unidad de Control) ---
    output logic n_is_zero,
    output logic n_msb_is_one,
    output logic n_is_gt_2 
);

    // --- Registros (Estado Interno) ---
    logic [WIDTH-1:0] reg_a, reg_a_next;
    logic [WIDTH-1:0] reg_b, reg_b_next;
    logic [WIDTH-1:0] reg_c, reg_c_next;
    logic [WIDTH-1:0] reg_n, reg_n_next;

    // --- Logica Combinacional (ALU y Muxes) ---
    logic [WIDTH-1:0] alu_out;
    logic [WIDTH-1:0] mux_a_in;
    logic [WIDTH-1:0] mux_b_in;
    logic [WIDTH-1:0] mux_c_in;
    logic [WIDTH-1:0] mux_n_in;

    // --- 1. Proceso Secuencial (Registros) ---
    // Actualiza el estado de todos los registros en el flanco de reloj
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_a <= '0;
            reg_b <= '0;
            reg_c <= '0;
            reg_n <= '0;
        end else begin
            reg_a <= reg_a_next;
            reg_b <= reg_b_next;
            reg_c <= reg_c_next;
            reg_n <= reg_n_next;
        end
    end

    // --- 2. Proceso Combinacional (ALU, Muxes, Logica de Proximo Estado) ---
    always_comb begin
        // --- A. Logica de la ALU ---
        // Define las operaciones que el procesador puede hacer
        case (alu_op_sel)
            'd0: alu_out = reg_b + reg_c;      // Padovan: P(n-2) + P(n-3)
            'd1: alu_out = reg_n - 1;        // Decrementar n
            'd2: alu_out = reg_a << 2;         // Moser: S * 4
            'd3: alu_out = (reg_a << 2) + 1;   // Moser: (S * 4) + 1
            default: alu_out = {WIDTH{1'bx}}; // 'x' para operacion indefinida
        endcase

        // --- B. Logica de Muxes de Entrada ---
        // Define que dato entra a cada registro
        
        // Mux para reg_a (Usado para P(n-1) y S)
        case (mux_a_sel)
            'd0: mux_a_in = 32'd1; // El numero '1' de 32 bits
            'd1: mux_a_in = alu_out;           // Padovan Calc: P_nuevo
            'd2: mux_a_in = {WIDTH{1'b0}};     // Moser Init: S = 0
            'd3: mux_a_in = alu_out;           // Moser Calc: S_nuevo
            default: mux_a_in = {WIDTH{1'bx}};
        endcase
        
        // Mux para reg_b (Usado para P(n-2))
        case (mux_b_sel)
            'd0: mux_b_in = 32'd1; // El numero '1' de 32 bits
            'd1: mux_b_in = reg_a;             // Padovan Shift: P(n-1) -> P(n-2)
            default: mux_b_in = reg_b; // Mantener valor (default)
        endcase

        // Mux para reg_c (Usado para P(n-3))
        case (mux_c_sel)
            'd0: mux_c_in = 32'd1; // El numero '1' de 32 bits
            'd1: mux_c_in = reg_b;             // Padovan Shift: P(n-2) -> P(n-3)
            default: mux_c_in = reg_c; // Mantener valor (default)
        endcase
        
        // Mux para reg_n (Contador)
        case (mux_n_sel)
            'd0: mux_n_in = n_in;              // Cargar valor inicial de 'n'
            'd1: mux_n_in = alu_out;           // Decrementar n
            'd2: mux_n_in = reg_n << 1;         // Moser: Shift n
            default: mux_n_in = reg_n; // Mantener valor (default)
        endcase

        // --- C. Logica de Proximo Estado para Registros ---
        // Decide si un registro debe cargar un nuevo valor o mantener el actual
        
        // Por defecto, mantener el valor actual (evita latches)
        reg_a_next = reg_a;
        reg_b_next = reg_b;
        reg_c_next = reg_c;
        reg_n_next = reg_n;

        if (load_a_en)
            reg_a_next = mux_a_in;
            
        if (load_b_en)
            reg_b_next = mux_b_in;
            
        if (load_c_en)
            reg_c_next = mux_c_in;
            
        if (load_n_en)
            reg_n_next = mux_n_in;
            
    end // fin de always_comb

    // --- 3. Asignacion de Salidas y Flags ---
    assign result_out = reg_a; // El resultado final siempre queda en reg_a
    assign n_is_zero = (reg_n == {WIDTH{1'b0}});
    assign n_msb_is_one = reg_n[WIDTH-1]; // Para el calculo de Moser
    assign n_is_gt_2 = (reg_n > 32'd2);

endmodule