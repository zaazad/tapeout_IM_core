module initial_spin_rf_ctrl(
    input i_clk,
    input i_rstn,

    input  [7:0] in_GPIO_sampled,
    input  in_GPIO_valid_sampled,

    input conf_sys_ctrl_reg_INIT,
    input [7:0] conf_reg_total_run_count,
    input conf_sys_ctrl_reg_RERUN,
    input conf_sys_ctrl_reg_RUN,
    input conf_sys_ctrl_reg_RESET,

    input coefficient_rf_wr_done,
    input [7:0] run_counter,

    input [49:0] initial_spin_rf_q,
    
    output logic [49:0] spin_initial,
    output logic [6:0] initial_spin_rf_a,
    output logic [49:0] initial_spin_rf_d,
    output logic initial_spin_rf_web,
    output logic [49:0] initial_spin_rf_bweb
);


logic [7:0] run_counter_initial_spin;//different for run and rerun
logic [49:0]  initial_spin_sr;
logic [6:0]   initial_spin_rf_wr_addr;
logic [2:0]   initial_spin_sr_counter;
logic initial_spin_rf_wr_enable, initial_spin_rf_wr_done;
logic last_config_dig_spin_pre_prog_ic;
logic [49:0] last_initial_spin_rf_q;

/////////////posedge conf_sys_ctrl_reg_INIT
logic conf_sys_ctrl_reg_RESET_q;
logic conf_sys_ctrl_reg_RESET_pos_edge;
always_ff @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn)
        conf_sys_ctrl_reg_RESET_q <= 0;
    else
        conf_sys_ctrl_reg_RESET_q <= conf_sys_ctrl_reg_RESET;
end
assign conf_sys_ctrl_reg_RESET_pos_edge = !conf_sys_ctrl_reg_RESET_q && conf_sys_ctrl_reg_RESET;

///////write initial_spin_rf///////////////////////////
always_ff @(posedge i_clk or negedge i_rstn) 
begin
    if (~i_rstn)
    begin
        initial_spin_rf_wr_addr <= '0;
        initial_spin_rf_wr_enable <= 0;
        initial_spin_rf_wr_done <= 0;
        initial_spin_sr_counter <= '0;
        initial_spin_sr <= '0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        initial_spin_rf_wr_addr <= '0;
        initial_spin_rf_wr_enable <= '0;
        initial_spin_rf_wr_done <= '0;
        initial_spin_sr_counter <= '0;
        initial_spin_sr <= '0;
    end
    else if (conf_sys_ctrl_reg_INIT && in_GPIO_valid_sampled && ~initial_spin_rf_wr_done && coefficient_rf_wr_done) //signal a valid read_write request
    begin
        if(initial_spin_rf_wr_addr < conf_reg_total_run_count)
        begin
            if (initial_spin_sr_counter < 3'd6)
            begin
                initial_spin_sr <= {initial_spin_sr[41:0], in_GPIO_sampled[7:0]};
                initial_spin_sr_counter <= initial_spin_sr_counter + 3'd1;
                initial_spin_rf_wr_enable <= '0;
                initial_spin_rf_wr_done <= '0;
                initial_spin_rf_wr_addr <= initial_spin_rf_wr_enable ? initial_spin_rf_wr_addr + 7'd1 : initial_spin_rf_wr_addr;
            end
            else if (initial_spin_sr_counter == 3'd6)
            begin
                initial_spin_sr <= {initial_spin_sr[47:0], in_GPIO_sampled[1:0]};
                initial_spin_sr_counter <= '0;
                initial_spin_rf_wr_enable <= 1'b1;
                initial_spin_rf_wr_done <= (initial_spin_rf_wr_addr == conf_reg_total_run_count-8'd1) ? 1'b1 : 1'b0;
            end
        end
        else
        begin
            initial_spin_rf_wr_enable <= '0;
            initial_spin_rf_wr_done <= 1'b1;
            initial_spin_sr_counter <= '0;
        end
    end
    else
    begin
        initial_spin_rf_wr_addr <= '0;
        initial_spin_rf_wr_enable <= '0;
    end
end

/////////////run start
logic run_start, run_start_q, run_start_pos_edge;
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

/////////////config_dig_spin_pre_prog_ic
assign config_dig_spin_pre_prog_ic = run_start_pos_edge && !conf_sys_ctrl_reg_RERUN; 

///////read initial_spin_rf///////////////////////////
assign run_counter_initial_spin = conf_sys_ctrl_reg_RERUN ? run_counter-8'd1 : run_counter;

always_ff @(posedge i_clk or negedge i_rstn)
    if(~i_rstn)
        begin
            last_config_dig_spin_pre_prog_ic <= '0;
            last_initial_spin_rf_q <= '0;
        end
    else
        begin
            last_config_dig_spin_pre_prog_ic <= config_dig_spin_pre_prog_ic;
            last_initial_spin_rf_q <= initial_spin_rf_q;
        end

assign spin_initial = config_dig_spin_pre_prog_ic? initial_spin_rf_q : (last_config_dig_spin_pre_prog_ic ? last_initial_spin_rf_q : '0);

assign initial_spin_rf_a = initial_spin_rf_wr_enable? initial_spin_rf_wr_addr : run_counter_initial_spin;
assign initial_spin_rf_bweb = initial_spin_rf_wr_enable ? '0 : '1;
assign initial_spin_rf_web = ~initial_spin_rf_wr_enable;
assign initial_spin_rf_d = initial_spin_sr;

endmodule