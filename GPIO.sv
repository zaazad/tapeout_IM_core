module GPIO(
    input               i_clk,
    input               i_rstn,
    input  [7:0]        in_GPIO_retimed,
    input               in_GPIO_valid,

    output logic [7:0]  in_GPIO_sampled,
    output logic        in_GPIO_valid_sampled,

    input  [7:0]        out_GPIO_rf,
    input               out_GPIO_valid_rf,
    output logic [7:0]  out_GPIO,
    output logic        out_GPIO_valid
);


always_ff @(negedge i_clk or negedge i_rstn)
    if(~i_rstn)
    begin
        in_GPIO_valid_sampled <= '0;
        in_GPIO_sampled <= '0;
    end
    else
    begin
        in_GPIO_valid_sampled <= in_GPIO_valid;
        in_GPIO_sampled <= in_GPIO_retimed;
    end


assign out_GPIO = out_GPIO_rf;
assign out_GPIO_valid = out_GPIO_valid_rf;

endmodule