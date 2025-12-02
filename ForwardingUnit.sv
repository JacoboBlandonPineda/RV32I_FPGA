// ============================================================================
// Unidad de Forwarding (ForwardingUnit)
// ============================================================================
// Detecta dependencias de datos (data hazards) entre instrucciones en el
// pipeline y determina si es necesario hacer forwarding desde las etapas ME
// o WB para evitar stalls. Esto mejora el rendimiento al permitir que las
// instrucciones utilicen resultados antes de que se escriban en el banco de
// registros.
//
// Prioridad de forwarding:
//   1. Forwarding desde ME (etapa de memoria): si el registro destino de ME
//      coincide con rs1 o rs2 de EX, usar el resultado ALU de ME
//   2. Forwarding desde WB (etapa de writeback): si no hay forwarding desde ME
//      y el registro destino de WB coincide, usar los datos de WB
//   3. Sin forwarding: usar valores normales del banco de registros
// ============================================================================

module ForwardingUnit (
    input  logic       RUWr_me,  // Habilitación de escritura en etapa ME
    input  logic [4:0] rd_me,     // Registro destino en etapa ME
    input  logic       RUWr_wb,  // Habilitación de escritura en etapa WB
    input  logic [4:0] rd_wb,     // Registro destino en etapa WB
    input  logic [4:0] rs1_ex,    // Registro fuente 1 en etapa EX
    input  logic [4:0] rs2_ex,    // Registro fuente 2 en etapa EX
    output logic [1:0] FUASrc,    // Selector de forwarding para operando A: 00=reg, 10=ME, 11=WB
    output logic [1:0] FUBSrc     // Selector de forwarding para operando B: 00=reg, 10=ME, 11=WB
);

  always_comb begin
    // ========== FORWARDING PARA OPERANDO A (rs1) ==========
    // Prioridad: ME tiene precedencia sobre WB
    if (RUWr_me && (rd_me == rs1_ex))
      FUASrc = 2'b10;  // Forwarding desde ME (resultado ALU)
    else if (RUWr_wb && (rd_wb == rs1_ex))
      FUASrc = 2'b11;  // Forwarding desde WB (datos escritos)
    else
      FUASrc = 2'b00;  // Sin forwarding: usar valor del banco de registros

    // ========== FORWARDING PARA OPERANDO B (rs2) ==========
    // Misma lógica que para rs1
    if (RUWr_me && (rd_me == rs2_ex))
      FUBSrc = 2'b10;  // Forwarding desde ME
    else if (RUWr_wb && (rd_wb == rs2_ex))
      FUBSrc = 2'b11;  // Forwarding desde WB
    else
      FUBSrc = 2'b00;  // Sin forwarding: usar valor del banco de registros
  end

endmodule
