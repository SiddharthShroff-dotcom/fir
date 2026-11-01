module fir_serial #(
    parameter DATA_W = 16,   // input width
    parameter COEF_W = 16,   // coefficient width
    parameter ACC_W  = 35,    // accumulator width
    parameter HIST = 8,    // number of samples to keep in history
    parameter signed WEIGHT = 1 //set constant weight 
    // WEIGHT value is a constant here, so the multiplier is simpler than a general one. 
    //In terms of area results, it means synthesis can optimize it.
) (input wire clk, 
input wire reset, 
input wire in_valid,
output reg out_valid,
input wire signed [DATA_W-1:0] x_in, 
output reg signed [ACC_W-1:0] y_out
);

//we need to know when a new sample has arrived: when in_Valid is raised
// if it is then start the 8 cycle multiplication and accumulation process
//every cycle for the next 8 cycles we will multiply the input sample by the corresponding coefficient and accumulate the result
//once done this process, raise out_valid for one cycle and output the result on y_outo
//then wait for the next sample to arrive
//we will use a counter to keep track of the number of cycles we have been in the multiplication and accumulation process
//we need to keep a tag to show that we are busy during the 8 cycles of multiplication and accumulation so that we don't start a 
//new multiplication and accumulation process until the current one is done

reg signed [DATA_W-1:0] shift_reg [0:HIST-1]; // 8 stage shift register to hold the input samples 
//gets updated once every time a new input is received

reg signed [ACC_W-1:0] accumulator;
reg [3:0] counter; // 4 bits to count up to 8
wire busy; 
assign busy = (counter !=0); //if counter is not zero then we are busy
integer i;

wire signed [DATA_W-1:0] operand = (counter == 0) ? x_in : shift_reg[counter[2:0]]; 
//so we dont access shift_reg[8] which is out of bounds, we use counter[2:0]

wire signed [ACC_W-1:0] product = operand * WEIGHT; //multiply the input sample by the weight


always @(posedge clk or posedge reset) begin
out_valid <= 0; //reset out_valid after one cycle

if(reset) begin
    out_valid <= 0;
    y_out <= 0;
    accumulator <= 0;
    counter <= 0;
    end

else if(in_valid && !busy) begin  //start multiplication and accumulation process
    for (i=HIST-1;i>0;i=i-1) begin //shift register 
        shift_reg[i] <= shift_reg[i-1];
    end 
    shift_reg[0] <= x_in;
   

    accumulator <= product; //add product
    counter <= 1; 
    end

else if(busy && counter < 8) begin  //continue multiplication and accumulation process
    accumulator <= accumulator+ product; //add weighted sum
    counter <= counter + 1;
    end
else if (busy && counter == 8) begin
    //finish multiplication and accumulation process
    out_valid <= 1;
    y_out <= accumulator;
    counter <= 0;
    end
  
end
endmodule 


//original serial code for FIR contains 2 multipliers, one for the starting of the multiplication and one for remaining of the history samples.
//to minimize the area that the synthesizer will use, we can use a single multiplier and use the input sample for the first multiplication and then use the shift register for the remaining multiplications.
//however, this will increase the latency of the FIR filter by 1 cycle. The original code has a latency of 8 cycles, while the modified code has a latency of 9 cycles.
//but serial design is the area-optimized version by definition
//we want only one multiplier in this design so that the pipelined version, which will use 8, can show that is has much lower latency per output and much larger area.
// If the serial version trades a little latency for less area, that makes the contrast clearer, not weaker.
//also, if we remove this second multiplier, we will also need a mux to select which input to use for the multiplication, the new sample or the shift register sample. This will also increase the area of the design.




//EARLY CHANGES AND THEORY BEHIND THEM
// ---------------------------------------------------------------
// Why the start branch uses x_in instead of shift_reg[0]
// ---------------------------------------------------------------
// The shift still happens with shift_reg[0] <= x_in; (kept in both
// versions). Only the multiply on the start edge changed.
//
// BEFORE:
//   shift_reg[0] <= x_in;                              // store new sample (kept)
//   accumulator <= accumulator + shift_reg[0]*WEIGHT;  // start branch
//
// AFTER:
//   shift_reg[0] <= x_in;           // store new sample (kept)
//   accumulator <= x_in * WEIGHT;   // start branch
//
// Reason: shift_reg[0] <= x_in uses a non-blocking assignment (<=).
// The new value doesn't appear in shift_reg[0] until the NEXT clock
// edge. On the edge where the sample arrives, shift_reg[0] still holds
// the previous sample. The BEFORE version multiplied the wrong sample,
// one cycle late.
//
// So on the start edge, the first product uses x_in, the sample
// arriving now. On later edges the sample is already stored, so the
// multiplier can read shift_reg[1] through shift_reg[7] safely.
//
// Rule to remember: a value written with <= is available on the
// next clock edge, not the current one.
// ---------------------------------------------------------------