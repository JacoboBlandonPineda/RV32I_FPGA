// ============================================================================
// Controlador VGA (VGAController)
// ============================================================================
// Genera las señales de sincronización y color para un monitor VGA estándar.
// Implementa el protocolo VGA 640x480@60Hz con un reloj de pixel de 25 MHz.
// Los colores se proporcionan en formato RGB332 (3 bits rojo, 3 bits verde, 2 bits azul).
//
// Resolución: 640x480 píxeles
// Frecuencia: 25 MHz para pixel clock, 50 MHz para reloj de entrada
// Formato de color: RGB332 (8 bits total: RRRGGGBB)
// ============================================================================

module VGAController #(
  parameter H_BACK_PORCH = 48,      // Horizontal back porch (píxeles después del display)
  parameter H_DISPLAY_TIME = 640,   // Tiempo de visualización horizontal (ancho activo)
  parameter H_FRONT_PORCH = 16,     // Horizontal front porch (píxeles antes del sync)
  parameter H_SYNC_TIME = 96,       // Ancho del pulso de sincronización horizontal
  parameter H_TOTAL = H_BACK_PORCH + H_DISPLAY_TIME + H_FRONT_PORCH + H_SYNC_TIME, 
  
  parameter V_BACK_PORCH = 33,      // Vertical back porch (líneas después del display)
  parameter V_DISPLAY_TIME = 480,   // Tiempo de visualización vertical (alto activo)
  parameter V_FRONT_PORCH = 10,     // Vertical front porch (líneas antes del sync)
  parameter V_SYNC_TIME = 2,        // Ancho del pulso de sincronización vertical
  parameter V_TOTAL = V_BACK_PORCH + V_DISPLAY_TIME + V_FRONT_PORCH + V_SYNC_TIME
)(
  input logic clk,              // Reloj de la FPGA (50 MHz)
  input logic [7:0] pixel_data, // Dato del píxel en formato RGB332
  output logic clk_25MHz = 0,   // Reloj de 25 MHz para VGA (habilitación)
  output logic [2:0] red,       // Señal de color rojo (3 bits)
  output logic [2:0] green,     // Señal de color verde (3 bits)
  output logic [1:0] blue,      // Señal de color azul (2 bits)
  output logic h_sync = 0,      // Señal de sincronización horizontal
  output logic v_sync = 0       // Señal de sincronización vertical
);

  // ========== DIVISOR DE RELOJ ==========
  // Divide el reloj de 50 MHz a 25 MHz (toggle cada ciclo)
  always_ff @(posedge clk) begin
    clk_25MHz <= !clk_25MHz;
  end

  // ========== CONTADOR HORIZONTAL ==========
  // Controla la sincronización horizontal (línea por línea)
  logic [9:0] h_counter = 0;   // Contador horizontal (0 a H_TOTAL-1)
  logic h_display = 0;         // Señal de zona visible horizontalmente
  logic new_line = 0;          // Señal que indica fin de línea

  always_ff @(posedge clk) begin
    if (clk_25MHz) begin
      // Incrementar contador horizontal
      if (h_counter == H_TOTAL - 1) begin
        h_counter <= 0;  // Reiniciar al final de la línea
      end else begin
        h_counter <= h_counter + 1;
      end
      // Determinar si estamos en la zona visible horizontal
      h_display <= (h_counter >= H_BACK_PORCH && h_counter < H_BACK_PORCH + H_DISPLAY_TIME);
      // Generar pulso de sincronización horizontal (activo bajo normalmente)
      h_sync <= (h_counter >= H_BACK_PORCH + H_DISPLAY_TIME + H_FRONT_PORCH && h_counter < H_TOTAL);
      // Señal de nueva línea al final del contador
      new_line <= h_counter == H_TOTAL - 1;
    end
  end

  // ========== CONTADOR VERTICAL ==========
  // Controla la sincronización vertical (frame completo)
  logic [9:0] v_counter = 0;   // Contador vertical (0 a V_TOTAL-1)
  logic v_display = 0;         // Señal de zona visible verticalmente

  always_ff @(posedge clk) begin
    if (clk_25MHz && new_line) begin
      // Incrementar contador vertical solo al final de cada línea
      if (v_counter == V_TOTAL - 1) begin
        v_counter <= 0;  // Reiniciar al final del frame
      end else begin
        v_counter <= v_counter + 1;
      end
      // Determinar si estamos en la zona visible vertical
      v_display <= (v_counter >= V_BACK_PORCH && v_counter < V_BACK_PORCH + V_DISPLAY_TIME);
      // Generar pulso de sincronización vertical
      v_sync <= (v_counter >= V_BACK_PORCH + V_DISPLAY_TIME + V_FRONT_PORCH && v_counter < V_TOTAL);
    end
  end

  // ========== GENERACIÓN DE COLORES ==========
  // Envía los datos de color solo cuando estamos en la zona visible
  // Formato RGB332: pixel_data[7:5] = rojo, [4:2] = verde, [1:0] = azul
  assign red   = (h_display && v_display) ? pixel_data[7:5] : 3'b0;
  assign green = (h_display && v_display) ? pixel_data[4:2] : 3'b0;
  assign blue  = (h_display && v_display) ? pixel_data[1:0] : 2'b0;

endmodule
