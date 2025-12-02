// ============================================================================
// Unidad de Control (ControlUnit)
// ============================================================================
// Genera todas las señales de control necesarias para el procesador según el
// tipo de instrucción RISC-V decodificada. Analiza el OpCode, Funct3 y Funct7
// para determinar qué operación realizar y configurar el datapath adecuadamente.
//
// Tipos de instrucciones soportadas:
//   - R-type: Operaciones aritméticas/lógicas con registros (ADD, SUB, AND, OR, etc.)
//   - I-type: Operaciones inmediatas y loads (ADDI, ANDI, LB, LH, LW, etc.)
//   - S-type: Store instructions (SB, SH, SW)
//   - B-type: Branch condicional (BEQ, BNE, BLT, BGE, etc.)
//   - J-type: Jump and Link (JAL)
//   - U-type: Load Upper Immediate y Add Upper Immediate to PC (LUI, AUIPC)
// ============================================================================

module ControlUnit (
    input logic [6:0] OpCode,    // Opcode de la instrucción (bits 6:0)
    input logic [6:0] Funct7,    // Campo funct7 (bits 31:25) para ALU
    input logic [2:0] Funct3,    // Campo funct3 (bits 14:12) para ALU y memoria

    // Señales de control de la ALU
    output logic       ALUASrc,  // 0: registro, 1: PC (para AUIPC)
    output logic       ALUBSrc,  // 0: registro, 1: inmediato
    output logic [3:0] ALUOp,    // Operación de la ALU (ADD, SUB, AND, OR, etc.)
    
    // Señales de control de memoria
    output logic       DMWr,     // Habilitar escritura en memoria de datos
    output logic       DMRd,     // Habilitar lectura de memoria de datos
    output logic [2:0] DMCtrl,   // Tipo de acceso: byte, halfword, word (con/sin signo)
    
    // Señales de control del banco de registros
    output logic       RUWr,            // Habilitar escritura en banco de registros
    output logic [1:0] RUDataWrSrc,     // Fuente: 00=ALU, 01=Memoria, 10=PC+4
    
    // Control de inmediatos y branches
    output logic [2:0] ImmSrc,   // Tipo de extensión de inmediato (I, S, B, U, J)
    output logic [4:0] BrOp      // Operación de branch (BEQ, BNE, BLT, BGE, etc.)
);

  // Lógica combinacional: genera señales de control según el opcode
  always @* begin
    // ========== VALORES POR DEFECTO ==========
    // Todas las señales inicializadas para evitar latches
    ALUASrc     = 0;
    ALUBSrc     = 0;
    DMWr        = 0;
    DMRd        = 0;   // Por defecto no se lee memoria
    RUWr        = 0;
    RUDataWrSrc = 2'b00;  // Por defecto: resultado de ALU
    ImmSrc      = 3'b000;
    DMCtrl      = 3'b000;
    ALUOp       = 4'b0000;
    BrOp        = 5'b00000;

    // ========== DECODIFICACIÓN POR OPCODE ==========
    case (OpCode)
      7'b0110011: begin  // R-type: ADD, SUB, AND, OR, XOR, SLT, SLL, SRL, SRA
        // Operaciones aritméticas/lógicas entre registros
        ALUASrc = 0;     // Operando A desde registro
        ALUBSrc = 0;     // Operando B desde registro
        ImmSrc  = 3'b000; // No se usa inmediato
        ALUOp   = {Funct7[5], Funct3};  // {funct7[5], funct3} determina la operación
        RUWr    = 1;     // Escribir resultado en registro destino
      end

      7'b0010011: begin  // I-type: ADDI, ANDI, ORI, XORI, SLTI, SLLI, SRLI, SRAI
        // Operaciones inmediatas (registro + inmediato)
        ALUASrc = 0;     // Operando A desde registro
        ALUBSrc = 1;     // Operando B desde inmediato
        ImmSrc  = 3'b000; // Extensión I-type (bits 31:20)
        // Para SRLI/SRAI necesitamos funct7[5], para otros solo funct3
        ALUOp   = (Funct3 == 3'b101) ? {Funct7[5], Funct3} : {1'b0, Funct3};
        RUWr    = 1;     // Escribir resultado en registro destino
      end

      7'b0000011: begin  // Load: LB, LH, LW, LBU, LHU
        // Instrucciones de carga desde memoria
        ALUASrc     = 0;     // Dirección base desde registro (rs1)
        ALUBSrc     = 1;     // Offset desde inmediato
        ImmSrc      = 3'b000; // Extensión I-type
        ALUOp       = 4'b0000; // ADD para calcular dirección efectiva
        DMCtrl      = Funct3;  // 000=LB, 001=LH, 010=LW, 100=LBU, 101=LHU
        RUDataWrSrc = 2'b01;  // Escribir datos leídos de memoria
        RUWr        = 1;      // Escribir en registro destino
        DMRd        = 1;      // Activa lectura de memoria
      end

      7'b0100011: begin  // S-type: SB, SH, SW
        // Instrucciones de almacenamiento en memoria
        ALUASrc = 0;     // Dirección base desde registro (rs1)
        ALUBSrc = 1;     // Offset desde inmediato
        ImmSrc  = 3'b001; // Extensión S-type (bits 31:25, 11:7)
        ALUOp   = 4'b0000; // ADD para calcular dirección efectiva
        DMWr    = 1;     // Habilitar escritura en memoria
        DMCtrl  = Funct3;  // 000=SB, 001=SH, 010=SW
        DMRd    = 0;      // No lectura en store
      end

      7'b1100011: begin  // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
        // Branches condicionales
        ALUASrc = 1;     // PC como operando A (para calcular PC+offset)
        ALUBSrc = 1;     // Offset desde inmediato
        ImmSrc  = 3'b101; // Extensión B-type (bits 31, 7, 30:25, 11:8)
        ALUOp   = 4'b0000; // ADD para calcular dirección de branch
        BrOp    = {2'b01, Funct3};  // 01xxx para branches condicionales
        DMRd    = 0;
      end

      7'b1101111: begin  // J-type: JAL (Jump and Link)
        // Salto incondicional con guardar dirección de retorno
        ALUASrc     = 1;     // PC como operando A
        ALUBSrc     = 1;     // Offset desde inmediato
        ImmSrc      = 3'b110; // Extensión J-type (bits 31, 19:12, 20, 30:21)
        ALUOp       = 4'b0000; // ADD para calcular dirección de salto
        RUDataWrSrc = 2'b10;  // Escribir PC+4 en registro destino (rd)
        RUWr        = 1;      // Guardar dirección de retorno
        BrOp        = 5'b10000; // Salto incondicional
        DMRd        = 0;
      end

      7'b1100111: begin  // JALR (Jump and Link Register)
        // Salto a dirección en registro + offset
        ALUASrc     = 0;     // Dirección base desde registro (rs1)
        ALUBSrc     = 1;     // Offset desde inmediato
        ImmSrc      = 3'b000; // Extensión I-type
        ALUOp       = 4'b0000; // ADD para calcular dirección de salto
        RUDataWrSrc = 2'b10;  // Escribir PC+4 en registro destino
        RUWr        = 1;      // Guardar dirección de retorno
        BrOp        = 5'b10000; // Salto incondicional
        DMRd        = 0;
      end

      7'b0110111: begin  // LUI (Load Upper Immediate)
        // Carga inmediato de 20 bits en los bits superiores del registro
        ALUASrc = 0;     // No se usa (pero se necesita para consistencia)
        ALUBSrc = 1;     // Inmediato como operando
        ImmSrc  = 3'b010; // Extensión U-type (bits 31:12)
        ALUOp   = 4'b1001; // Operación especial: pasar B directamente
        RUWr    = 1;     // Escribir en registro destino
        DMRd    = 0;
      end

      7'b0010111: begin  // AUIPC (Add Upper Immediate to PC)
        // Suma PC + (inmediato << 12)
        ALUASrc = 1;     // PC como operando A
        ALUBSrc = 1;     // Inmediato desplazado como operando B
        ImmSrc  = 3'b010; // Extensión U-type
        ALUOp   = 4'b0000; // ADD
        RUWr    = 1;     // Escribir resultado en registro destino
        DMRd    = 0;
      end

      default: begin
        // Opcodes no reconocidos: mantener valores por defecto
        // Esto puede ocurrir con instrucciones no implementadas o inválidas
        DMRd = 0;
      end
    endcase
  end

endmodule

