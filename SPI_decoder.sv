module SPI_decoder (
    input i_clk,
    input i_rstn,

    input                o_RX_DV, // Data Valid pulse (1 clock cycle)
    input [7:0]          o_RX_Byte, // Byte received on MOSI
    output logic         i_TX_DV, // Data Valid pulse to register i_TX_Byte
    output logic [7:0]   i_TX_Byte, // Byte to serialize to MISO.


    output logic conf_sys_ctrl_reg_RESET, //0 -> 00000
    output logic conf_sys_ctrl_reg_INIT, //1 -> 00001
    output logic conf_sys_ctrl_reg_LOAD, //2 -> 00010
    output logic conf_sys_ctrl_reg_RUN, //3 -> 00011
    output logic [7:0] conf_sys_ctrl_reg_RUN_TIME_INTERVAL, //4 -> 00100
    output logic conf_sys_ctrl_reg_RERUN, //5 -> 00101

    //input conf_sys_stat_reg_ERROR, //8 -> 01000
    input conf_sys_stat_reg_FIFO_FULL, //9 -> 01001
    input conf_sys_stat_reg_BUFFER_FULL, //10 -> 01010
    //input conf_sys_stat_reg_SPI_ERR, //11 -> 01011
    input conf_sys_stat_reg_LOADING_DONE, //12 -> 01100
    input conf_sys_stat_reg_RUNNING, //13 -> 01101
    //input conf_sys_stat_reg_SAMPLING, //14 -> 01110

    output logic [15:0] conf_dig_Ibias_spin_ctrl,//16 -> 10000
    output logic [1:0]  conf_fix_langevin_sel, //17 -> 10001 
    output logic [23:0] conf_reg_GPIO_offest, //18 -> 10010 
    output logic        conf_dig_noise_sample_clk_sel,//19 -> 10011
    output logic [127:0] conf_dig_anneal_sch_reg,//20 -> 10100
    output logic [1:0]  conf_dig_spin_fix_polarity,//21 -> 10101
    output logic [2:0]  conf_dig_langevin_gain_ctrl,//22 -> 10110
    output logic [7:0]  conf_reg_total_run_count, //23 -> 10111
    output logic [7:0]  conf_reg_total_rerun_count, //24 -> 11000
    output logic [7:0]  conf_reg_GPIO_DS, //26 -> 11010
    output logic [7:0]  conf_reg_GPIO_PE, //27 -> 11011
    output logic [49:0] conf_reg_bias_en, //28 -> 011100
    output logic [5:0]  conf_reg_coupler_cal_bias_ctrl //29 -> 011101
);



typedef enum bit[1:0] {SET=0, RESET=1, WRITE=2, READ=3} e_command;
e_command config_register_command;
e_command config_register_command_q;
logic [4:0] cfg_reg_transfer_count;
logic [5:0] config_register_address;
logic [5:0] config_register_address_q;
logic [7:0] conf_reg_test_SPI;



always_ff @(posedge i_clk or negedge i_rstn)
begin
    if(~i_rstn)
    begin
        config_register_command_q <= e_command'('0);
        config_register_address_q <= '0;
    end 
    else
    begin
        config_register_command_q <= config_register_command;
        config_register_address_q <= config_register_address;
    end
end
assign config_register_command = (|cfg_reg_transfer_count || !o_RX_DV)? config_register_command_q : e_command'(o_RX_Byte[7:6]);
assign config_register_address = (|cfg_reg_transfer_count || !o_RX_DV)? config_register_address_q : o_RX_Byte[5:0]; 


