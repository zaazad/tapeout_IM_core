`timescale 1ns/10ps
module tb_digital_wrapper ();

logic i_clk, i_rstn, ACLK;

logic o_RX_DV, i_TX_DV;
logic [7:0] o_RX_Byte; 
logic [7:0] i_TX_Byte;

//wire [7:0] i_o_GPIO;
//wire i_o_GPIO_valid;

logic  [7:0]  in_GPIO_retimed;
logic         in_GPIO_valid;
logic  [7:0]  out_GPIO;
logic         out_GPIO_valid;
logic         GPIO_IE;
logic         GPIO_OEN;
logic  [7:0]  GPIO_DS;
logic  [7:0]  GPIO_PE;
logic [23:0]  GPIO_offest;


logic [7:0] i_o_GPIO_tmp;
logic i_o_GPIO_valid_tmp;

logic [49:0] spin_read_out;

logic [249:0] dig_cu_dac_ctrl;
logic [49:0]  dig_cu_polarity;
logic dig_spin_pre_prog_ic; //when set the initial spin values are passed
logic dig_spin_prog_ic; //set when programming (coefficient and polarity)
logic dig_spin_CCII_ena; //active during a run/rerun
logic [49:0] dig_spin_init_condition;
logic [49:0] dig_cu_prog_ena;
logic dig_spin_fix_ena; //set to one, 3 cycles after dig_spin_CCII_ena, active for 10 cycles
//logic [2:0] dig_noise_sample_clk_mux; //Generates 0, 1, 2, 3, 4, 5, 6, 7, 7, 7 while dig_spin_fix_ena is set
logic dig_spin_read_out_ena;//one cycle before end of run/dig_spin_CCII_ena ==> the output spin is ready one cycle later
logic [15:0] dig_Ibias_spin_ctrl;
logic        dig_spin_fix_polarity;
logic [2:0]  dig_langevin_gain_ctrl;
logic        dig_anneal_sch_reg;
logic        dig_langevin_ena;
logic [15:0] dig_langevin_res_bank_ctrl;
logic [49:0] bias_en;
logic [5:0] coupler_cal_bias_ctrl;

digital_wrapper DUT
  (
    .i_clk(i_clk),
    .i_rstn(i_rstn),
    .ACLK(ACLK),

   // SPI-Slave Interface
    .o_RX_DV(o_RX_DV),
    .o_RX_Byte(o_RX_Byte),
    .i_TX_DV(i_TX_DV),
    .i_TX_Byte(i_TX_Byte),

    // GPIO Interface
   .in_GPIO_retimed(in_GPIO_retimed),
   .in_GPIO_valid(in_GPIO_valid),
   .out_GPIO(out_GPIO),
   .out_GPIO_valid(out_GPIO_valid),
   .GPIO_DS(GPIO_DS),
   .GPIO_PE(GPIO_PE),
   .GPIO_IE(GPIO_IE),
   .GPIO_OEN(GPIO_OEN),
   .GPIO_offest(GPIO_offest),
  
   //Inputs from Analog Top
    .spin_read_out(spin_read_out),

   //Outputs to Analog Top => To-Do: complete the signal list
    .dig_cu_dac_ctrl(dig_cu_dac_ctrl),
    .dig_cu_polarity(dig_cu_polarity),
    .dig_spin_pre_prog_ic(dig_spin_pre_prog_ic),
    .dig_spin_prog_ic(dig_spin_prog_ic),
    .dig_spin_CCII_ena(dig_spin_CCII_ena),
    .dig_spin_init_condition(dig_spin_init_condition),
    .dig_cu_prog_ena(dig_cu_prog_ena),
    .dig_spin_fix_ena(dig_spin_fix_ena),
    .dig_spin_read_out_ena(dig_spin_read_out_ena),
    .dig_Ibias_spin_ctrl(dig_Ibias_spin_ctrl),
    //.dig_noise_sample_clk_sel(dig_noise_sample_clk_sel),
    .dig_spin_fix_polarity(dig_spin_fix_polarity),
    .dig_langevin_gain_ctrl(dig_langevin_gain_ctrl),
    .dig_anneal_sch_reg(dig_anneal_sch_reg),
    .dig_langevin_ena(dig_langevin_ena),
    .dig_langevin_res_bank_ctrl(dig_langevin_res_bank_ctrl),
    .bias_en(bias_en), 
    .coupler_cal_bias_ctrl(coupler_cal_bias_ctrl)
   );


   localparam MAIN_CLK_DELAY = 5;
   localparam Analog_CLK_DELAY = 2;
    // Clock Generators:
    always #(MAIN_CLK_DELAY) i_clk = ~i_clk;

    always #(Analog_CLK_DELAY) ACLK = ~ACLK;

    assign in_GPIO_retimed = i_o_GPIO_tmp;
    assign in_GPIO_valid = i_o_GPIO_valid_tmp;


initial
     begin


        i_rstn = 1;
        i_clk = 0;
        ACLK = 0;
        o_RX_DV = 0;
        o_RX_Byte = '0;
        i_o_GPIO_tmp = '0;
        i_o_GPIO_valid_tmp = 0;

        repeat(4) @(negedge i_clk);
        i_rstn = 0;

        repeat(4) @(negedge i_clk);
        i_rstn = 1;

     
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////Start of the first test
        o_RX_DV = 1;
        o_RX_Byte = 8'b1000_0100; //command for conf_sys_ctrl_reg_RUN_TIME_INTERVAL
        @(negedge i_clk);
        o_RX_DV = 0;

       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0010_0000; //data for conf_sys_ctrl_reg_RUN_TIME_INTERVAL:32

        @(negedge i_clk);
        o_RX_DV = 0;


        @(negedge i_clk);//conf_reg_GPIO_offest: 24 bit
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0010;
        @(negedge i_clk);
        o_RX_Byte = 8'b1010_1100;
        @(negedge i_clk);
        o_RX_Byte = 8'b0101_1001;
        @(negedge i_clk);
        o_RX_Byte = 8'b1011_0011;

        @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);//conf_dig_anneal_sch_reg: 128 bit
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0100; 
        for(int i=0; i<16; i++) begin
          @(negedge i_clk);
          if(i%2)
            o_RX_Byte = 8'hFA;
          else
            o_RX_Byte = 8'hFF;
        end

       @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0001;//conf_fix_langevin_sel command and address

        @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0001;//conf_fix_langevin_sel data => langevin
        //o_RX_Byte = 8'b0000_0011;//conf_fix_langevin_sel data => both spin_fix and langevin

       @(negedge i_clk);
        o_RX_DV = 0;


        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0111;   
        @(negedge i_clk);
        o_RX_Byte = 8'b0000_0100;//Run Count Set to 4 
        @(negedge i_clk);
        o_RX_DV = 0;

      @(negedge i_clk);
      o_RX_DV = 1;
      o_RX_Byte = 8'b1001_1000; 
      @(negedge i_clk);
      o_RX_Byte = 8'b0000_0010;////Rerun Count Set to 2


      @(negedge i_clk);
      o_RX_DV = 1;
      o_RX_Byte = 8'b0000_0001; //command for conf_sys_ctrl_reg_INIT
      @(negedge i_clk);
      o_RX_DV = 0;
      
      //coefficients
      for (int i = 0; i < 39; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b1111_1111;
          i_o_GPIO_valid_tmp = 1;
      end

      for (int i = 38; i < 77; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b0000_0000;
          i_o_GPIO_valid_tmp = 1;
      end

      for (int i = 77; i < 1910; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b1111_1111;
          i_o_GPIO_valid_tmp = 1;
      end

      for (int i = 1910; i < 1949; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b0000_0000;
          i_o_GPIO_valid_tmp = 1;
      end

      @(negedge i_clk); ////we need to wait one cycle until coefficients done signal is set 
      i_o_GPIO_valid_tmp = 0;

        //initial spin values run 1
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b1111_1111; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end
        //initial spin values run 2
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b0000_0000; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end
        //initial spin values run 3
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b1111_1111; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end
         //initial spin values run 4
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b0000_0000; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end

       @(negedge i_clk);
        o_RX_DV = 0;


        repeat(5)  @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0001; //command for conf_sys_ctrl_reg_INIT reset


        i_o_GPIO_valid_tmp = 0;
        i_o_GPIO_tmp = '0;

        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0010;//LOAD Set

       @(negedge i_clk);
        o_RX_DV = 0;

        repeat(101) @(negedge i_clk);//100 cycles should be enough for the load to be done
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0010;//LOAD ReSet


       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1000_0100; //RTI address and command
        @(negedge i_clk);
        o_RX_Byte = 8'b0010_0000;//RTI Set to 128


      //run 1
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;


        @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0001;//conf_fix_langevin_sel command and address

        @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);
        o_RX_DV = 1;
        //o_RX_Byte = 8'b0000_0001;//conf_fix_langevin_sel data => langevin
        o_RX_Byte = 8'b0000_0011;//conf_fix_langevin_sel data => both spin_fix and langevin

        @(negedge i_clk);
        o_RX_DV = 0;

        //rerun 1
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0101;//Rerun Set
        repeat(100) @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0101;//Rerun reset
        @(negedge i_clk);
        o_RX_DV = 0;

        //rerun 2
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0101;//Rerun Set
        repeat(100) @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0101;//Rerun reset
        @(negedge i_clk);
        o_RX_DV = 0;

        //run 2
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;


        //run 3
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;



        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0001;//conf_fix_langevin_sel command and address

        @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0010;//conf_fix_langevin_sel data => both spin_fix and langevin
        //o_RX_Byte = 8'b0000_0001;//conf_fix_langevin_sel data => langevin
        //o_RX_Byte = 8'b0000_0011;//conf_fix_langevin_sel data => both spin_fix and langevin

        @(negedge i_clk);
        o_RX_DV = 0;


        //run 4
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;


        //rerun 2
       /* @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0101;//Rerun Set
        repeat(100) @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0101;//Rerun reset
        @(negedge i_clk);
        o_RX_DV = 0;*/

        
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_1011; //write into the test config register
        @(negedge i_clk);
        o_RX_Byte = 8'b1111_1001; //data

        @(negedge i_clk);
        o_RX_DV = 0;

       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1101_1011; //read the test config register

        @(negedge i_clk);
        o_RX_DV = 0;


      repeat(100) @(negedge i_clk); //wait for the output to be read
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0000;//Reset to get ready for the next run

        repeat(5) @(negedge i_clk);
        o_RX_DV = 0;
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////End of first test




        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////Start of second test
        o_RX_DV = 1;
        o_RX_Byte = 8'b1000_0100; //command for conf_sys_ctrl_reg_RUN_TIME_INTERVAL

        @(negedge i_clk);
        o_RX_DV = 0;

       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0010_0000; //data for conf_sys_ctrl_reg_RUN_TIME_INTERVAL:32

       @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0001;//conf_fix_langevin_sel command and address

        @(negedge i_clk);
        o_RX_DV = 0;

        @(negedge i_clk);
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0001;//conf_fix_langevin_sel data => langevin
        //o_RX_Byte = 8'b0000_0011;//conf_fix_langevin_sel data => both spin_fix and langevin

       @(negedge i_clk);
        o_RX_DV = 0;


        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0111;
        @(negedge i_clk);
        o_RX_Byte = 8'b0000_0100;//Run Count Set to 4 
        @(negedge i_clk);
        o_RX_DV = 0;


      @(negedge i_clk);
      o_RX_DV = 1;
      o_RX_Byte = 8'b1001_1000;
      @(negedge i_clk);
      o_RX_Byte = 8'b0000_0010;////Rerun Count Set to 2


      @(negedge i_clk);
      o_RX_DV = 1;
      o_RX_Byte = 8'b0000_0001; //command for conf_sys_ctrl_reg_INIT
      @(negedge i_clk);
      o_RX_DV = 0;
      
       //coefficients
      for (int i = 0; i < 39; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b1111_1111;
          i_o_GPIO_valid_tmp = 1;
      end

      for (int i = 38; i < 77; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b0000_0000;
          i_o_GPIO_valid_tmp = 1;
      end

      for (int i = 77; i < 1910; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b1111_1111;
          i_o_GPIO_valid_tmp = 1;
      end

      for (int i = 1910; i < 1949; i = i + 1) begin
           @(negedge i_clk);
          //i_o_GPIO_tmp = 8'(i%256);
          i_o_GPIO_tmp = 8'b0000_0000;
          i_o_GPIO_valid_tmp = 1;
      end

      @(negedge i_clk); ////we need to wait one cycle until coefficients done signal is set 
      i_o_GPIO_valid_tmp = 0;

        //initial spin values run 1
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b1111_1111; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end
        //initial spin values run 2
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b0000_0000; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end
        //initial spin values run 3
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b1111_1111; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end
         //initial spin values run 4
        for (int i = 0; i < 7; i = i + 1) begin
           @(negedge i_clk);
          i_o_GPIO_tmp = 8'b0000_0000; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end

       @(negedge i_clk);
        o_RX_DV = 0;


        repeat(5)  @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0001; //command for conf_sys_ctrl_reg_INIT reset


        i_o_GPIO_valid_tmp = 0;
        i_o_GPIO_tmp = '0;

        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0010;//LOAD Set

       @(negedge i_clk);
        o_RX_DV = 0;

        repeat(101) @(negedge i_clk);//100 cycles should be enough for the load to be done
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0010;//LOAD ReSet


       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1000_0100; //RTI address and command
        @(negedge i_clk);
        o_RX_Byte = 8'b0010_0000;//RTI Set to 128


      //run 1
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;


        //rerun 1
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0101;//Rerun Set
        repeat(100) @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0101;//Rerun reset
        @(negedge i_clk);
        o_RX_DV = 0;


        //run 2
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;


        //run 3
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;


        //run 4
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set
       @(negedge i_clk);
        o_RX_DV = 0;
        #700 //35 cycles to finish the RIT and read out process
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset
        @(negedge i_clk);
        o_RX_DV = 0;


        //rerun 2
        @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0101;//Rerun Set
        repeat(100) @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0101;//Rerun reset
        @(negedge i_clk);
        o_RX_DV = 0;

        
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_1011; //write into the test config register
        @(negedge i_clk);
        o_RX_Byte = 8'b1111_1001; //data

        @(negedge i_clk);
        o_RX_DV = 0;

       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1101_1011; //read the test config register

        @(negedge i_clk);
        o_RX_DV = 0;

      repeat(100) @(negedge i_clk);
       @(negedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0000;//Reset to get ready for the next run

        repeat(5) @(negedge i_clk);
        o_RX_DV = 0;
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////End of second test



        repeat(1500) @(negedge i_clk);
        $finish(); 
        $dumpfile ("dut.dump");
        $dumpvars (0, tb_digital_wrapper);
     end // initial begin


//Generates the output spins on behalf of the IM_core      
logic [49:0] counter;
always_ff @(posedge dig_spin_CCII_ena or i_rstn) begin
    if (~i_rstn)
    begin
      counter <= '0;
      spin_read_out <= '0;
    end
    else 
    begin
      counter <= counter + 1;
      spin_read_out <= counter;
    end
end



endmodule





    /*initial
    begin
        i_rstn = 1;
        i_clk = 0;
        o_RX_DV = 0;
        o_RX_Byte = '0;
        i_o_GPIO_tmp = '0;
        i_o_GPIO_valid_tmp = 0;


        #45
        i_rstn = 0;

        //testing config register commands
        //repeat(5) @(posedge i_clk);
        o_RX_DV = 1;
        o_RX_Byte = 8'b1000_0100; //command for conf_sys_ctrl_reg_RUN_TIME_INTERVAL

        #20
        o_RX_DV = 0;

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b0010_0000; //data for conf_sys_ctrl_reg_RUN_TIME_INTERVAL:32

        #20
        o_RX_DV = 0;

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_0001;//conf_fix_langevin_sel command and address

        #20
        o_RX_DV = 0;

        #40
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0001;//conf_fix_langevin_sel data => langevin
        //o_RX_Byte = 8'b0000_0011;//conf_fix_langevin_sel data => both spin_fix and langevin

        #20
        o_RX_DV = 0;


        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_1001;
        #20
        o_RX_Byte = 8'b0000_0001;//Run Count Set to 1  


        #20
        o_RX_DV = 0;

        #20 
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0001; //command for conf_sys_ctrl_reg_INIT

        #20
        o_RX_DV = 0;
      
      //coefficients
      for (int i = 0; i < 1900; i = i + 1) begin
          #20 
          i_o_GPIO_tmp = i%256;
          i_o_GPIO_valid_tmp = 1;
      end

      #20 ////we need to wait one cycle until coefficients done signal is set 
      #20 

        //initial spin values
        for (int i = 0; i < 7; i = i + 1) begin
          #20
          i_o_GPIO_tmp = i%256; //8'b1100_0011;
          i_o_GPIO_valid_tmp = 1;
        end

      

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_1010;////Rerun Count Set to 1
        #20
        o_RX_Byte = 8'b0000_0001;


        #20
        o_RX_DV = 0;


        #100
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0001; //command for conf_sys_ctrl_reg_INIT reset


        i_o_GPIO_valid_tmp = 0;
        i_o_GPIO_tmp = '0;

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0010;//LOAD Set

        #20
        o_RX_DV = 0;

        #2000//100 cycles should be enough for the load to be done
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0010;//LOAD ReSet


        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b1000_0100; //RTI address and command
        #20
        o_RX_Byte = 8'b0010_0000;//RTI Set to 128


        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0011;//Run Set

        #20
        o_RX_DV = 0;

        #700 //35 cycles to finish the RIT and read out process

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0011;//Run Reset

        #20 
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0101;//Rerun Set

        #2000 

        o_RX_DV = 1;
        o_RX_Byte = 8'b0100_0101;//rerun reset

      
        #20
        o_RX_DV = 0;

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b1001_1011; //write into the test config register
        #20
        o_RX_Byte = 8'b1111_1001; //data

        #20 
        o_RX_DV = 0;

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b1101_1011; //read the test config register

        #20
        o_RX_DV = 0;

        #20
        o_RX_DV = 1;
        o_RX_Byte = 8'b0000_0000;//Reset to get ready for the next run

        #100
        o_RX_DV = 0;

        #30000
        $finish();      
    end


logic [49:0] counter;
always_ff @(posedge dig_spin_CCII_ena or i_rstn) begin
    if (i_rstn)
    begin
      counter <= '0;
      spin_read_out <= '0;
    end
    else 
    begin
      counter <= counter + 1;
      spin_read_out <= counter;
    end
end
*/