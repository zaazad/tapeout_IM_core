module central_control_unit(
    input i_clk,
    input i_rstn,
    input ACLK,

    input conf_sys_ctrl_reg_LOAD,
    input conf_sys_ctrl_reg_RUN,
    input conf_sys_ctrl_reg_RERUN,
    input [7:0]  conf_reg_total_run_count,
    input [7:0]  conf_reg_total_rerun_count,
    input [7:0]  conf_sys_ctrl_reg_RUN_TIME_INTERVAL,
    input conf_sys_ctrl_reg_RESET,
    input [1:0]  conf_fix_langevin_sel,
    input [127:0] conf_dig_anneal_sch_reg,

    output logic [7:0] run_counter,

    output logic config_dig_spin_pre_prog_ic,
    output logic config_dig_spin_read_out_ena, 
    output logic config_dig_spin_read_out_ena_q,
    output logic config_dig_spin_prog_ic,
    output logic [49:0] config_dig_cu_prog_ena,
    output logic config_dig_spin_CCII_ena,
    output logic config_dig_spin_fix_ena,
    output logic dig_anneal_sch_reg,
    output logic config_dig_langevin_ena,
    output logic [15:0] config_dig_langevin_res_bank_ctrl,
    output logic final_run,
    output logic conf_sys_stat_reg_LOADING_DONE
);


logic run_start, run_start_q;
logic [7:0] run_time_counter;
logic [7:0] current_run_rerun_time;
logic [7:0] rerun_time_interval_q;
logic [7:0] rerun_time_interval;

logic run_start_pos_edge_q, run_start_pos_edge_qq, run_start_pos_edge_qqq;//start dig_spin_fix_ena 3 cycles after run starts
logic [4:0] config_dig_langevine_ena_cnt;
logic [7:0] config_dig_spin_fix_ena_cnt;
logic config_dig_langevine_ena_cnt_start;
logic config_dig_spin_fix_ena_cnt_start;
logic [7:0] total_output_count;
logic [7:0] rerun_counter;

logic sync_inc_counter_en;
logic [5:0]   sync_coefficient_rf_rd_addr;
logic start_programming, start_programming_q;
logic config_dig_spin_pre_prog_ic_q, config_dig_spin_pre_prog_ic_qq;

logic spin_fix_ena;
logic [7:0] ACLK_counter_spin_fix;

/////////////posedge conf_sys_ctrl_reg_INIT
logic conf_sys_ctrl_reg_RESET_q;
always_ff @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn)
        conf_sys_ctrl_reg_RESET_q <= 0;
    else
        conf_sys_ctrl_reg_RESET_q <= conf_sys_ctrl_reg_RESET;
end
assign conf_sys_ctrl_reg_RESET_pos_edge = !conf_sys_ctrl_reg_RESET_q && conf_sys_ctrl_reg_RESET;

/////////////run start
always_ff @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn)
        run_start <= 0;
    else
        run_start <= conf_sys_ctrl_reg_RESET_pos_edge ? 0 : conf_sys_ctrl_reg_RUN || conf_sys_ctrl_reg_RERUN;
end

always_ff @(posedge i_clk  or negedge i_rstn) begin
    if (~i_rstn)
        run_start_q <= 0;
    else
        run_start_q <= conf_sys_ctrl_reg_RESET_pos_edge ? 0: run_start;
end
assign run_start_pos_edge = !run_start_q && run_start;

/////////////run number counter
always_ff @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) 
    begin
        run_counter <= 8'd0;
        rerun_counter <= 8'd0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        run_counter <= 8'd0;
        rerun_counter <= 8'd0;
    end
    else if (run_start_pos_edge && !conf_sys_ctrl_reg_RERUN && (run_counter < conf_reg_total_run_count))//we don't increase run counter for a rerun
        run_counter <= run_counter + 8'd1;
    else if (run_start_pos_edge && conf_sys_ctrl_reg_RERUN && (rerun_counter < conf_reg_total_rerun_count))
        rerun_counter <= rerun_counter + 8'd1;
end

/////////////runtime counter & config_dig_spin_CCII_ena
always_ff @(posedge i_clk or negedge i_rstn)
    if(~i_rstn)
    begin
        run_time_counter <= '0;
        config_dig_spin_CCII_ena <= '0;
        current_run_rerun_time <= '0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        run_time_counter <= '0;
        config_dig_spin_CCII_ena <= '0;
        current_run_rerun_time <= '0;
    end
    else if (run_start_pos_edge)
    begin
        run_time_counter <= conf_sys_ctrl_reg_RERUN ? rerun_time_interval-1 : conf_sys_ctrl_reg_RUN_TIME_INTERVAL-1;
        current_run_rerun_time <= conf_sys_ctrl_reg_RERUN ? rerun_time_interval-1 : conf_sys_ctrl_reg_RUN_TIME_INTERVAL-1;
        config_dig_spin_CCII_ena <= 1;
    end
    else if (run_start && |run_time_counter)
    begin
        run_time_counter <= run_time_counter-1;
        config_dig_spin_CCII_ena <= 1;
    end
    else
    begin
        run_time_counter <= '0;
        config_dig_spin_CCII_ena <= '0;
        current_run_rerun_time <= '0;
    end

