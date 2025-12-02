module PC (
    input  logic        clk,
    input  logic [31:0] NextPC,
    output logic [31:0] Address = 0
);

  always @(posedge clk) begin
    Address <= NextPC;
  end

endmodule
