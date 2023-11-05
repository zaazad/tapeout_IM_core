module output_spin_rf_ctrl(
    input i_clk,
    input i_rstn,

    input conf_sys_ctrl_reg_RESET,
    input [7:0] conf_reg_total_rerun_count,
    input [7:0] conf_reg_total_run_count,

    input config_dig_spin_CCII_ena,
    input config_dig_spin_read_out_ena_q,
    input final_run,

    input [49:0] spin_read_out,
    input [49:0] output_spin_rf_q,

    output logic output_spin_rf_web,
    output logic [7:0] output_spin_rf_a,
    output logic [49:0] output_spin_rf_d,
    output logic [49:0] output_spin_rf_bweb,

    output logic [7:0]  out_GPIO,
    output logic        out_GPIO_valid,
    output logic        GPIO_IE,
    output logic        GPIO_OEN
);


logic spin_read_out_write_ena, spin_read_out_write_ena_q;
logic out_GPIO_valid_setup;
logic [7:0]   output_spin_rf_wr_addr;
logic [2:0]   output_spin_sr_counter;
logic output_spin_rf_wr_enable;
logic [7:0]   output_spin_rf_rd_addr;
logic output_spin_rf_rd_enable;
logic [49:0] output_spin_rf_rd_tmp;


logic [7:0] total_output_count;
assign total_output_count = conf_reg_total_rerun_count + conf_reg_total_run_count;

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


/////write output_spin_rf //////////////////////////
always_ff @(posedge i_clk or negedge i_rstn) 
begin
    if (~i_rstn)
    begin
        output_spin_rf_wr_addr <= '0;
        output_spin_rf_wr_enable <= '0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        output_spin_rf_wr_addr <= '0;
        output_spin_rf_wr_enable <= '0;
    end
    else if(output_spin_rf_wr_addr < total_output_count && config_dig_spin_read_out_ena_q)//output is valid one cycle after config_dig_spin_read_out_ena
    begin
        output_spin_rf_wr_enable <= 1'b1;
    end
    else
    begin
        output_spin_rf_wr_addr <= conf_sys_ctrl_reg_RESET_pos_edge ? '0 : output_spin_rf_wr_addr + output_spin_rf_wr_enable;
        output_spin_rf_wr_enable <= '0;
    end
end

assign output_spin_rf_a = output_spin_rf_wr_enable? output_spin_rf_wr_addr : output_spin_rf_rd_addr;
assign output_spin_rf_bweb = output_spin_rf_wr_enable ? '0 : '1;
assign output_spin_rf_web = ~output_spin_rf_wr_enable;
assign output_spin_rf_d = spin_read_out;
assign output_spin_rf_rd_tmp = output_spin_rf_q;

/////read output_spin_rf/////////////////////////
assign spin_read_out_write_ena = !config_dig_spin_CCII_ena && !config_dig_spin_read_out_ena_q
                                  && !output_spin_rf_wr_enable && final_run 
                                  && (output_spin_rf_rd_addr < total_output_count);

always_ff @(posedge i_clk or negedge i_rstn)
    if(~i_rstn)
        spin_read_out_write_ena_q <= '0;
    else
        spin_read_out_write_ena_q <= spin_read_out_write_ena;

assign output_spin_rf_rd_enable = spin_read_out_write_ena_q ? (((output_spin_rf_rd_addr < 8'd200) && (output_spin_sr_counter <= 3'd6)) ? 1'b1 : 1'b0)
                                                          : 1'b0;


always_ff@(negedge i_clk or negedge i_rstn)//out_GPIO_valid should be set to 1, half a cycle before output
    if(~i_rstn)
        out_GPIO_valid_setup <= '0;
    else
        out_GPIO_valid_setup <= spin_read_out_write_ena;


always_ff @(posedge i_clk or negedge i_rstn) 
begin
    if (~i_rstn)
    begin
        output_spin_rf_rd_addr <= '0;
        output_spin_sr_counter <= '0;
    end
    else if (conf_sys_ctrl_reg_RESET_pos_edge)
    begin
        output_spin_rf_rd_addr <= '0;
        output_spin_sr_counter <= '0;
    end
    else if (spin_read_out_write_ena_q)//wait for last run to complete
    begin
        if(output_spin_rf_rd_addr < total_output_count)//read out entire output spin RF (runs and reruns)
        begin
            if (output_spin_sr_counter < 3'd6)
                output_spin_sr_counter <= output_spin_sr_counter + 3'd1;
            else
            begin 
                output_spin_rf_rd_addr <= output_spin_rf_rd_addr + 8'd1;
                output_spin_sr_counter <= '0;
            end
        end
    end
end


//out_GPIO_valid, GPIO_IE, and GPIO_OEN should stay 1 until one cycle after data transfer is done => output_spin_rf_rd_enable handles this
assign out_GPIO_valid = out_GPIO_valid_setup || output_spin_rf_rd_enable;
assign out_GPIO = output_spin_rf_rd_enable  ? ((output_spin_sr_counter == 3'd0) ? output_spin_rf_rd_tmp[7:0]   : 
                                              (output_spin_sr_counter == 3'd1) ? output_spin_rf_rd_tmp[15:8]  :
                                              (output_spin_sr_counter == 3'd2) ? output_spin_rf_rd_tmp[23:16] :
                                              (output_spin_sr_counter == 3'd3) ? output_spin_rf_rd_tmp[31:24] :
                                              (output_spin_sr_counter == 3'd4) ? output_spin_rf_rd_tmp[39:32] :
                                              (output_spin_sr_counter == 3'd5) ? output_spin_rf_rd_tmp[47:40] :
                                              (output_spin_sr_counter == 3'd6) ? {6'd0,output_spin_rf_rd_tmp[49:48]} :'0
                                             ) : '0;

assign GPIO_IE  = (out_GPIO_valid || final_run) ? 1'b0 : 1'b1;
assign GPIO_OEN = (out_GPIO_valid || final_run) ? 1'b0 : 1'b1;

endmodule