always_ff @(posedge i_clk or negedge i_rstn)
begin
    if (~i_rstn)
        rerun_time_interval_q <= '0;
    else 
        rerun_time_interval_q <= conf_sys_ctrl_reg_RESET_pos_edge ? '0 : rerun_time_interval;
end

assign rerun_time_interval =  conf_sys_ctrl_reg_RERUN && run_start_pos_edge ? rerun_time_interval_q + 1 : 
                              (conf_sys_ctrl_reg_RUN  && run_start_pos_edge ? conf_sys_ctrl_reg_RUN_TIME_INTERVAL : rerun_time_interval_q);

/////////////config_dig_spin_pre_prog_ic && config_dig_spin_prog_ic
assign config_dig_spin_pre_prog_ic = run_start_pos_edge && !conf_sys_ctrl_reg_RERUN;

always_ff @(posedge i_clk or negedge i_rstn)
    if(~i_rstn)
    begin
        config_dig_spin_pre_prog_ic_q <= '0;
        config_dig_spin_pre_prog_ic_qq <= '0;
    end
    else
    begin
        config_dig_spin_pre_prog_ic_q <= config_dig_spin_pre_prog_ic;
        config_dig_spin_pre_prog_ic_qq <= config_dig_spin_pre_prog_ic_q;
    end

assign config_dig_spin_prog_ic = config_dig_spin_pre_prog_ic_qq? 1'b1 : 1'b0; 

////////////config_dig_spin_fix_ena && dig_anneal_sch_reg
always_ff @(posedge i_clk or negedge i_rstn)
    if (~i_rstn)
    begin
        run_start_pos_edge_q <= 0;
        run_start_pos_edge_qq <= 0;
        run_start_pos_edge_qqq <= 0;
    end
    else 
    begin
        run_start_pos_edge_q <= conf_sys_ctrl_reg_RESET_pos_edge ? 0 : run_start_pos_edge;
        run_start_pos_edge_qq <= conf_sys_ctrl_reg_RESET_pos_edge ? 0 : run_start_pos_edge_q;
        run_start_pos_edge_qqq <= conf_sys_ctrl_reg_RESET_pos_edge ? 0 : run_start_pos_edge_qq;//spin_fix_ena is set 3 cycles aftet the start (refer to Yongchao's time diagram)
    end

