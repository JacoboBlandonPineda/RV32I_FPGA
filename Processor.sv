// ============================================================================
// Módulo Principal: Processor
// ============================================================================
// Este módulo implementa un procesador RISC-V de 32 bits con pipeline de 5
// etapas: Fetch (IF), Decode (ID), Execute (EX), Memory (ME) y Writeback (WB).
// Incluye soporte para periféricos de E/S: teclado PS/2 y controlador VGA.
// 
// Características principales:
//   - Pipeline con forwarding y hazard detection
//   - Memoria de datos e instrucciones separadas
//   - Mapeo de memoria para periféricos (teclado en 0xFFFF0000, VGA en 0xFFFF0004)
//   - Controlador VGA para salida de video RGB332
// ============================================================================

module Processor (
    input  logic       clk,
    input  logic       ps2_clk,
    input  logic       ps2_data,
    input  logic [3:0] buttons,      // 4 botones para seleccionar colores
    output logic [2:0] red,
    output logic [2:0] green,
    output logic [1:0] blue,
    output logic       h_sync,
    output logic       v_sync,
	 output logic [7:0] leds,
    output logic       clk_25MHz
);

    // Color actual para VGA (no utilizado actualmente)
    logic [7:0] current_color = 8'h00;
    
    // Color seleccionado por botones (formato RGB332)
    // Inicializado a 0 para indicar que no se ha presionado ningún botón
    logic [7:0] button_color = 8'h00;
    logic button_color_active = 1'b0;  // Indica si se ha presionado algún botón
    
    // Registros para detección de flancos de botones
    logic [3:0] buttons_prev = 4'b0;
    logic [3:0] buttons_edge = 4'b0;

    // Señales del periférico de teclado
    logic [31:0] KBDData;

    // Señales de control para hazard detection y forwarding
    logic        HDUStall;        // Stall del pipeline por hazard de datos
    logic [4:0]  rd_ex, rs1_de, rs2_de;  // Registros destino y fuente
    logic        DMRd_ex;         // Señal de lectura de memoria en etapa EX

    // ========== ETAPA DECODE (ID) ==========
    // Señales del pipeline entre Fetch y Decode
    logic [31:0] PC_fe, PC_de, PCInc_fe, PCInc_de;  // PC y PC+4
    logic [31:0] Inst_fe, Inst_de;                   // Instrucción actual
    // Campos de la instrucción decodificados
    logic [6:0]  OpCode_de;      // Opcode de la instrucción (bits 6:0)
    logic [2:0]  Funct3_de;      // Campo funct3 (bits 14:12)
    logic [6:0]  Funct7_de;      // Campo funct7 (bits 31:25)
    logic [4:0]  rd_de;          // Registro destino (bits 11:7)
    // Valores leídos del banco de registros
    logic [31:0] RUrs1_de, RUrs2_de;
    // Inmediato extendido y señales de control
    logic [31:0] ImmExt_de;
    logic [1:0]  ImmSrc_de;      // Tipo de extensión de inmediato
    logic        ALUASrc_de, ALUBSrc_de;  // Selectores de operandos ALU
    logic        DMWr_de, DMRd_de, RUWr_de;  // Control de escritura/lectura
    logic [1:0]  RUDataWrSrc_de; // Origen de datos para escritura en registros
    logic [1:0]  DMCtrl_de;      // Control de tamaño de acceso a memoria
    logic [3:0]  ALUOp_de;       // Operación de la ALU
    logic [2:0]  BrOp_de;        // Operación de branch

    // ========== ETAPA EXECUTE (EX) ==========
    // Señales de control propagadas desde ID
    logic        ALUASrc_ex, ALUBSrc_ex;
    logic [3:0]  ALUOp_ex;
    logic [2:0]  BrOp_ex;
    logic        DMWr_ex;
    logic [1:0]  DMCtrl_ex, RUDataWrSrc_ex;
    logic        RUWr_ex;
    // Datos propagados desde ID
    logic [31:0] PC_ex, PCInc_ex;
    logic [31:0] RUrs1_ex, RUrs2_ex, ImmExt_ex;
    logic [4:0]  rs1_ex, rs2_ex;  // IDs de registros fuente

    // ========== ETAPA MEMORY (ME) ==========
    // Señales de control para acceso a memoria
    logic        DMWr_me;
    logic [1:0]  DMCtrl_me, RUDataWrSrc_me;
    logic        RUWr_me;
    // Datos: resultado ALU, PC+4, datos a escribir, y registro destino
    logic [31:0] PCInc_me, ALURes_me, RUrs2_me;
    logic [4:0]  rd_me;

    // ========== ETAPA WRITEBACK (WB) ==========
    // Señales de control finales
    logic [1:0]  RUDataWrSrc_wb;
    logic        RUWr_wb;
    // Datos disponibles para escritura en registros
    logic [31:0] PCInc_wb, DMDataRd_wb, ALURes_wb;
    logic [4:0]  rd_wb;

    // Datos unificados para escritura en banco de registros
    logic [31:0] RUDataWr_wb;

    // ========== FORWARDING ==========
    // Unidad de forwarding para evitar stalls por dependencias de datos
    logic [1:0] FUASrc, FUBSrc;  // Selectores de forwarding para operandos A y B
    logic [31:0] ALURes_ex;       // Resultado ALU en etapa EX (para forwarding)
    logic [31:0] FUA, FUB, ALUA, ALUB;  // Operandos después de forwarding y selección

    // ========== CONTROL DE FLUJO ==========
    logic NextPCSrc;      // Señal para tomar branch/jump
    logic [31:0] NextPC;  // Siguiente dirección de PC

    // ========== ETAPA FETCH (IF) ==========
    // Cálculo de PC+4 para instrucciones secuenciales
    assign PCInc_fe = PC_fe + 4;
    
    // Actualización del PC: se mantiene si hay stall, sino toma NextPC
    always_ff @(posedge clk) begin
        if (HDUStall)
            PC_fe <= PC_fe;  // Stall: mantener PC actual
        else
            PC_fe <= NextPC;  // Actualizar con siguiente dirección
    end

    // Memoria de instrucciones: lee la instrucción en la dirección PC
    InstructionMemory InstructionMemory1 (
        .Address(PC_fe),
        .Instruction(Inst_fe)
    );

    // ========== ETAPA DECODE (ID) ==========
    // Extracción de campos de la instrucción según formato RISC-V
    assign OpCode_de = Inst_de[6:0];    // Opcode (7 bits)
    assign Funct3_de = Inst_de[14:12];  // Funct3 para ALU y memoria
    assign Funct7_de = Inst_de[31:25];  // Funct7 para operaciones ALU
    assign rd_de     = Inst_de[11:7];   // Registro destino (5 bits)
    assign rs1_de    = Inst_de[19:15];  // Registro fuente 1 (5 bits)
    assign rs2_de    = Inst_de[24:20];  // Registro fuente 2 (5 bits)

    // Registro de pipeline IF/ID: propaga datos de IF a ID
    // En caso de branch/jump: inserta NOP (instrucción 0)
    // En caso de stall: mantiene valores actuales
    always_ff @(posedge clk) begin
        if (NextPCSrc) begin
            // Branch tomado: insertar burbuja (NOP)
            PC_de    <= 0;
            PCInc_de <= 0;
            Inst_de  <= 0;
        end else if (HDUStall) begin
            // Stall: mantener valores actuales
            PC_de    <= PC_de;
            PCInc_de <= PCInc_de;
            Inst_de  <= Inst_de;
        end else begin
            // Flujo normal: propagar datos
            PC_de    <= PC_fe;
            PCInc_de <= PCInc_fe;
            Inst_de  <= Inst_fe;
        end
    end

    // Unidad de Control: genera todas las señales de control según el tipo de instrucción
    ControlUnit ControlUnit1 (
        .OpCode(OpCode_de),
        .Funct3(Funct3_de),
        .Funct7(Funct7_de),
        .ImmSrc(ImmSrc_de),
        .ALUASrc(ALUASrc_de),
        .ALUBSrc(ALUBSrc_de),
        .DMWr(DMWr_de),
        .DMRd(DMRd_de),
        .RUWr(RUWr_de),
        .RUDataWrSrc(RUDataWrSrc_de),
        .DMCtrl(DMCtrl_de),
        .ALUOp(ALUOp_de),
        .BrOp(BrOp_de)
    );

    // Banco de Registros: 32 registros de 32 bits, x0 siempre es 0
    RegisterUnit RegisterUnit1 (
        .clk(clk),
        .rs1(rs1_de),
        .rs2(rs2_de),
        .RUrs1(RUrs1_de),
        .RUrs2(RUrs2_de),
        .RUWr(RUWr_wb),          // Escritura desde etapa WB
        .RUDataWr(RUDataWr_wb),  // Datos desde etapa WB
        .rd(rd_wb)               // Destino desde etapa WB
    );

    // Extensión de Inmediatos: extiende signo según el tipo de instrucción (I, S, B, U, J)
    ImmediateUnit ImmediateUnit1 (
        .VecImm(Inst_de[24:0]),  // Bits del inmediato según formato
        .ImmSrc(ImmSrc_de),      // Tipo de extensión
        .ImmExt(ImmExt_de)       // Inmediato extendido a 32 bits
    );

    // Unidad de Detección de Hazards: detecta stalls cuando un load está en EX
    // y la siguiente instrucción necesita sus datos
    HazardDetectionUnit HazardDetectionUnit1 (
        .DMRd_ex(DMRd_ex),
        .rd_ex(rd_ex),
        .rs1_de(rs1_de),
        .rs2_de(rs2_de),
        .HDUStall(HDUStall)
    );

    // ========== ETAPA EXECUTE (EX) ==========
    // Unidad de Forwarding: determina de dónde tomar los operandos si hay dependencias
    ForwardingUnit ForwardingUnit1 (
        .RUWr_me(RUWr_me),
        .rd_me(rd_me),
        .RUWr_wb(RUWr_wb),
        .rd_wb(rd_wb),
        .rs1_ex(rs1_ex),
        .rs2_ex(rs2_ex),
        .FUASrc(FUASrc),  // Selector: 00=reg, 10=ME, 11=WB
        .FUBSrc(FUBSrc)   // Selector: 00=reg, 10=ME, 11=WB
    );

    // Multiplexores de Forwarding: seleccionan operandos desde ME, WB o registros
    assign FUA = (FUASrc == 2'b10) ? ALURes_me :      // Forwarding desde ME
                 (FUASrc == 2'b11) ? RUDataWr_wb :    // Forwarding desde WB
                 RUrs1_ex;                            // Valor normal del registro

    assign FUB = (FUBSrc == 2'b10) ? ALURes_me :      // Forwarding desde ME
                 (FUBSrc == 2'b11) ? RUDataWr_wb :    // Forwarding desde WB
                 RUrs2_ex;                            // Valor normal del registro

    // Multiplexores de selección de operandos ALU: PC o registro, inmediato o registro
    assign ALUA = ALUASrc_ex ? PC_ex : FUA;      // Para AUIPC: usar PC, sino registro
    assign ALUB = ALUBSrc_ex ? ImmExt_ex : FUB;  // Para I-type: usar inmediato, sino registro

    // Unidad Aritmético-Lógica: ejecuta operaciones aritméticas y lógicas
    alu Alu1 (
        .A(ALUA),
        .B(ALUB),
        .ALUOp(ALUOp_ex),
        .ALURes(ALURes_ex)
    );

    // Unidad de Branch: evalúa condiciones de salto (BEQ, BNE, BLT, BGE, etc.)
    BranchUnit BranchUnit1 (
        .RURs1(FUA),
        .RURs2(FUB),
        .BrOp(BrOp_ex),
        .NextPCSrc(NextPCSrc)  // 1 si se toma el branch/jump
    );

    // Selección del siguiente PC: branch/jump (dirección calculada) o secuencial (PC+4)
    assign NextPC = (NextPCSrc) ? ALURes_ex : PCInc_fe;

    // Pipeline registers (EX stage)
    always_ff @(posedge clk) begin
        if (NextPCSrc || HDUStall) begin
            ALUASrc_ex     <= 0;
            ALUBSrc_ex     <= 0;
            ALUOp_ex       <= 0;
            BrOp_ex        <= 0;
            DMWr_ex        <= 0;
            DMCtrl_ex      <= 0;
            RUDataWrSrc_ex <= 0;
            RUWr_ex        <= 0;
        end else begin
            ALUASrc_ex     <= ALUASrc_de;
            ALUBSrc_ex     <= ALUBSrc_de;
            ALUOp_ex       <= ALUOp_de;
            BrOp_ex        <= BrOp_de;
            DMWr_ex        <= DMWr_de;
            DMCtrl_ex      <= DMCtrl_de;
            RUDataWrSrc_ex <= RUDataWrSrc_de;
            RUWr_ex        <= RUWr_de;
        end

        PC_ex     <= PC_de;
        PCInc_ex  <= PCInc_de;
        RUrs1_ex  <= RUrs1_de;
        RUrs2_ex  <= RUrs2_de;
        ImmExt_ex <= ImmExt_de;
        rs1_ex    <= rs1_de;
        rs2_ex    <= rs2_de;
        rd_ex     <= rd_de;      // Registro destino para hazard detection y forwarding
        DMRd_ex   <= DMRd_de;    // Señal de lectura de memoria para hazard detection
    end

    // Registros de pipeline EX/ME: propagan datos de EX a ME
    always_ff @(posedge clk) begin
        // Señales de control para acceso a memoria
        DMWr_me        <= DMWr_ex;
        DMCtrl_me      <= DMCtrl_ex;
        RUDataWrSrc_me <= RUDataWrSrc_ex;
        RUWr_me        <= RUWr_ex;

        // Datos: resultado ALU, datos a escribir, PC+4, y registro destino
        PCInc_me  <= PCInc_ex;
        ALURes_me <= ALURes_ex;  // Dirección para memoria o resultado ALU
        RUrs2_me  <= RUrs2_ex;   // Datos a escribir en memoria
        rd_me     <= rd_ex;
    end

    // Registros de pipeline ME/WB: propagan datos de ME a WB
    always_ff @(posedge clk) begin
        RUDataWrSrc_wb <= RUDataWrSrc_me;
        RUWr_wb        <= RUWr_me;
        PCInc_wb       <= PCInc_me;
        ALURes_wb      <= ALURes_me;
        rd_wb          <= rd_me;
    end

    // ========== PERIFÉRICOS Y MEMORIA ==========
    // Controlador de Teclado PS/2: mapeado en dirección 0xFFFF0000
    // Lee el código de tecla cuando se accede a esta dirección
    KBControllerMem KB (
        .clk(clk),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .MemRead(DMRd_me),
        .Address(ALURes_me),
		  .leds(leds),  // Muestra el keycode en LEDs
        .DataOut(KBDData)
    );

    // Memoria de Datos: memoria principal del sistema
    logic [31:0] DMDataRd_me_internal;
    DataMemory DataMemory1 (
        .clk(clk),
        .DMWr(DMWr_me),
        .DMCtrl(DMCtrl_me),      // Control de tamaño (byte, halfword, word)
        .Address(ALURes_me),
        .DataWr(RUrs2_me),
        .DataRd(DMDataRd_me_internal)
    );

    // Multiplexor de lectura: selecciona entre memoria de datos o periférico
    assign DMDataRd_wb = (ALURes_me == 32'hFFFF0000) ? KBDData : DMDataRd_me_internal;

    // Multiplexor de escritura en registros: selecciona fuente de datos
    // 00: Resultado ALU (R-type, I-type)
    // 01: Datos de memoria (Load)
    // 10: PC+4 (JAL, JALR)
    assign RUDataWr_wb = (RUDataWrSrc_wb == 2'b01) ? DMDataRd_wb :
                         (RUDataWrSrc_wb == 2'b10) ? PCInc_wb :
                         (RUDataWrSrc_wb == 2'b00) ? ALURes_wb : 32'b0;
								 
    // ========== DETECCIÓN DE FLANCOS DE BOTONES ==========
    // Detectar cuando se presiona un botón
    // Asumiendo que los botones están activos en bajo (0 = presionado, típico en FPGAs)
    // Detectar flanco descendente: cuando buttons pasa de 1 a 0
    always_ff @(posedge clk) begin
        buttons_prev <= buttons;  // Guardar estado anterior
    end
    
    // Detectar flancos descendentes (cuando se presiona el botón: 1->0)
    assign buttons_edge = buttons_prev & ~buttons;
    
    // ========== SELECCIÓN DE COLOR POR BOTONES ==========
    // Colores en formato RGB332:
    //   Botón 0: Rojo    = 11100000 = 0xE0 (RRRGGGBB = 111 000 00)
    //   Botón 1: Verde   = 00011100 = 0x1C (RRRGGGBB = 000 111 00)
    //   Botón 2: Azul    = 00000011 = 0x03 (RRRGGGBB = 000 000 11)
    //   Botón 3: Blanco  = 11111111 = 0xFF (RRRGGGBB = 111 111 11)
    always_ff @(posedge clk) begin
        if (buttons_edge[0]) begin      // Botón 0 presionado -> Rojo
            button_color <= 8'hE0;
            button_color_active <= 1'b1;
        end else if (buttons_edge[1]) begin  // Botón 1 presionado -> Verde
            button_color <= 8'h1C;
            button_color_active <= 1'b1;
        end else if (buttons_edge[2]) begin  // Botón 2 presionado -> Azul
            button_color <= 8'h03;
            button_color_active <= 1'b1;
        end else if (buttons_edge[3]) begin  // Botón 3 presionado -> Blanco
            button_color <= 8'hFF;
            button_color_active <= 1'b1;
        end
        // Si no se presiona ningún botón, mantener el color actual (persistente)
    end

    // ========== PERIFÉRICO VGA ==========
    // Escribir color en registro VGA (mapeado en 0xFFFF0004)
    always_ff @(posedge clk) begin
        if (DMWr_me && ALURes_me == 32'hFFFF0004)
            current_color <= RUrs2_me[7:0];
    end

    // Controlador VGA: genera señales de sincronización y color RGB332
    // Prioridad: botones (si se ha presionado alguno) > keycode
    VGAController vga (
        .clk(clk),
        .pixel_data(button_color_active ? button_color : leds),  // Usar color de botones si está activo, sino keycode
        .red(red),
        .green(green),
        .blue(blue),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .clk_25MHz(clk_25MHz)  // Clock de 25 MHz para VGA
    );

endmodule