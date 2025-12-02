// ============================================================================
// Unidad de Detección de Hazards (HazardDetectionUnit)
// ============================================================================
// Detecta dependencias de datos que requieren un stall del pipeline.
// Específicamente, detecta el caso de "load-use hazard": cuando una instrucción
// de carga (load) está en la etapa EX y la siguiente instrucción en ID necesita
// usar ese dato antes de que esté disponible en el banco de registros.
//
// En este caso, es necesario insertar una burbuja (bubble) en el pipeline:
//   - Mantener el PC en su valor actual (no avanza)
//   - Insertar un NOP en la etapa ID (instrucción 0)
//   - El forwarding no puede resolver este hazard porque el dato de memoria
//     no está disponible hasta la etapa ME
//
// El stall se mantiene por un ciclo, permitiendo que el load complete y el
// dato esté disponible en la siguiente instrucción.
// ============================================================================

module HazardDetectionUnit (
    input  logic       DMRd_ex,    // Señal de lectura de memoria en etapa EX
    input  logic [4:0] rd_ex,      // Registro destino de la instrucción en EX
    input  logic [4:0] rs1_de,     // Registro fuente 1 de la instrucción en ID
    input  logic [4:0] rs2_de,     // Registro fuente 2 de la instrucción en ID
    output logic       HDUStall    // 1 si se debe hacer stall, 0 en caso contrario
);

  // Detecta hazard cuando:
  //   - Hay una instrucción load en EX (DMRd_ex = 1)
  //   - El registro destino del load (rd_ex) coincide con rs1 o rs2 de la instrucción en ID
  assign HDUStall = (DMRd_ex && ((rd_ex == rs1_de) || (rd_ex == rs2_de)));

endmodule