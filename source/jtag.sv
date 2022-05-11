//////////////////////////////////////////////////
//~:(
//@module: jtag.sv
//@author: Yafizov Airat
//@date: 05.05.2022
//@version: 1.0.0
//@description: jtag_interface
//~:)
//////////////////////////////////////////////////

module jtag
    #(
    parameter DATA_INSTRACTION = 10,
    parameter DATA_DATA = 8,
    parameter FIFO_DEPTH = 16
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //INPUT_CONTROL
    input logic [15:0] len,
    input logic op,
    /*
    1-запись в дату,0-запись tms + иструкции
    */
    input logic work,
    //OUTPUT_CONTROL
    output logic busy,
    //INPUT_SPI
    input logic tdo,
    //OUTPUT_SPI
    output logic tdi,
    output logic tck,
    output logic tms,
    //OUTPUT_FIFO_instraction
    output logic [(DATA_INSTRACTION-1):0] wdata_instraction,
    output logic wr_instraction,
    input logic full_instraction,
    //INPUT_FIFO_intraction
    input logic  [(DATA_INSTRACTION-1):0] rdata_instraction,
    output logic rd_instraction,
    input logic empty_instraction,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_instraction,
    //OUTPUT_FIFO_data
    output logic [(DATA_DATA-1):0] wdata_data,
    output logic wr_data,
    input logic full_data,
    //INPUT_FIFO_data
    input logic  [(DATA_DATA-1):0] rdata_data,
    output logic rd_data,
    input logic empty_data,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_data
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [2:0] {ST_IDLE, ST_INSTRACTION, ST_TDI, ST_TDO, ST_PRE_TDO, ST_PRE_TDI, ST_PRE_INSTRACTION} state_type;

//////////////////////////////////////////////////
//Local params
//////////////////////////////////////////////////

// поддерживаются делители 1 и 2
localparam FREQUENCY_DIVIDER = 1;
localparam DELAY= FREQUENCY_DIVIDER * 2;
localparam DATA_TMS = 4;

//initial constants
localparam GO_SHIFT_IR = 4'b1100;
localparam GO_SHIFT_DR = 4'b0100;
localparam GO_EXIT = 4'b1100;

//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////
logic [15:0] count;
logic [15:0] counttransaction; 
logic [(DATA_TMS - 1) :0] shifttms;
logic [(DATA_TMS - 1) :0] nextshifttms;
logic [(DATA_INSTRACTION - 1) :0] shiftinstraction;
logic [(DATA_INSTRACTION - 1) :0] nextshiftinstraction;
state_type state;
logic countenable;



//////////////////////////////////////////////////
//counter
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (rst) begin
            count <= 0;
        end
    else if ((FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + 2 * DELAY) == count) begin
            count <= 0;
        end
    else if (countenable == 1) begin
            count <= count + 1;
        end
    else begin
        count <= 0;
    end
end

//////////////////////////////////////////////////
//counter of transaction
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (rst) begin
            counttransaction <= 0;
        end
    else if ((len + 2 * DATA_TMS) == counttransaction) begin
            counttransaction <= 0;
        end
    else if ((countenable == 1) && (((DELAY + FREQUENCY_DIVIDER * 2 * counttransaction) - count) == 1))  begin
            counttransaction <= counttransaction + 1;
        end
end

//////////////////////////////////////////////////
//Shift register
//////////////////////////////////////////////////
always_ff @ (negedge clk) begin
    if (rst) begin
        nextshiftinstraction <= 0;
        nextshifttms <= 0;
    end
    else begin
        nextshiftinstraction <= shiftinstraction;
        nextshifttms <= shifttms;
    end
end

//////////////////////////////////////////////////
//Mosi retiming
//////////////////////////////////////////////////

assign tms = nextshifttms [(DATA_TMS - 1)];
assign tdi = nextshiftinstraction [(DATA_INSTRACTION - 1)];

