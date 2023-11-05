///////////////////////////////////////////////////////////////////////////////
// Description:       Simple test bench for SPI Master and Slave modules
///////////////////////////////////////////////////////////////////////////////

module tb_spi_slave ();
  
  parameter SPI_MODE = 1; // CPOL = 0, CPHA = 1
  parameter SPI_CLK_DELAY = 20;  // 2.5 MHz
  parameter MAIN_CLK_DELAY = 2;  // 25 MHz

  logic w_CPOL; // clock polarity
  logic w_CPHA; // clock phase

  assign w_CPOL = (SPI_MODE == 2) | (SPI_MODE == 3);
  assign w_CPHA = (SPI_MODE == 1) | (SPI_MODE == 3);

  logic r_Rst_L     = 1'b0;

  logic [7:0] dataPayload[0:255]; 
  logic [7:0] dataLength;
  
  // CPOL=0, clock idles 0.  CPOL=1, clock idles 1
//  logic r_SPI_Clk   = w_CPOL ? 1'b1 : 1'b0;
  logic w_SPI_Clk   = 1'b0;
  logic r_SPI_En    = 1'b0;
  logic r_Clk       = 1'b0;
  logic w_SPI_CS_n;
  logic w_SPI_MOSI;
  logic w_SPI_MISO;
  logic SPIOE;


  // Slave Specific
  logic       w_Slave_RX_DV, r_Slave_TX_DV;
  logic [7:0] w_Slave_RX_Byte, r_Slave_TX_Byte;

  // Clock Generators:
  always #(MAIN_CLK_DELAY) r_Clk = ~r_Clk;
  always #(SPI_CLK_DELAY)  w_SPI_Clk = ~w_SPI_Clk;
  // Instantiate UUT
  SPI_Slave #(.SPI_MODE(SPI_MODE)) SPI_Slave_UUT
  (
   // Control/Data Signals,
   .i_Rst_L(r_Rst_L),      // FPGA Reset
   .i_Clk(r_Clk),          // FPGA Clock
   .o_RX_DV(r_Slave_TX_DV),      // Data Valid pulse (1 clock cycle)
   .o_RX_Byte(r_Slave_TX_Byte),  // Byte received on MOSI
   .i_TX_DV(w_Slave_RX_DV),      // Data Valid pulse
   .i_TX_Byte(w_Slave_RX_Byte),  // Byte to serialize to MISO (set up for loopback)

   // SPI Interface
   .i_SPI_Clk(w_SPI_Clk),
   .o_SPI_MISO(w_SPI_MISO),
   .i_SPI_MOSI(w_SPI_MOSI),
   .i_SPI_CS_n(w_SPI_CS_n),
   .SPIOE(SPIOE)
   );

    
  initial
    begin
      repeat(10) @(posedge r_Clk);
      r_Rst_L  = 1'b0;
      w_SPI_CS_n   = 1'b1;
      w_Slave_RX_DV = 1'b0;
      repeat(10) @(posedge r_Clk);
      r_Rst_L          = 1'b1;

      w_SPI_CS_n    = 1'b0;
      w_Slave_RX_Byte = 8'h5A;
      w_Slave_RX_DV   = 1'b1;
      @(posedge w_SPI_Clk);
      w_Slave_RX_DV   = 1'b0;
      repeat(10) @(posedge w_SPI_Clk);
      w_SPI_CS_n   = 1'b1;


      @(posedge r_Clk);
      w_SPI_CS_n   = 1'b0;
      w_Slave_RX_Byte = 8'hFA;
      w_Slave_RX_DV   = 1'b1;
      @(posedge w_SPI_Clk);
      w_Slave_RX_DV   = 1'b0;
      repeat(10) @(posedge w_SPI_Clk);
      w_SPI_CS_n   = 1'b1;

    
      @(posedge w_SPI_Clk);//Transfer AA to the master
      w_SPI_CS_n    = 1'b0;
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b0;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b0;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b0;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b0;
      @(posedge w_SPI_Clk);
      w_SPI_CS_n    = 1'b1;

      @(posedge w_SPI_Clk);//Transfer AA to the master E9
      w_SPI_CS_n    = 1'b0;
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b0;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b0;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b0;
      @(posedge w_SPI_Clk);
      w_SPI_MOSI    = 1'b1;
      @(posedge w_SPI_Clk);
      w_SPI_CS_n    = 1'b1;

      @(posedge r_Clk);
      w_SPI_CS_n   = 1'b0;
      w_Slave_RX_Byte = 8'b11001011;
      w_Slave_RX_DV   = 1'b1;
      @(posedge w_SPI_Clk);
      w_Slave_RX_DV   = 1'b0;
      repeat(10) @(posedge w_SPI_Clk);
      w_SPI_CS_n   = 1'b1;


      repeat(100) @(posedge r_Clk);
      $finish();      
    end // initial begin

endmodule // SPI_Slave



