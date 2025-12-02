// ============================================================================
// Banco de Registros (RegisterUnit)
// ============================================================================
// Implementa el banco de 32 registros de 32 bits del procesador RISC-V.
// El registro x0 siempre vale 0 y no puede ser modificado.
// Las lecturas son combinacionales (asíncronas) y las escrituras son
// síncronas (flanco de subida del reloj).
//
// Convención de registros RISC-V:
//   x0 (zero): Siempre cero, no puede escribirse
//   x1 (ra): Return address
//   x2 (sp): Stack pointer (inicializado a 1024)
//   x3-x31: Registros de propósito general
// ============================================================================

module RegisterUnit (
    input  logic        clk,         // Reloj del sistema
    input  logic        RUWr,        // Habilitar escritura (write enable)
    input  logic [ 4:0] rs1,         // Dirección del registro fuente 1
    input  logic [ 4:0] rs2,         // Dirección del registro fuente 2
    input  logic [ 4:0] rd,          // Dirección del registro destino
    input  logic [31:0] RUDataWr,    // Dato a escribir
    output logic [31:0] RUrs1,       // Valor leído del registro rs1
    output logic [31:0] RUrs2        // Valor leído del registro rs2
);

  // Banco de 32 registros de 32 bits
  logic [31:0] ru[31:0];

  // ========== INICIALIZACIÓN ==========
  // Inicializa todos los registros a cero, excepto x2 (stack pointer) a 1024
  initial begin
    for (int i = 0; i < 32; i++) ru[i] = 32'b0;
    ru[2] = 32'b1000000000;  // Inicializar x2 (stack pointer) a 1024
  end

  // ========== LECTURA COMBINACIONAL ==========
  // Las lecturas son asíncronas: el valor está disponible inmediatamente
  // Nota: x0 siempre retorna 0 debido a la inicialización
  assign RUrs1 = ru[rs1];
  assign RUrs2 = ru[rs2];

  // ========== ESCRITURA SINCRÓNICA ==========
  // Las escrituras ocurren en el flanco de subida del reloj
  // El registro x0 nunca puede escribirse (siempre permanece en 0)
  always @(posedge clk) begin
    if (RUWr && (rd != 5'd0)) ru[rd] <= RUDataWr;
  end

endmodule