/////////////Langevine control/output signals (active for 16 cycles regardless of the runtime value)
always_ff @(posedge i_clk or negedge i_rstn)
    if(~i_rstn)
      begin
        config_dig_langevine_ena_cnt <= '0;
        config_dig_langevine_ena_cnt_start <= '0;
        config_dig_langevin_ena <= '0;
      end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        config_dig_langevine_ena_cnt <= '0;
        config_dig_langevine_ena_cnt_start <= '0;
        config_dig_langevin_ena <= '0;
    end
    else if (run_start_pos_edge_qqq && !config_dig_langevine_ena_cnt_start)//we want this enabled 3 cycles after run/rerun starts
      begin
        config_dig_langevine_ena_cnt_start <= 1'b1;
        config_dig_langevin_ena <= conf_fix_langevin_sel[0] ? 1'b1 : 1'b0;
      end
    else if (config_dig_langevine_ena_cnt_start && config_dig_langevine_ena_cnt < 5'd15)
      begin
        config_dig_langevine_ena_cnt <=  config_dig_langevine_ena_cnt + 5'd1;
        config_dig_langevine_ena_cnt_start <= 1'b1;
        config_dig_langevin_ena <= conf_fix_langevin_sel[0] ? 1'b1 : 1'b0;
      end
    else
      begin
        config_dig_langevine_ena_cnt <=  '0;
        config_dig_langevin_ena <= '0;
        config_dig_langevine_ena_cnt_start <= '0;
      end
assign config_dig_langevin_res_bank_ctrl = config_dig_langevin_ena ? (1 << config_dig_langevine_ena_cnt) : '0;

////////////Spin fix control/output signals (active for runtime - 3 initial cycles - 4 settle down cycles)
////////////Using Aclk for spin fix/////////////////////////////////////////////////
always_ff @(posedge i_clk or negedge i_rstn)
    if(~i_rstn)
      begin
        config_dig_spin_fix_ena_cnt <= '0;
        config_dig_spin_fix_ena_cnt_start <= '0;
        config_dig_spin_fix_ena <= '0;
      end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        config_dig_spin_fix_ena_cnt <= '0;
        config_dig_spin_fix_ena_cnt_start <= '0;
        config_dig_spin_fix_ena <= '0;
    end
    else if (run_start_pos_edge_qqq && !config_dig_spin_fix_ena_cnt_start)//we want this enabled 3 cycles after run/rerun starts
      begin
        config_dig_spin_fix_ena_cnt_start <= 1'b1;
        config_dig_spin_fix_ena <= conf_fix_langevin_sel[1] ? 1'b1 : 1'b0;
      end
    else if (config_dig_spin_fix_ena_cnt_start && (config_dig_spin_fix_ena_cnt < (current_run_rerun_time - 8'd7)))
      begin
        config_dig_spin_fix_ena_cnt <=  config_dig_spin_fix_ena_cnt + 8'd1;
        config_dig_spin_fix_ena_cnt_start <= 1'b1;
        config_dig_spin_fix_ena <= conf_fix_langevin_sel[1] ? 1'b1 : 1'b0;
      end
    else
      begin
        config_dig_spin_fix_ena_cnt <=  '0;
        config_dig_spin_fix_ena_cnt_start <= '0;
        config_dig_spin_fix_ena <= '0;
      end


assign spin_fix_ena = config_dig_spin_fix_ena;

always_ff @(posedge ACLK or negedge i_rstn)
    if(~i_rstn)
        ACLK_counter_spin_fix <= '0;
    else if (spin_fix_ena && ACLK_counter_spin_fix != 7'd127)
        ACLK_counter_spin_fix <=  ACLK_counter_spin_fix + 7'd1;
    else //if (~spin_fix_ena)
        ACLK_counter_spin_fix <= '0;
  
assign dig_anneal_sch_reg = spin_fix_ena ? conf_dig_anneal_sch_reg[ACLK_counter_spin_fix] : 0;

/*logic [127:0] conf_dig_anneal_sch_reg_shift;
assign dig_anneal_sch_reg = config_dig_spin_fix_ena ? conf_dig_anneal_sch_reg_shift[0] : 1'b0;

always_ff @(posedge ACLK or negedge i_rstn)
    if(~i_rstn)
        conf_dig_anneal_sch_reg_shift <= '0;
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
        conf_dig_anneal_sch_reg_shift <= '0;
    else if (config_dig_spin_fix_ena)
        conf_dig_anneal_sch_reg_shift <= conf_dig_anneal_sch_reg_shift >> 1;
    else if (~config_dig_spin_fix_ena)
        conf_dig_anneal_sch_reg_shift <= conf_dig_anneal_sch_reg;*/

////////////config_dig_spin_read_out_ena: enable this one cycle before run/rerun ends 
always_ff @(posedge i_clk or negedge i_rstn)
    if(~i_rstn)
        config_dig_spin_read_out_ena <= '0;
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
        config_dig_spin_read_out_ena <= '0;
    else if (run_time_counter == 8'd3)
        config_dig_spin_read_out_ena <= 1'b1;
    else
        config_dig_spin_read_out_ena <= '0;

always_ff @(posedge i_clk or negedge i_rstn)//the spin read out value is valid one cycle after config_dig_spin_read_out_ena
    if(~i_rstn)
        config_dig_spin_read_out_ena_q <= '0;
    else
        config_dig_spin_read_out_ena_q <= conf_sys_ctrl_reg_RESET_pos_edge ? 0 : config_dig_spin_read_out_ena;

////////////final run to start reading out spins from RF to GPIO
assign total_output_count = conf_reg_total_rerun_count + conf_reg_total_run_count;
assign final_run = (((run_counter+rerun_counter) == total_output_count) && (total_output_count != 8'd0)) ? 1'b1 : 1'b0;

///////sync control signals with read coefficient_rf///////////////////////////
always_ff @(posedge i_clk or negedge i_rstn)
begin
    if(~i_rstn)
    begin
        sync_coefficient_rf_rd_addr <= '0;
        sync_inc_counter_en <= '0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        sync_coefficient_rf_rd_addr <= '0;
        sync_inc_counter_en <= '0;
    end
    else if (start_programming_q && sync_coefficient_rf_rd_addr<6'd50 && !sync_inc_counter_en)
        sync_inc_counter_en <= 1'b1;
    else if (start_programming_q && sync_coefficient_rf_rd_addr<6'd50 && sync_inc_counter_en)
    begin
        sync_coefficient_rf_rd_addr <= sync_coefficient_rf_rd_addr + 1;
        sync_inc_counter_en <= '0;
    end
    else
    begin
        sync_inc_counter_en <= '0;
    end
end

/////////////config_dig_cu_prog_ena
assign start_programming = (conf_sys_ctrl_reg_LOAD && sync_coefficient_rf_rd_addr<6'd50) ? 1'b1 : 1'b0; 
always_ff @(posedge i_clk or negedge i_rstn) 
    if (~i_rstn)
    begin
         start_programming_q <= 0;
    end
    else
        start_programming_q <= conf_sys_ctrl_reg_RESET_pos_edge ? 0 : config_dig_spin_prog_ic;

assign config_dig_cu_prog_ena = (start_programming_q && !sync_inc_counter_en) ? (sync_coefficient_rf_rd_addr<6'd50 ?  (1 << (6'd49-sync_coefficient_rf_rd_addr)) : '0) : '0;
assign conf_sys_stat_reg_LOADING_DONE = ~(sync_coefficient_rf_rd_addr<6'd50);

endmodule



