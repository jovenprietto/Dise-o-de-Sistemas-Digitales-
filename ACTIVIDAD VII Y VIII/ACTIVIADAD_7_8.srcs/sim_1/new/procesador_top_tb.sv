`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Modulo: procesador_top_tb (Testbench)
// Descripcion: Simula el modulo 'procesador_top' completo.
//              CORREGIDO: Se elimino el uso de 'byte' como nombre de
//              variable y se cambio el bucle 'for' a estilo Verilog.
//////////////////////////////////////////////////////////////////////////////////

module procesador_top_tb;

    // --- Parametros de Simulacion ---
    parameter CLK_PERIOD   = 10;      // 10ns = 100MHz
    parameter BIT_PERIOD   = 104170;  // 104.17 us por bit
    parameter RESET_TIME   = 20_000_000; // 20ms (para el debouncer)

    // --- Señales (Wires y Logic) ---
    logic       clk;
    logic       btnC;       // Boton de Reset
    logic       uart_rxd;   // Lo que la PC envia
    wire        uart_txd;   // Lo que la FPGA responde
    logic [15:0] sw;
    wire  [15:0] led;

    // --- Instanciacion del "Device Under Test" (DUT) ---
    procesador_top DUT (
        .clk(clk),
        .btnC(btnC),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .sw(sw),
        .led(led)
    );


    // --- 1. Generador de Reloj ---
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end


    // --- 2. Tarea para enviar un byte (Simula la PC) ---
    // ESTA TAREA FUE CORREGIDA
    task send_byte(input [7:0] data_in); // <-- 'byte' se cambio a 'data_in'
        integer i; // <-- 'i' se declara aqui (estilo Verilog)
        
        $display("[%0t ns] TB: Enviando byte 0x%h ('%c')", $time, data_in, data_in);
        
        // Bit de Inicio (Start)
        uart_rxd = 1'b0;
        #(BIT_PERIOD);

        // 8 Bits de Datos (LSB primero)
        for (i = 0; i < 8; i = i + 1) begin // <-- Bucle estilo Verilog
            uart_rxd = data_in[i];
            #(BIT_PERIOD);
        end

        // Bit de Paro (Stop)
        uart_rxd = 1'b1;
        #(BIT_PERIOD);
        
        // Pequeña pausa
        #(BIT_PERIOD / 2);
    endtask


    // --- 3. Secuencia Principal de la Prueba ---
    initial begin
        $display("==================================================");
        $display("[%0t ns] TB: Iniciando simulacion...", $time);
        
        // --- A. Inicializacion y Reset ---
        btnC     = 1'b0; // Boton no presionado
        uart_rxd = 1'b1; // Linea UART en reposo (Idle/Mark)
        sw       = 16'h00; // <-- Corregido a 16 bits
        
        #(CLK_PERIOD * 10); // Esperar 100ns
        
        // Presionar el boton de Reset (btnC)
        $display("[%0t ns] TB: Presionando Reset...", $time);
        btnC = 1'b1;
        #(RESET_TIME); // Esperar 20ms (para el debouncer)
        
        $display("[%0t ns] TB: Soltando Reset...", $time);
        btnC = 1'b0;
        
        #(RESET_TIME / 2); // Esperar a que el sistema se estabilice
        $display("[%0t ns] TB: Sistema listo.", $time);
        $display("==================================================");

        
        // --- B. Prueba 1: Padovan(n=5) ---
        // P(0)=1, P(1)=1, P(2)=1, P(3)=2, P(4)=2, P(5)=3
        // Resultado esperado: 0x00000003
        $display("TB: --- Iniciando Prueba 1: Padovan(n=5) ---");
        send_byte(8'h50); // Enviar 'P'
        #(BIT_PERIOD * 20); // Esperar eco y que FSM avance
        send_byte(8'h05); // Enviar n=5
        
        // Esperar el calculo y la transmision de 4 bytes de vuelta
        #(BIT_PERIOD * 50); 
        $display("TB: --- Prueba 1 Completa ---");


        // --- C. Prueba 2: Moser-de Bruijn(n=6) ---
        // S(6) = 20
        // Resultado esperado: 0x00000014
        $display("TB: --- Iniciando Prueba 2: Moser(n=6) ---");
        send_byte(8'h4D); // Enviar 'M'
        #(BIT_PERIOD * 20);
        send_byte(8'h06); // Enviar n=6
        
        #(BIT_PERIOD * 50);
        $display("TB: --- Prueba 2 Completa ---");


        // --- D. Prueba 3: Padovan(n=10) ---
        // P(0-10): 1, 1, 1, 2, 2, 3, 4, 5, 7, 9, 12
        // Resultado esperado: 0x0000000C
        $display("TB: --- Iniciando Prueba 3: Padovan(n=10) ---");
        send_byte(8'h50); // Enviar 'P'
        #(BIT_PERIOD * 20);
        send_byte(8'h0A); // Enviar n=10

        #(BIT_PERIOD * 50);
        $display("TB: --- Prueba 3 Completa ---");
        

        // --- E. Fin de la simulacion ---
        $display("==================================================");
        $display("[%0t ns] TB: Simulacion finalizada.", $time);
        $stop;
    end

endmodule