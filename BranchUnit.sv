// ============================================================================
// Unidad de Control de Branches (BranchUnit)
// ============================================================================
// Evalúa las condiciones de los branches condicionales y jumps incondicionales.
// Compara dos operandos según el tipo de operación especificada en BrOp y
// genera la señal NextPCSrc que indica si se debe tomar el salto.
//
// Operaciones soportadas:
//   - BEQ:  Igual (RURs1 == RURs2)
//   - BNE:  No igual (RURs1 != RURs2)
//   - BLT:  Menor que con signo (RURs1 < RURs2)
//   - BGE:  Mayor o igual con signo (RURs1 >= RURs2)
//   - BLTU: Menor que sin signo
//   - BGEU: Mayor o igual sin signo
//   - JAL/JALR: Saltos incondicionales (BrOp[4] = 1)
// ============================================================================

module BranchUnit (
    input  logic signed [31:0] RURs1,   // Valor del registro fuente 1 (después de forwarding)
    input  logic signed [31:0] RURs2,   // Valor del registro fuente 2 (después de forwarding)
    input  logic        [ 4:0] BrOp,    // Código de operación de branch
    output logic               NextPCSrc // 1 si se toma el salto, 0 si no
);

  always @* begin
    if (BrOp[4] == 1) 
      // Salto incondicional: JAL o JALR (bit 4 = 1)
      NextPCSrc = 1;
    else if (BrOp[4:3] == 2'b00) 
      // No es un branch: instrucción que no es de control de flujo
      NextPCSrc = 0;
    else begin
      // Branch condicional: evaluar condición según funct3
      case (BrOp[2:0])
        3'b000:  NextPCSrc = (RURs1 == RURs2);                          // BEQ: igual
        3'b001:  NextPCSrc = (RURs1 != RURs2);                          // BNE: no igual
        3'b100:  NextPCSrc = (RURs1 < RURs2);                           // BLT: menor (con signo)
        3'b101:  NextPCSrc = (RURs1 >= RURs2);                          // BGE: mayor o igual (con signo)
        3'b110:  NextPCSrc = ($unsigned(RURs1) < $unsigned(RURs2));    // BLTU: menor (sin signo)
        3'b111:  NextPCSrc = ($unsigned(RURs1) >= $unsigned(RURs2));   // BGEU: mayor o igual (sin signo)
        default: NextPCSrc = 0;                                         // Por defecto: no tomar salto
      endcase
    end
  end

endmodule
