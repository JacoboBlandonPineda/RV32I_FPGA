// ============================================================================
// Memoria de Datos (DataMemory)
// ============================================================================
// Implementa la memoria de datos del procesador con capacidad de 1KB (256 palabras).
// Soporta diferentes tamaños de acceso: byte (8 bits), halfword (16 bits) y word (32 bits),
// tanto con signo (LB, LH, LW) como sin signo (LBU, LHU).
//
// Organización: 4 bancos de memoria de bytes para permitir acceso a diferentes alineaciones.
//   - mem0: Bytes en posiciones 0, 4, 8, ... (múltiplos de 4)
//   - mem1: Bytes en posiciones 1, 5, 9, ...
//   - mem2: Bytes en posiciones 2, 6, 10, ...
//   - mem3: Bytes en posiciones 3, 7, 11, ...
// ============================================================================

module DataMemory (
    input  logic        clk,        // Reloj del sistema
    input  logic        DMWr,       // Habilitar escritura (write enable)
    input  logic [ 2:0] DMCtrl,     // Control: 000=SB/LB, 001=SH/LH, 010=SW/LW, 100=LBU, 101=LHU
    input  logic [31:0] Address,    // Dirección de memoria (solo se usan bits [7:0])
    input  logic [31:0] DataWr,     // Dato a escribir
    output logic [31:0] DataRd      // Dato leído
);

  // Cuatro bancos de memoria de bytes (256 bytes cada uno = 1KB total)
  logic [7:0] mem0[255:0]; // byte 0 (posiciones alineadas)
  logic [7:0] mem1[255:0]; // byte 1
  logic [7:0] mem2[255:0]; // byte 2
  logic [7:0] mem3[255:0]; // byte 3

  // Dirección de byte (solo se usan los 8 bits menos significativos)
  wire [7:0] addr = Address[7:0];

  // ========== ESCRITURA (SÍNCRONA) ==========
  // Las escrituras ocurren en el flanco de subida del reloj
  always_ff @(posedge clk) begin
    if (DMWr) begin
      case (DMCtrl)
        3'b000: begin // SB (Store Byte): Escribe 1 byte
          // Selecciona el banco según la alineación (bits [1:0] de Address)
          case (Address[1:0])
            2'b00: mem0[addr] <= DataWr[7:0];
            2'b01: mem1[addr] <= DataWr[7:0];
            2'b10: mem2[addr] <= DataWr[7:0];
            2'b11: mem3[addr] <= DataWr[7:0];
          endcase
        end

        3'b001: begin // SH (Store Halfword): Escribe 2 bytes consecutivos
          mem0[addr] <= DataWr[7:0];
          mem1[addr] <= DataWr[15:8];
        end

        3'b010: begin // SW (Store Word): Escribe 4 bytes (palabra completa)
          // Orden little-endian: byte menos significativo en menor dirección
          mem0[addr] <= DataWr[7:0];
          mem1[addr] <= DataWr[15:8];
          mem2[addr] <= DataWr[23:16];
          mem3[addr] <= DataWr[31:24];
        end
      endcase
    end
  end

  // ========== LECTURA (COMBINACIONAL) ==========
  // Las lecturas son asíncronas: el dato está disponible inmediatamente
  always_comb begin
    case (DMCtrl)
      3'b000: begin // LB (Load Byte): Lee 1 byte con extensión de signo
        case (Address[1:0])
          2'b00: DataRd = {{24{mem0[addr][7]}}, mem0[addr]};  // Extiende signo
          2'b01: DataRd = {{24{mem1[addr][7]}}, mem1[addr]};
          2'b10: DataRd = {{24{mem2[addr][7]}}, mem2[addr]};
          2'b11: DataRd = {{24{mem3[addr][7]}}, mem3[addr]};
        endcase
      end

      3'b001: // LH (Load Halfword): Lee 2 bytes con extensión de signo
        DataRd = {{16{mem1[addr][7]}}, mem1[addr], mem0[addr]};
      
      3'b010: // LW (Load Word): Lee 4 bytes (palabra completa)
        DataRd = {mem3[addr], mem2[addr], mem1[addr], mem0[addr]};
      
      3'b100: begin // LBU (Load Byte Unsigned): Lee 1 byte sin extensión de signo
        case (Address[1:0])
          2'b00: DataRd = {24'b0, mem0[addr]};  // Rellena con ceros
          2'b01: DataRd = {24'b0, mem1[addr]};
          2'b10: DataRd = {24'b0, mem2[addr]};
          2'b11: DataRd = {24'b0, mem3[addr]};
        endcase
      end

      3'b101: // LHU (Load Halfword Unsigned): Lee 2 bytes sin extensión de signo
        DataRd = {16'b0, mem1[addr], mem0[addr]};
      
      default: DataRd = 32'b0;  // Valor por defecto
    endcase
  end

endmodule