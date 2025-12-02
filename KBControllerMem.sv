// ============================================================================
// Controlador de Teclado PS/2 Mapeado en Memoria (KBControllerMem)
// ============================================================================
// Implementa un controlador para teclados PS/2 y lo mapea en el espacio de
// memoria del procesador en la dirección 0xFFFF0000. Cuando el procesador lee
// esta dirección, obtiene el código de la última tecla presionada.
//
// Protocolo PS/2:
//   - Cada tecla genera un código de escaneo (scan code) de 8 bits
//   - Los datos se transmiten serialmente a través de ps2_data
//   - El reloj ps2_clk sincroniza la transmisión
//   - Formato: 1 bit start (0), 8 bits datos, 1 bit paridad, 1 bit stop (1)
//
// El código de tecla también se muestra en los LEDs de la FPGA.
// ============================================================================

module KBControllerMem (
    input  logic clk,              // Reloj del sistema
    input  logic ps2_clk,          // Reloj del protocolo PS/2 (del teclado)
    input  logic ps2_data,         // Dato serial del teclado
    input  logic MemRead,          // Señal de lectura de memoria
    input  logic [31:0] Address,   // Dirección de memoria
    output logic [7:0] leds,       // LEDs para mostrar el keycode
    output logic [31:0] DataOut    // Dato leído (32 bits, solo 8 bits útiles)
);

    // ========== VARIABLES DE ESTADO ==========
    logic [3:0] count = 11;        // Contador para recibir bits (11 = idle)
    logic [7:0] keycode = 8'b0;    // Código de tecla recibido
    logic [7:0] aux;               // Registro auxiliar para almacenar bits
    logic parity;                  // Bit de paridad calculado

    // ========== RECEPCIÓN DE DATOS PS/2 ==========
    // Recibe datos en el flanco negativo de ps2_clk (protocolo PS/2)
    always_ff @(negedge ps2_clk) begin
        if (count == 11) begin
            // Estado idle: esperar bit de inicio (start bit = 0)
            if (~ps2_data) begin
                count <= 1;      // Iniciar recepción
                parity <= 1;     // Inicializar paridad impar
            end
        end else if (count < 9) begin
            // Recibir bits de datos (8 bits, del 0 al 7)
            aux[count-1] <= ps2_data;
            // Actualizar paridad: cambiar si el bit es 1
            if (ps2_data) parity <= ~parity;
            count <= count + 1;
        end else if (count == 9) begin
            // Verificar bit de paridad
            if (parity == ps2_data) keycode <= aux;  // Guardar solo si paridad correcta
            count <= 10;  // Ir a estado de espera del stop bit
        end else begin
            // count == 10: esperar stop bit, luego volver a idle
            count <= 11;
        end
    end

    // ========== INTERFAZ CON MEMORIA ==========
    // Mapeado en dirección 0xFFFF0000: cuando se lee, devuelve el keycode
    always_ff @(posedge clk) begin
        if (MemRead && Address == 32'hFFFF0000) begin
            DataOut <= {24'b0, keycode}; // Extender keycode a 32 bits (solo 8 bits útiles)
        end else begin
            DataOut <= 32'b0;  // Otras direcciones devuelven 0
        end
    end

    // ========== SALIDA A LEDs ==========
    // Mostrar el código de tecla actual en los LEDs de la FPGA
    assign leds = keycode;

endmodule
	