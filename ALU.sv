// ============================================================================
// Unidad Aritmético-Lógica (ALU)
// ============================================================================
// Ejecuta operaciones aritméticas, lógicas y de comparación entre dos operandos
// de 32 bits. La operación a realizar se especifica mediante el código ALUOp.
//
// Operaciones soportadas:
//   - Aritméticas: suma, resta
//   - Lógicas: AND, OR, XOR
//   - Desplazamientos: izquierda, derecha lógica, derecha aritmética
//   - Comparaciones: menor que (con/sin signo)
//   - Especial: pasar operando B (para LUI)
// ============================================================================

module alu (
    input  logic signed [31:0] A,      // Operando A (puede ser PC o valor de registro)
    input  logic signed [31:0] B,      // Operando B (puede ser inmediato o valor de registro)
    input  logic        [ 3:0] ALUOp,  // Código de operación (4 bits)
    output logic signed [31:0] ALURes  // Resultado de la operación
);

  always @* begin
    case (ALUOp)
      4'b0000: ALURes = A + B;              // ADD: Suma
      4'b1000: ALURes = A - B;              // SUB: Resta
      4'b0001: ALURes = A << B[4:0];        // SLL: Shift Left Logical (usa bits 4:0 de B)
      4'b0010: ALURes = (A < B) ? 1 : 0;    // SLT: Set Less Than (comparación con signo)
      4'b0011: ALURes = ($unsigned(A) < $unsigned(B)) ? 1 : 0;  // SLTU: Set Less Than Unsigned
      4'b0100: ALURes = A ^ B;              // XOR: O exclusivo
      4'b0101: ALURes = A >> B[4:0];        // SRL: Shift Right Logical
      4'b1101: ALURes = A >>> B[4:0];       // SRA: Shift Right Arithmetic (extiende signo)
      4'b0110: ALURes = A | B;              // OR: O lógico
      4'b0111: ALURes = A & B;              // AND: Y lógico
      4'b1001: ALURes = B;                  // Operación especial: pasar B (para LUI)
      default: ALURes = 0;                  // Por defecto: cero
    endcase
  end

endmodule
