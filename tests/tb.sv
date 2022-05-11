//////////////////////////////////////////////////
//~:(
//@module: Spi_interface_test.sv
//@author: Yafizov Airat
//@date: 15.12.2021
//@version: 1.0.0
//@description: testbench 
//~:)
//////////////////////////////////////////////////
`timescale 10 ns/10 ns
//////////////////////////////////////////////////
module tb;

//////////////////////////////////////////////////
//Local signals
//////////////////////////////////////////////////

logic clk;
logic rst;
logic [15:0] len;
logic [9:0] rdata_instraction;
logic [7:0] rdata_data;
logic work;
logic op;
logic tdo;

//////////////////////////////////////////////////
//Tested module
//////////////////////////////////////////////////

jtag jtag_inst (
    .clk(clk), .rst(rst),
    .len(len), .rdata_instraction(rdata_instraction),
    .rdata_data(rdata_data),
    .work(work), .op(op),
    .tdo(tdo)
    );

//////////////////////////////////////////////////
//Test
//////////////////////////////////////////////////

initial
    begin
        rst = 1;
        #10;
        rst = 0;
        #10;
        op = 0;
        work = 1;
        rdata_instraction = 10'b0110011100;
        len = 10;
        #10;
        work = 0;
        #400;
        op = 1;
        work = 1;
        #400;
        work = 0;
    end

//////////////////////////////////////////////////
//clk
//////////////////////////////////////////////////

initial                                                
    begin                                                  
        clk=0;
        forever #5 clk=~clk;
    end

initial                                                
    begin                                                  
        tdo=0;
        forever #10 tdo=~tdo;
    end

endmodule