//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        shiftinstraction <= 0;
        shifttms <= 0;
        state <= ST_IDLE;
        countenable <= 0;
        rd_data <=0; rd_instraction <=0; 
        busy <=0;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                shiftinstraction <= 0;
                shifttms <= 0;
                rd_data <=0; rd_instraction <=0; 
                if ((work == 1) && (op == 0)) begin
                    state <= ST_PRE_INSTRACTION;
                    busy <= 1;
                end 
                if ((work == 1) && (op == 1)) begin
                    state <= ST_PRE_TDO;
                    busy <= 1;
                end 
            end
            //////////////////////////////////////////////////
            ST_INSTRACTION : begin 
                if ((FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + 2 * DELAY) == count) begin 
                    rd_instraction <= 0;
                    state <= ST_IDLE;
                    busy <= 0;
                    countenable <= 0;
                end
                else if (count == (DELAY - FREQUENCY_DIVIDER * 2)) begin
                    shifttms [(DATA_TMS - 1):0] <= GO_SHIFT_IR;
                end
                else if ((count > (DELAY - 1)) && (count < (FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + DELAY)) && (count == ((counttransaction - 1) * FREQUENCY_DIVIDER * 2 + DELAY))) begin 
                    if (counttransaction < (DATA_TMS + 1)) begin
                        if (counttransaction == DATA_TMS) begin
                            shifttms <= {nextshifttms[(DATA_TMS - 2):0], 1'b0};
                            shiftinstraction [(DATA_INSTRACTION - 1):0] <= rdata_instraction [(DATA_INSTRACTION - 1):0];
                            rd_instraction <= 1;
								end
                        else begin
                            shifttms <= {nextshifttms[(DATA_TMS - 2):0], 1'b0};
                            rd_instraction <= 0;
                        end
                    end
                    else if (counttransaction < (DATA_TMS + len + 1)) begin
                        if (counttransaction == (DATA_TMS + len)) begin 
                            shifttms [(DATA_TMS - 1):0] <= GO_EXIT;
                            shiftinstraction <= {nextshiftinstraction [(DATA_INSTRACTION-2):0], 1'b0};
                            rd_instraction <= 0;
								end
                        else begin
                            shiftinstraction <= {nextshiftinstraction [(DATA_INSTRACTION-2):0], 1'b0};
                            rd_instraction <= 0;
                        end
                    end
                    else if (counttransaction < (DATA_TMS * 2 + len + 1)) begin
                        shifttms <= {nextshifttms[(DATA_TMS - 2):0],1'b0};
                        rd_instraction <= 0;
                    end
                end 
                else begin
                    rd_instraction <= 0;
                end 
            end
            //////////////////////////////////////////////////
            ST_TDO : begin 
                if ((FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + 2 * DELAY) == count) begin 
                    rd_instraction <= 0;
                    state <= ST_IDLE;
                    busy <= 0;
                    countenable <= 0;
                end
                else if (count == (DELAY - FREQUENCY_DIVIDER * 2)) begin
                    shifttms [(DATA_TMS - 1):0] <= GO_SHIFT_DR;
                end
                else if ((count > (DELAY - 1)) && (count < (FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + DELAY)) && (count == ((counttransaction - 1) * FREQUENCY_DIVIDER * 2 + DELAY))) begin 
                    if (counttransaction < (DATA_TMS + 1)) begin
                        shifttms <= {nextshifttms[(DATA_TMS - 2):0], 1'b0};
                    end
                    else if (counttransaction == (DATA_TMS + len)) begin 
                        shifttms [(DATA_TMS - 1):0] <= GO_EXIT;
                    end
                    else if (counttransaction < (DATA_TMS * 2 + len + 1)) begin
                        shifttms <= {nextshifttms[(DATA_TMS - 2):0], 1'b0};
                    end
                end 
            end
            //////////////////////////////////////////////////
            ST_PRE_TDO : begin  
                state <= ST_TDO;
                countenable <= 1;
            end
            //////////////////////////////////////////////////
            ST_PRE_INSTRACTION : begin  
                state <= ST_INSTRACTION;
                countenable <= 1;
            end
            //////////////////////////////////////////////////
            default : begin 
                state <= ST_IDLE;
            end
         endcase
    end
end

//////////////////////////////////////////////////
//tck impulse generation logic
//////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if(rst) begin
        tck <= 0;
    end 
     else if (count == DELAY) begin
                tck <= 1;
        end
        else if ((count[FREQUENCY_DIVIDER - 1] == 0) && (count > (DELAY)) && (count < (FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + DELAY))) begin
                tck <= 1;
        end 
        else begin 
            tck <= 0;
        end
end


//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
