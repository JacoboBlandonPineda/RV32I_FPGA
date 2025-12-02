// ============================================================================
// Unidad de Extensión de Inmediatos (ImmediateUnit)
// ============================================================================
// Extiende el campo inmediato de la instrucción a 32 bits según el tipo
// de formato de instrucción RISC-V. Diferentes tipos de instrucciones
// tienen el inmediato distribuido en diferentes bits de la instrucción.
//
// Formatos soportados:
//   - I-type: Instrucciones inmediatas y loads (bits 31:20)
//   - S-type: Stores (bits 31:25, 11:7)
//   - B-type: Branches (bits 31, 7, 30:25, 11:8)
//   - U-type: LUI y AUIPC (bits 31:12)
//   - J-type: JAL (bits 31, 19:12, 20, 30:21)
// ============================================================================

module ImmediateUnit (
    input  logic [24:0] VecImm,   // Bits del inmediato extraídos de la instrucción
    input  logic [2:0] ImmSrc,    // Tipo de extensión (I, S, B, U, J)
    output logic [31:0] ImmExt    // Inmediato extendido a 32 bits con signo
);

  always @* begin
    case (ImmSrc)
      3'b000: // I-type: ADDI, ANDI, ORI, XORI, SLTI, SLLI, SRLI, SRAI, LB, LH, LW, etc.
        // Extiende signo: bits 31:20 de la instrucción
        ImmExt = {{21{VecImm[24]}}, VecImm[23:13]};

      3'b001: // S-type: SB, SH, SW
        // Extiende signo: bits 31:25 (inm[11:5]) y bits 11:7 (inm[4:0])
        ImmExt = {{21{VecImm[24]}}, VecImm[23:18], VecImm[4:0]};

      3'b101: // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
        // Extiende signo y desplaza a la izquierda 1 bit: bits 31, 7, 30:25, 11:8
        // El bit menos significativo siempre es 0 (direcciones pares)
        ImmExt = {{19{VecImm[24]}}, VecImm[0], VecImm[23:18], VecImm[4:1], 1'b0};

      3'b010: // U-type: LUI, AUIPC
        // Sin extensión de signo, solo desplaza a la izquierda 12 bits
        // Los bits inferiores se rellenan con ceros
        ImmExt = {VecImm[24:5], 12'b0};

      3'b110: // J-type: JAL
        // Extiende signo y desplaza a la izquierda 1 bit: bits 31, 19:12, 20, 30:21
        // El bit menos significativo siempre es 0 (direcciones pares)
        ImmExt = {{11{VecImm[24]}}, VecImm[12:5], VecImm[13], VecImm[23:14], 1'b0};

      default: ImmExt = 32'b0;  // Valor por defecto si el tipo no es reconocido
    endcase
  end

endmodule