always_ff @(posedge i_clk or negedge i_rstn)
begin
    if (~i_rstn)
    begin
        cfg_reg_transfer_count <= '0;
        conf_sys_ctrl_reg_RESET <= '0;
        conf_sys_ctrl_reg_INIT <= '0;
        conf_sys_ctrl_reg_LOAD <= '0;
        conf_sys_ctrl_reg_RUN <= '0;
        conf_sys_ctrl_reg_RUN_TIME_INTERVAL <= '0;
        conf_sys_ctrl_reg_RERUN <= '0;
        conf_dig_Ibias_spin_ctrl <= '0;
        conf_fix_langevin_sel <= '0;
        conf_dig_noise_sample_clk_sel <= '0;
        conf_dig_spin_fix_polarity<= '0;
        conf_dig_langevin_gain_ctrl <= '0;
        conf_dig_anneal_sch_reg <= '0;
        conf_reg_total_run_count <= '0;
        conf_reg_total_rerun_count <= '0;
        conf_reg_test_SPI <= '0;
    end

    else if((config_register_command == WRITE) && o_RX_DV)
    begin
    case (config_register_address)
        6'b000100: begin
            if(cfg_reg_transfer_count == 5'd0)//we have only received command and address so far, next we recieve data 
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_sys_ctrl_reg_RUN_TIME_INTERVAL <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b010101:
        begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_dig_spin_fix_polarity <= o_RX_Byte[1:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b010000: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_dig_Ibias_spin_ctrl [7:0] <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            end
            else if(cfg_reg_transfer_count == 5'd2)
            begin
                conf_dig_Ibias_spin_ctrl [15:8] <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b010001: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_fix_langevin_sel <= o_RX_Byte[1:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b010010: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_GPIO_offest <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            end
            else if (cfg_reg_transfer_count == 5'd2)
            begin
                 conf_reg_GPIO_offest <= {conf_reg_GPIO_offest[15:0], o_RX_Byte[7:0]};
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            end
            else if (cfg_reg_transfer_count == 5'd3)
            begin
                conf_reg_GPIO_offest <= {conf_reg_GPIO_offest[15:0], o_RX_Byte[7:0]};
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b010100: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_dig_anneal_sch_reg <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            end
            else if(cfg_reg_transfer_count < 5'd16) 
            begin
                conf_dig_anneal_sch_reg <= {conf_dig_anneal_sch_reg[119:0], o_RX_Byte[7:0]};
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            end
            else if(cfg_reg_transfer_count == 5'd16) 
            begin
                conf_dig_anneal_sch_reg <= {conf_dig_anneal_sch_reg[119:0], o_RX_Byte[7:0]};
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b010110: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_dig_langevin_gain_ctrl <= o_RX_Byte[2:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b010111: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_total_run_count <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b011000: begin
            if(cfg_reg_transfer_count == 6'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_total_rerun_count <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b011001: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_test_SPI <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b011010: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_GPIO_DS <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b011011: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_GPIO_PE <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= '0;
            end
        end

        6'b011100: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_bias_en <= o_RX_Byte[7:0];
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            end
            else if(cfg_reg_transfer_count < 5'd7) 
            begin
                conf_reg_bias_en <= {conf_dig_anneal_sch_reg[41:0], o_RX_Byte[7:0]};
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            end
            else if(cfg_reg_transfer_count == 5'd7) 
            begin
                conf_reg_bias_en <= {conf_dig_anneal_sch_reg[47:0], o_RX_Byte[1:0]};
                cfg_reg_transfer_count <= '0;
            end
        end
        6'b011101: begin
            if(cfg_reg_transfer_count == 5'd0)
                cfg_reg_transfer_count <= cfg_reg_transfer_count + 5'd1;
            else if(cfg_reg_transfer_count == 5'd1) 
            begin
                conf_reg_coupler_cal_bias_ctrl <= o_RX_Byte[5:0];
                cfg_reg_transfer_count <= '0;
            end
        end
    endcase
    end
    else if((config_register_command == SET) && o_RX_DV)
    begin
        case (config_register_address)
            6'b000000:   conf_sys_ctrl_reg_RESET <= 1'b1;
            6'b000001:   conf_sys_ctrl_reg_INIT <= 1'b1;
            6'b000010:   conf_sys_ctrl_reg_LOAD <= 1'b1;
            6'b000011:   conf_sys_ctrl_reg_RUN <= 1'b1;
            6'b010011:   conf_dig_noise_sample_clk_sel <= 1'b1;
            6'b000101:   conf_sys_ctrl_reg_RERUN <= 1'b1;
        endcase
    end
    else if((config_register_command == RESET) && o_RX_DV)
    begin
        case (config_register_address)
            6'b000000:   conf_sys_ctrl_reg_RESET <= 1'b0;
            6'b000001:   conf_sys_ctrl_reg_INIT <= 1'b0;
            6'b000010:   conf_sys_ctrl_reg_LOAD <= 1'b0;
            6'b000011:   conf_sys_ctrl_reg_RUN <= 1'b0;
            6'b010011:   conf_dig_noise_sample_clk_sel <= 1'b0;
            6'b000101:   conf_sys_ctrl_reg_RERUN <= 1'b0;
        endcase
    end
end

always_comb
    begin
        i_TX_Byte = '0;
        i_TX_DV = '0;
        if ((config_register_command == READ) && o_RX_DV && !(|cfg_reg_transfer_count))//not in the middle of a write operation
        begin
            i_TX_DV = 1'b1;
            case (config_register_address)
                //6'b001000:   i_TX_Byte[0] = conf_sys_stat_reg_ERROR;
                6'b001001:   i_TX_Byte[0] = conf_sys_stat_reg_FIFO_FULL;
                6'b001010:   i_TX_Byte[0] = conf_sys_stat_reg_BUFFER_FULL;
                //6'b001011:   i_TX_Byte[0] = conf_sys_stat_reg_SPI_ERR;
                6'b001100:   i_TX_Byte[0] = conf_sys_stat_reg_LOADING_DONE;
                6'b001101:   i_TX_Byte[0] = conf_sys_stat_reg_RUNNING;
                //6'b001110:   i_TX_Byte[0] = conf_sys_stat_reg_SAMPLING;
                6'b011001:   i_TX_Byte    = conf_reg_test_SPI;       
            endcase
        end
    end

endmodule