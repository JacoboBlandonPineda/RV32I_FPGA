// ============================================================================
// Memoria de Instrucciones (InstructionMemory)
// ============================================================================
// Almacena el programa a ejecutar. Tiene capacidad de 4KB (1024 palabras de 32 bits).
// Las instrucciones se almacenan como bytes y se leen como palabras completas de 32 bits.
// Se inicializa desde un archivo binario hexadecimal al inicio de la simulación.
//
// Nota: En un procesador real, esta sería una memoria ROM o caché de instrucciones.
// Aquí se implementa como memoria de solo lectura que se carga al inicio.
// ============================================================================

module InstructionMemory (
    input  logic [31:0] Address,        // Dirección de la instrucción (PC)
    output logic [31:0] Instruction = 0 // Instrucción de 32 bits leída
);

  // Memoria de 4KB organizada como 1024 bytes
  // Cada instrucción ocupa 4 bytes consecutivos
  logic [7:0] imem[1023:0];

  // ========== INICIALIZACIÓN ==========
  // Carga el programa desde un archivo hexadecimal al inicio de la simulación
  initial begin
    // Inicializar toda la memoria a cero
    for (int i = 0; i < 1024; i++) imem[i] = 8'b0;
    // Cargar instrucciones desde el archivo Instructions.bin
    $readmemh("./Instructions.bin", imem, 0, 1023);
  end

  // ========== LECTURA COMBINACIONAL ==========
  // Lee 4 bytes consecutivos y los concatena en una palabra de 32 bits
  // Orden little-endian: byte en menor dirección es el menos significativo
  always @* begin
    Instruction = {imem[Address], imem[Address+1], imem[Address+2], imem[Address+3]};
  end

endmodule