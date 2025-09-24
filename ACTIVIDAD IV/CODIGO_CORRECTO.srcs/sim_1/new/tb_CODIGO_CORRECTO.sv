`timescale 1ns / 1ps

module tb_CODIGO_CORRECTO();

    // Señales de prueba
    logic clk;
    logic [7:0] sw;
    logic btnU, btnR, btnL, btnD, btnC;
    logic [15:0] led;

    // Instanciamos el DUT
    CODIGO_CORRECTO uut (
        .clk(clk),
        .sw(sw),
        .btnU(btnU),
        .btnR(btnR),
        .btnL(btnL),
        .btnD(btnD),
        .btnC(btnC),
        .led(led)
    );

    // Generador de reloj
    always #5 clk = ~clk;  // periodo = 10ns

    // Tarea para simular pulsación de un botón
    task press_button(input logic ref_btn);
        begin
            ref_btn = 1;
            #10; // botón presionado por un ciclo
            ref_btn = 0;
            #30; // tiempo entre pulsaciones
        end
    endtask

    initial begin
        // Inicialización
        clk = 0;
        btnU = 0; btnR = 0; btnL = 0; btnD = 0; btnC = 0;
        sw = 8'b0110_1100; 
        // secreto = {sw[7:6], sw[5:4], sw[3:2], sw[1:0]}
        // secreto = 01,10,11,00

        // Reset manual
        #20 press_button(btnC);

        // Caso 1: secuencia incorrecta (primer botón mal)
        $display("Prueba: Secuencia incorrecta (fallo esperado)");
        press_button(btnR); // debería fallar (esperaba 01, se da 10)
        #50;

        // Caso 2: secuencia correcta
        $display("Prueba: Secuencia correcta (debería llegar a estado q4)");
        press_button(btnU); // 01
        press_button(btnR); // 10
        press_button(btnL); // 11
        press_button(btnD); // 00
        #50;

        // Caso 3: varios fallos hasta reset automático
        $display("Prueba: múltiples fallos");
        repeat(5) press_button(btnD); // todas incorrectas
        #100;

        // Caso 4: reset manual desde q4
        $display("Prueba: reset manual");
        press_button(btnU);
        press_button(btnR);
        press_button(btnL);
        press_button(btnD); // código correcto
        #50 press_button(btnC); // reset manual
        #50;

        $finish;
    end

endmodule
