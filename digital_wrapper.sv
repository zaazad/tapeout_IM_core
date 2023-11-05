`timescale 1ns/10ps
module digital_wrapper
  #()
  (
    input                i_clk,//main clock, 100MHz
    input                i_rstn,
    input                ACLK,//annealing clock, 250MHz

    // SPI-Slave Interface
    input                o_RX_DV, // Data Valid pulse (1 clock cycle)
    input [7:0]          o_RX_Byte, // Byte received on MOSI
    output logic         i_TX_DV, // Data Valid pulse to register i_TX_Byte
    output logic [7:0]   i_TX_Byte, // Byte to serialize to MISO.

    // GPIO Interface
    input  [7:0]        in_GPIO_retimed,
    input               in_GPIO_valid,
    output logic [7:0]  out_GPIO,
    output logic        out_GPIO_valid,
    output logic        GPIO_IE,
    output logic        GPIO_OEN,
    output logic [7:0]  GPIO_DS,
    output logic [7:0]  GPIO_PE,
    output logic [23:0] GPIO_offest,


   //Inputs from Analog Top
    input [49:0]         spin_read_out,

    //Dynamic control registers
    output logic [249:0] dig_cu_dac_ctrl,
    output logic [49:0]  dig_cu_polarity,
    output logic         dig_spin_pre_prog_ic, 
    output logic         dig_spin_prog_ic, 
    output logic         dig_spin_CCII_ena,
    output logic [49:0]  dig_spin_init_condition,
    output logic [49:0]  dig_cu_prog_ena,
    output logic         dig_spin_fix_ena, 
    output logic         dig_spin_read_out_ena,
    output logic         dig_anneal_sch_reg,
    output logic         dig_langevin_ena,
     output logic [15:0] dig_langevin_res_bank_ctrl,

    //Static control registers
    output logic [15:0] dig_Ibias_spin_ctrl, 
    output logic        dig_noise_sample_clk_sel,
    output logic [1:0]  dig_spin_fix_polarity,
    output logic [2:0]  dig_langevin_gain_ctrl,
    output logic [49:0] bias_en,
    output logic [5:0] coupler_cal_bias_ctrl

   );

   
/////////////////////////////////////////////////////////////////////////
///////////////////////Config and Status Registers//////////////////////
////////////////////////////////////////////////////////////////////////
//System control registers 0 -> 7
logic conf_sys_ctrl_reg_RESET, conf_sys_ctrl_reg_INIT, conf_sys_ctrl_reg_LOAD, conf_sys_ctrl_reg_RUN, conf_sys_ctrl_reg_RERUN;
logic [7:0] conf_sys_ctrl_reg_RUN_TIME_INTERVAL;

//System status registers 8 -> 15
logic conf_sys_stat_reg_ERROR, conf_sys_stat_reg_FIFO_FULL, conf_sys_stat_reg_BUFFER_FULL, conf_sys_stat_reg_SPI_ERR,
      conf_sys_stat_reg_LOADING_DONE, conf_sys_stat_reg_RUNNING, conf_sys_stat_reg_SAMPLING;

logic [15:0] conf_dig_Ibias_spin_ctrl;//16 -> 10000
//(00 none, 01 langevine, 10 spin fix, 11 both) ==> this controls dig_langevin_ena and dig_spin_fix_ena
logic [1:0]  conf_fix_langevin_sel; //17 -> 10001 
logic [23:0] conf_reg_GPIO_offest; //18 -> 10010 
logic        conf_dig_noise_sample_clk_sel;//19 -> 10011
logic [127:0] conf_dig_anneal_sch_reg;//20 -> 10100
logic [1:0]  conf_dig_spin_fix_polarity;//21 -> 10101
logic [2:0]  conf_dig_langevin_gain_ctrl;//22 -> 10110
logic [7:0]  conf_reg_total_run_count; //23 -> 10111
logic [7:0]  conf_reg_total_rerun_count; //24 -> 11000
logic [7:0]  conf_reg_test_SPI; //25 -> 11001
logic [7:0]  conf_reg_GPIO_DS; //26 -> 11010
logic [7:0]  conf_reg_GPIO_PE; //27 -> 11011
logic [49:0] conf_reg_bias_en; // 28 -> 11100
logic [5:0] conf_reg_coupler_cal_bias_ctrl; //29 -> 11101

////////////////////////////////////////////////////////////////////////////////////////
////////////////////////Data Streaming//////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////
logic coefficient_rf_part1_web, coefficient_rf_part2_web, spin_polarity_web, initial_spin_rf_web, output_spin_rf_web;

logic [5:0] coefficient_rf_part1_a;
logic [5:0] coefficient_rf_part2_a;
logic [5:0] spin_polarity_a;
logic [6:0] initial_spin_rf_a;
logic [7:0] output_spin_rf_a;

logic [127:0] coefficient_rf_part1_d;
logic [127:0] coefficient_rf_part2_d;
logic [49:0] spin_polarity_d;
logic [49:0] initial_spin_rf_d;
logic [49:0] output_spin_rf_d;

logic [127:0] coefficient_rf_part1_bweb;
logic [127:0] coefficient_rf_part2_bweb;
logic [49:0] spin_polarity_bweb;
logic [49:0] initial_spin_rf_bweb;
logic [49:0] output_spin_rf_bweb;

logic [127:0] coefficient_rf_part1_q;
logic [127:0] coefficient_rf_part2_q;
logic [49:0] spin_polarity_q;
logic [49:0] initial_spin_rf_q;
logic [49:0] output_spin_rf_q;


logic [127:0] coefficients_part_1_tmp;
logic [127:0] coefficients_part_2_tmp;
logic [49:0] spin_polarity_tmp;
logic in_GPIO_valid_sampled;
logic [7:0] in_GPIO_sampled;
logic [49:0] spin_initial;

logic [7:0]  out_GPIO_rf;
logic        out_GPIO_valid_rf;
////////////////////////////////////////////////////////////////////////////////////////
///////////////////////Control Unit/////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////
logic [7:0] run_counter;
logic config_dig_spin_pre_prog_ic;
logic config_dig_spin_read_out_ena, config_dig_spin_read_out_ena_q;
logic config_dig_spin_prog_ic;
logic [49:0] config_dig_cu_prog_ena;
logic config_dig_spin_CCII_ena;
logic config_dig_spin_fix_ena;
logic config_dig_langevin_ena;
logic [15:0] config_dig_langevin_res_bank_ctrl;
logic final_run;

////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////Submodules Instantiation//////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////

RF #(.numRow(52), .numBit(128), .numRowAddr(6)) coefficient_rf_part1
    (.CLK(i_clk),
    .CEB(1'b0), // always enabled
    .WEB(coefficient_rf_part1_web),
    .A(coefficient_rf_part1_a),
    .D(coefficient_rf_part1_d),
    .BWEB(coefficient_rf_part1_bweb),
    .Q(coefficient_rf_part1_q)
);


RF #(.numRow(52), .numBit(128), .numRowAddr(6)) coefficient_rf_part2
    (.CLK(i_clk),
    .CEB(1'b0),
    .WEB(coefficient_rf_part2_web),
    .A(coefficient_rf_part2_a),
    .D(coefficient_rf_part2_d),
    .BWEB(coefficient_rf_part2_bweb),
    .Q(coefficient_rf_part2_q)
);


RF #(.numRow(52), .numBit(50), .numRowAddr(6)) spin_polarity_rf
    (.CLK(i_clk),
    .CEB(1'b0),
    .WEB(spin_polarity_web),
    .A(spin_polarity_a),
    .D(spin_polarity_d),
    .BWEB(spin_polarity_bweb),
    .Q(spin_polarity_q)
);


RF #(.numRow(100), .numBit(50), .numRowAddr(7)) initial_spin_rf
    (.CLK(i_clk),
    .CEB(1'b0),
    .WEB(initial_spin_rf_web),
    .A(initial_spin_rf_a),
    .D(initial_spin_rf_d),
    .BWEB(initial_spin_rf_bweb),
    .Q(initial_spin_rf_q)
);


RF #(.numRow(200), .numBit(50), .numRowAddr(8)) output_spin_rf
    (.CLK(i_clk),
    .CEB(1'b0),
    .WEB(output_spin_rf_web),
    .A(output_spin_rf_a),
    .D(output_spin_rf_d),
    .BWEB(output_spin_rf_bweb),
    .Q(output_spin_rf_q)
);

SPI_decoder     SPI_decoder_instance (
    .i_clk (i_clk),
    .i_rstn(i_rstn),

    .o_RX_DV (o_RX_DV),
    .o_RX_Byte(o_RX_Byte),
    .i_TX_DV(i_TX_DV),
    .i_TX_Byte(i_TX_Byte),

    .conf_sys_ctrl_reg_RESET(conf_sys_ctrl_reg_RESET), 
    .conf_sys_ctrl_reg_INIT(conf_sys_ctrl_reg_INIT), 
    .conf_sys_ctrl_reg_LOAD(conf_sys_ctrl_reg_LOAD), 
    .conf_sys_ctrl_reg_RUN(conf_sys_ctrl_reg_RUN), 
    .conf_sys_ctrl_reg_RERUN(conf_sys_ctrl_reg_RERUN),
    .conf_sys_ctrl_reg_RUN_TIME_INTERVAL(conf_sys_ctrl_reg_RUN_TIME_INTERVAL),

    .conf_sys_stat_reg_ERROR(conf_sys_stat_reg_ERROR), 
    .conf_sys_stat_reg_FIFO_FULL(conf_sys_stat_reg_FIFO_FULL), 
    .conf_sys_stat_reg_BUFFER_FULL(conf_sys_stat_reg_BUFFER_FULL), 
    .conf_sys_stat_reg_SPI_ERR(conf_sys_stat_reg_SPI_ERR),
    .conf_sys_stat_reg_LOADING_DONE(conf_sys_stat_reg_LOADING_DONE), 
    .conf_sys_stat_reg_RUNNING(conf_sys_stat_reg_RUNNING), 
    .conf_sys_stat_reg_SAMPLING(conf_sys_stat_reg_SAMPLING),
    .conf_dig_Ibias_spin_ctrl(conf_dig_Ibias_spin_ctrl),
    .conf_fix_langevin_sel(conf_fix_langevin_sel),
    .conf_reg_GPIO_offest(conf_reg_GPIO_offest),
    .conf_dig_noise_sample_clk_sel(conf_dig_noise_sample_clk_sel),
    .conf_dig_anneal_sch_reg(conf_dig_anneal_sch_reg),
    .conf_dig_spin_fix_polarity(conf_dig_spin_fix_polarity),
    .conf_dig_langevin_gain_ctrl(conf_dig_langevin_gain_ctrl),
    .conf_reg_total_run_count(conf_reg_total_run_count),
    .conf_reg_total_rerun_count(conf_reg_total_rerun_count),
    .conf_reg_test_SPI(conf_reg_test_SPI),
    .conf_reg_GPIO_DS(conf_reg_GPIO_DS),
    .conf_reg_GPIO_PE(conf_reg_GPIO_PE),
    .conf_reg_bias_en(conf_reg_bias_en),
    .conf_reg_coupler_cal_bias_ctrl(conf_reg_coupler_cal_bias_ctrl)
);


GPIO    GPIO_instance(
    .i_clk(i_clk),
    .i_rstn(i_rstn),

    .in_GPIO_retimed(in_GPIO_retimed),
    .in_GPIO_valid(in_GPIO_valid),
    .in_GPIO_sampled(in_GPIO_sampled),
    .in_GPIO_valid_sampled(in_GPIO_valid_sampled),

    .out_GPIO_rf(out_GPIO_rf),
    .out_GPIO_valid_rf(out_GPIO_valid_rf),
    .out_GPIO(out_GPIO),
    .out_GPIO_valid(out_GPIO_valid)
);


coefficient_rf_ctrl     coefficient_rf_ctrl_instance (
    .i_clk(i_clk),
    .i_rstn(i_rstn),

    .in_GPIO_sampled(in_GPIO_sampled),
    .in_GPIO_valid_sampled(in_GPIO_valid_sampled),

    .conf_sys_ctrl_reg_RESET(conf_sys_ctrl_reg_RESET),
    .conf_sys_ctrl_reg_INIT(conf_sys_ctrl_reg_INIT),
    .conf_sys_ctrl_reg_LOAD(conf_sys_ctrl_reg_LOAD),

    .coefficient_rf_part1_a(coefficient_rf_part1_a),
    .coefficient_rf_part1_bweb(coefficient_rf_part1_bweb),
    .coefficient_rf_part1_web(coefficient_rf_part1_web),
    .coefficient_rf_part1_d(coefficient_rf_part1_d), 

    .coefficient_rf_part2_a(coefficient_rf_part2_a),
    .coefficient_rf_part2_bweb(coefficient_rf_part2_bweb),
    .coefficient_rf_part2_web(coefficient_rf_part2_web),
    .coefficient_rf_part2_d(coefficient_rf_part2_d),

    .spin_polarity_a(spin_polarity_a),
    .spin_polarity_bweb(spin_polarity_bweb),
    .spin_polarity_web(spin_polarity_web),
    .spin_polarity_d(spin_polarity_d),

    .coefficient_rf_wr_done(coefficient_rf_wr_done),
    .coefficients_part_1_tmp(coefficients_part_1_tmp),       
    .coefficients_part_2_tmp(coefficients_part_2_tmp),
    .spin_polarity_tmp(spin_polarity_tmp),
    .coefficient_rf_part1_q(coefficient_rf_part1_q),
    .coefficient_rf_part2_q(coefficient_rf_part2_q),
    .spin_polarity_q(spin_polarity_q)
);

initial_spin_rf_ctrl    initial_spin_rf_ctrl_instance(
    .i_clk(i_clk),
    .i_rstn(i_rstn),

    .in_GPIO_sampled(in_GPIO_sampled),
    .in_GPIO_valid_sampled(in_GPIO_valid_sampled),

    .conf_sys_ctrl_reg_INIT(conf_sys_ctrl_reg_INIT),
    .conf_reg_total_run_count(conf_reg_total_run_count),
    .conf_sys_ctrl_reg_RERUN(conf_sys_ctrl_reg_RERUN),
    .conf_sys_ctrl_reg_RUN(conf_sys_ctrl_reg_RUN),
    .conf_sys_ctrl_reg_RESET(conf_sys_ctrl_reg_RESET),
    .coefficient_rf_wr_done(coefficient_rf_wr_done),
    .run_counter(run_counter),
    .initial_spin_rf_q(initial_spin_rf_q),

    .spin_initial(spin_initial),
    .initial_spin_rf_a(initial_spin_rf_a),
    .initial_spin_rf_d(initial_spin_rf_d),
    .initial_spin_rf_web(initial_spin_rf_web),
    .initial_spin_rf_bweb(initial_spin_rf_bweb)
);

    
output_spin_rf_ctrl     output_spin_rf_ctrl_instance(
    .i_clk(i_clk),
    .i_rstn(i_rstn) ,

    .conf_reg_total_rerun_count(conf_reg_total_rerun_count),
    .conf_reg_total_run_count(conf_reg_total_run_count),
    .conf_sys_ctrl_reg_RESET(conf_sys_ctrl_reg_RESET),

    .config_dig_spin_read_out_ena_q(config_dig_spin_read_out_ena_q),
    .config_dig_spin_CCII_ena(config_dig_spin_CCII_ena),
    .final_run(final_run),
    .spin_read_out(spin_read_out),
    .output_spin_rf_q(output_spin_rf_q),

    .output_spin_rf_web(output_spin_rf_web),
    .output_spin_rf_a(output_spin_rf_a),
    .output_spin_rf_d(output_spin_rf_d),
    .output_spin_rf_bweb(output_spin_rf_bweb),

    .out_GPIO(out_GPIO_rf),
    .out_GPIO_valid(out_GPIO_valid_rf),
    .GPIO_IE(GPIO_IE),
    .GPIO_OEN(GPIO_OEN)
);


central_control_unit    central_control_unit_instance(
    .i_clk(i_clk),
    .i_rstn(i_rstn),
    .ACLK(ACLK),

    .conf_sys_ctrl_reg_LOAD(conf_sys_ctrl_reg_LOAD),
    .conf_sys_ctrl_reg_RUN(conf_sys_ctrl_reg_RUN),
    .conf_sys_ctrl_reg_RERUN(conf_sys_ctrl_reg_RERUN),
    .conf_reg_total_run_count(conf_reg_total_run_count),
    .conf_reg_total_rerun_count(conf_reg_total_rerun_count),
    .conf_sys_ctrl_reg_RUN_TIME_INTERVAL(conf_sys_ctrl_reg_RUN_TIME_INTERVAL),
    .conf_sys_ctrl_reg_RESET(conf_sys_ctrl_reg_RESET),
    .conf_fix_langevin_sel(conf_fix_langevin_sel),
    .conf_dig_anneal_sch_reg(conf_dig_anneal_sch_reg),

    .run_counter(run_counter),

    .config_dig_spin_pre_prog_ic(config_dig_spin_pre_prog_ic),
    .config_dig_spin_read_out_ena(config_dig_spin_read_out_ena), 
    .config_dig_spin_read_out_ena_q(config_dig_spin_read_out_ena_q),
    .config_dig_spin_prog_ic(config_dig_spin_prog_ic),
    .config_dig_cu_prog_ena(config_dig_cu_prog_ena),
    .config_dig_spin_CCII_ena(config_dig_spin_CCII_ena),
    .config_dig_spin_fix_ena(config_dig_spin_fix_ena),
    .dig_anneal_sch_reg(dig_anneal_sch_reg),
    .config_dig_langevin_ena(config_dig_langevin_ena),
    .config_dig_langevin_res_bank_ctrl(config_dig_langevin_res_bank_ctrl),
    .final_run(final_run)
);


////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////Output signals///////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////
assign GPIO_PE  = conf_reg_GPIO_PE;
assign GPIO_DS  = conf_reg_GPIO_DS;
assign dig_cu_dac_ctrl = {coefficients_part_2_tmp[121:0] , coefficients_part_1_tmp[127:0]};
assign dig_cu_polarity = spin_polarity_tmp[49:0];
assign dig_spin_init_condition = spin_initial;
assign dig_spin_pre_prog_ic = config_dig_spin_pre_prog_ic;
assign dig_spin_read_out_ena = config_dig_spin_read_out_ena;
assign dig_spin_prog_ic = config_dig_spin_prog_ic;
assign dig_cu_prog_ena = config_dig_cu_prog_ena;
assign dig_spin_CCII_ena = config_dig_spin_CCII_ena;
assign dig_spin_fix_ena = config_dig_spin_fix_ena;
assign dig_Ibias_spin_ctrl = conf_dig_Ibias_spin_ctrl;
assign dig_noise_sample_clk_sel = conf_dig_noise_sample_clk_sel;
assign dig_spin_fix_polarity = conf_dig_spin_fix_polarity;
assign dig_langevin_gain_ctrl = conf_dig_langevin_gain_ctrl;
assign dig_langevin_ena = config_dig_langevin_ena;
assign dig_langevin_res_bank_ctrl = config_dig_langevin_res_bank_ctrl;
assign GPIO_offest = conf_reg_GPIO_offest;
assign bias_en = conf_reg_bias_en;
assign coupler_cal_bias_ctrl = conf_reg_coupler_cal_bias_ctrl;


endmodule
