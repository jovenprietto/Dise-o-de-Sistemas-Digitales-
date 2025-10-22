`timescale 1ns / 1ps

/*
 * gcd_tb.sv
 * Testbench para simular el módulo 'gcd_top'.
 */
module gcd_tb;

    logic       clk;
    logic       reset, go;
    logic [7:0] xin, yin;
    logic [7:0] gcd_out;
    logic       done_led;

    // Instancia del diseño bajo prueba (UUT)
    gcd_top uut (.*);

    // --- Generador de Clock ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Clock de 100MHz (periodo 10ns)
    end

    // --- Secuencia de Estímulos ---
    initial begin
        $display("Inicio de la simulación GCD");
        reset = 1;
        go = 0;
        xin = 8'h00;
        yin = 8'h00;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        $display("Reset liberado");

        // --- Caso 1: GCD(70, 15) ---
        $display("Caso 1: GCD(70, 15)");
        xin = 8'd70; // 0x46
        yin = 8'd15; // 0x0F
        @(posedge clk);
        
        go = 1; // Presionar 'go'
        @(posedge clk);
        go = 0; // Soltar 'go'
        
        // Esperar a que 'done_led' se active
        wait (done_led == 1'b1);
        $display("Cálculo terminado. Resultado: %d", gcd_out);
        if (gcd_out == 8'd5) $display("Prueba 1: PASÓ");
        else                 $display("Prueba 1: FALLÓ");
        
        @(posedge clk);

        // --- Caso 2: GCD(15, 70) ---
        $display("Caso 2: GCD(15, 70)");
        xin = 8'd15;
        yin = 8'd70;
        @(posedge clk);
        
        go = 1; @(posedge clk); go = 0;
        
        wait (done_led == 1'b1);
        $display("Cálculo terminado. Resultado: %d", gcd_out);
        if (gcd_out == 8'd5) $display("Prueba 2: PASÓ");
        else                 $display("Prueba 2: FALLÓ");
        
        @(posedge clk);

        // --- Caso 3: GCD(12, 18) = 6 ---
        $display("Caso 3: GCD(12, 18)");
        xin = 8'd12;
        yin = 8'd18;
        @(posedge clk);
        
        go = 1; @(posedge clk); go = 0;
        
        wait (done_led == 1'b1);
        $display("Cálculo terminado. Resultado: %d", gcd_out);
        if (gcd_out == 8'd6) $display("Prueba 3: PASÓ");
        else                 $display("Prueba 3: FALLÓ");
        
        @(posedge clk);

        $display("Simulación finalizada.");
        $stop;
    end

endmodule
