module coefficient_rf_ctrl(
    input i_clk,
    input i_rstn,

    input  [7:0]   in_GPIO_sampled,
    input in_GPIO_valid_sampled,

    input  conf_sys_ctrl_reg_RESET,
    input conf_sys_ctrl_reg_INIT,
    input conf_sys_ctrl_reg_LOAD,

    output logic [5:0] coefficient_rf_part1_a,
    output logic [127:0] coefficient_rf_part1_bweb,
    output logic coefficient_rf_part1_web,
    output logic [127:0] coefficient_rf_part1_d ,

    output logic [5:0] coefficient_rf_part2_a,
    output logic [127:0] coefficient_rf_part2_bweb,
    output logic coefficient_rf_part2_web,
    output logic [127:0] coefficient_rf_part2_d,

    output logic [5:0] spin_polarity_a,
    output logic [49:0] spin_polarity_bweb,
    output logic spin_polarity_web,
    output logic [49:0] spin_polarity_d,

    output logic coefficient_rf_wr_done,

    output logic [127:0] coefficients_part_1_tmp,       
    output logic [127:0] coefficients_part_2_tmp,
    output logic [49:0] spin_polarity_tmp,

    input [127:0] coefficient_rf_part1_q,
    input [127:0] coefficient_rf_part2_q,
    input  [49:0] spin_polarity_q
);


logic [5:0]   coefficient_rf_rd_addr;
logic [305:0] coefficient_sr;//we wanted to store and use the whole 128*2 bit => 256 + 50
logic [5:0]   coefficient_rf_wr_addr;
logic [5:0]   coefficient_sr_counter;
logic coefficient_rf_wr_enable;
logic config_dig_spin_prog_ic_q;

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

///////write coefficient_rf///////////////////////////
always_ff @(posedge i_clk or negedge i_rstn)
begin
    if (~i_rstn)
    begin
        coefficient_rf_wr_addr <= '0;
        coefficient_rf_wr_enable <= '0;
        coefficient_rf_wr_done <= '0;
        coefficient_sr <= '0;
        coefficient_sr_counter <= '0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        coefficient_rf_wr_addr <= '0;
        coefficient_rf_wr_enable <= '0;
        coefficient_rf_wr_done <= '0;
        coefficient_sr <= '0;
        coefficient_sr_counter <= '0;
    end
    else if (conf_sys_ctrl_reg_INIT && in_GPIO_valid_sampled && ~coefficient_rf_wr_done) //signal a valid read_write request
    begin
        if(coefficient_rf_wr_addr < 6'd50)
        begin
            if(coefficient_sr_counter < 6'd38)
            begin
                coefficient_sr <= {coefficient_sr[297:0], in_GPIO_sampled[7:0]};
                coefficient_sr_counter <= coefficient_sr_counter + 6'd1;
                coefficient_rf_wr_enable <= '0;
                coefficient_rf_wr_done <= '0;
                coefficient_rf_wr_addr <= coefficient_rf_wr_enable ? coefficient_rf_wr_addr + 6'd1 : coefficient_rf_wr_addr;
             end
            else if(coefficient_sr_counter == 6'd38)
            begin
                coefficient_sr <= {coefficient_sr[304:0], in_GPIO_sampled[1:0]};
                coefficient_sr_counter <= '0;
                coefficient_rf_wr_enable <= 1'b1;
                coefficient_rf_wr_done <= (coefficient_rf_wr_addr == 6'd49) ? 1'b1 : 1'b0;
            end
        end
        else
        begin
            coefficient_rf_wr_enable <= '0;
            coefficient_rf_wr_done <= 1'b1;
            coefficient_sr_counter <= '0;
        end
    end
    else 
    begin
        coefficient_rf_wr_addr <= '0;
        coefficient_rf_wr_enable <= '0;
    end
end

assign coefficient_rf_part1_a = coefficient_rf_wr_enable? coefficient_rf_wr_addr : coefficient_rf_rd_addr;
assign coefficient_rf_part1_bweb = coefficient_rf_wr_enable ? '0 : '1;
assign coefficient_rf_part1_web = ~coefficient_rf_wr_enable;
assign coefficient_rf_part1_d = coefficient_sr[127:0];

assign coefficient_rf_part2_a = coefficient_rf_wr_enable? coefficient_rf_wr_addr : coefficient_rf_rd_addr;
assign coefficient_rf_part2_bweb = coefficient_rf_wr_enable ? '0 : '1;
assign coefficient_rf_part2_web = ~coefficient_rf_wr_enable;
assign coefficient_rf_part2_d = coefficient_sr[255:128];


assign spin_polarity_a = coefficient_rf_wr_enable? coefficient_rf_wr_addr : coefficient_rf_rd_addr;
assign spin_polarity_bweb = coefficient_rf_wr_enable ? '0 : '1;
assign spin_polarity_web = ~coefficient_rf_wr_enable;
assign spin_polarity_d = coefficient_sr[305:256];

///////read coefficient_rf///////////////////////////
logic inc_counter_en;
always_ff @(posedge i_clk or negedge i_rstn)
begin
    if(~i_rstn)
    begin
        coefficient_rf_rd_addr <= '0;
        inc_counter_en <= '0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        coefficient_rf_rd_addr <= '0;
        inc_counter_en <= '0;
    end
    else if (config_dig_spin_prog_ic_q && coefficient_rf_rd_addr<6'd50 && !inc_counter_en)
        inc_counter_en <= 1'b1;
    else if (config_dig_spin_prog_ic_q && coefficient_rf_rd_addr<6'd50 && inc_counter_en)
    begin
        coefficient_rf_rd_addr <= coefficient_rf_rd_addr + 1;
        inc_counter_en <= '0;
    end
    else
    begin
        inc_counter_en <= '0;
    end
end

/////////////config_dig_spin_prog_ic
assign config_dig_spin_prog_ic = (conf_sys_ctrl_reg_LOAD && coefficient_rf_rd_addr<6'd50) ? 1'b1 : 1'b0; 
always_ff @(posedge i_clk or negedge i_rstn) 
    if (~i_rstn)
    begin
         config_dig_spin_prog_ic_q <= 0;
    end
    else
        config_dig_spin_prog_ic_q <= conf_sys_ctrl_reg_RESET_pos_edge ? 0 : config_dig_spin_prog_ic;

assign coefficients_part_1_tmp = config_dig_spin_prog_ic_q ? (coefficient_rf_rd_addr<6'd50 ?  coefficient_rf_part1_q : '0) : '0;
assign coefficients_part_2_tmp = config_dig_spin_prog_ic_q ? (coefficient_rf_rd_addr<6'd50 ?  coefficient_rf_part2_q : '0) : '0;
assign spin_polarity_tmp = config_dig_spin_prog_ic_q ? (coefficient_rf_rd_addr<6'd50 ?  spin_polarity_q : '0) : '0;


endmodule