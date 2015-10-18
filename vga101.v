module vga101(
	input CLK_100MHz,
	input SwitchLeft,
	input SwitchRight,
	output wire HSync,
	output wire VSync,
	output wire [2:0] Red,
	output wire [2:0] Green,
	output wire [1:0] Blue
);

	parameter finalclk = 25000000;

	// snake stuff
	parameter borderWidth = 10; // border size, in pixels
	parameter snakeWidth = 15;
	parameter snakeInitialSize = 3;
	parameter snakeSpeed = 8; // move by seconds
	parameter maxTail = 100;

	// vga stuff
	parameter xmax = 640; // resolution
	parameter ymax = 480;
	
	parameter xfp = 16; // horizontal front porch
	parameter xsync = 48; // horizontal sync
	parameter xbp = 96; // horizontal back porch
	
	parameter yfp = 10; // vertical stuffs
	parameter ysync = 2;
	parameter ybp = 33;
	
	// vga ending offsets
	localparam oxfp = xmax + xfp;
	localparam oxsync = oxfp + xsync;
	localparam oxbp = oxsync + xbp;
	localparam oyfp = ymax + yfp;
	localparam oysync = oyfp + ysync;
	localparam oybp = oysync + ybp;
	
	localparam maxAdvanceCounter = finalclk / snakeSpeed; // when then clock reachs that many ticks, the snake moves forward
	
	wire CLK_25MHz;

	DCM_CLKGEN #(
		.CLKFXDV_DIVIDE(8),       // CLKFXDV divide value (2, 4, 8, 16, 32)
      .CLKFX_DIVIDE(8),         // Divide value - D - (1-256)
      .CLKFX_MD_MAX(0.0),       // Specify maximum M/D ratio for timing anlysis
      .CLKFX_MULTIPLY(2),       // Multiply value - M - (2-256)
      .CLKIN_PERIOD(10.0),       // Input clock period specified in nS
      .SPREAD_SPECTRUM("NONE"), // Spread Spectrum mode "NONE", "CENTER_LOW_SPREAD", "CENTER_HIGH_SPREAD",
                                // "VIDEO_LINK_M0", "VIDEO_LINK_M1" or "VIDEO_LINK_M2" 
      .STARTUP_WAIT("FALSE")    // Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
   )
	DCM_CLKGEN_inst (
      .CLKFX(CLK_25MHz),         // 1-bit output: Generated clock output
      .CLKFX180(),   // 1-bit output: Generated clock output 180 degree out of phase from CLKFX.
      .CLKFXDV(),     // 1-bit output: Divided clock output
      .LOCKED(),       // 1-bit output: Locked output
      .PROGDONE(),   // 1-bit output: Active high output to indicate the successful re-programming
      .STATUS(),       // 2-bit output: DCM_CLKGEN status
      .CLKIN(CLK_100MHz),         // 1-bit input: Input clock
      .FREEZEDCM(1'b0), // 1-bit input: Prevents frequency adjustments to input clock
      .PROGCLK(1'b0),     // 1-bit input: Clock input for M/D reconfiguration
      .PROGDATA(1'b0),   // 1-bit input: Serial data input for M/D reconfiguration
      .PROGEN(1'b0),       // 1-bit input: Active high program enable
      .RST(1'b0)              // 1-bit input: Reset input pin
   );

	reg [32:0] advanceCounter; // at 0, the snake moves

	reg [9:0] counterX;
	reg [9:0] counterY;

	reg [2:0] R;
	reg [2:0] G;
	reg [1:0] B;
	
	assign HSync = (counterX < oxfp || counterX >= oxsync);
	assign VSync = (counterY < oyfp || counterY >= oysync);
	
	assign Red = R;
	assign Green = G;
	assign Blue = B;
	
	// snake
	reg [9:0] X;
	reg [8:0] Y;
	reg [1:0] direction; // right, bottom, left, top
	reg [9:0] tailSize;
	reg [9:0] tailX [maxTail-1:0];
	reg [9:0] tailY [maxTail-1:0];
	
	reg oldSwitchLeft; // of the tick before
	reg oldSwitchRight;
	
	// cherry
	reg [9:0] cherryX;
	reg [8:0] cherryY;
	reg cherryFound;
	reg cherryEaten;
	wire cherryDisplayed;
	assign cherryDisplayed = (cherryEaten == 0) && (cherryFound == 1);
	
	// random seeds
	reg [9:0] LSFR_X;
	reg [8:0] LSFR_Y;
	wire [9:0] discreteLSFRX;
	wire [8:0] discreteLSFRY;
	assign discreteLSFRX = snakeWidth*LSFR_X;
	assign discreteLSFRY = snakeWidth*LSFR_Y;
	
	integer i;
	initial begin
		advanceCounter = 1;
		
		counterX = 0;
		counterY = 0;
		
		oldSwitchLeft = 1;
		oldSwitchRight = 1;
		
		cherryX = 0;
		cherryY = 0;
		cherryFound = 0;
		cherryEaten = 0;
		
		LSFR_X = 10'd687;
		LSFR_Y = 9'd53;
		
		X = snakeWidth*(xmax/(2*snakeWidth));
		Y = snakeWidth*(ymax/(2*snakeWidth));
		direction = 0;

		tailSize = snakeInitialSize;
		tailX[0] = X;
		tailY[0] = Y;
		for(i=1 ; i<maxTail ; i=i+1) begin
			tailX[i] = 10'b0000000000;
			tailY[i] = 10'b0000000000;
		end
	end
	
	// handle sync
	always @(posedge CLK_25MHz) begin
		if(counterX >= oxbp-1) begin
			counterX <= 0;
			if(counterY >= oybp-1)
				counterY <= 0;
			else
				counterY <= counterY + 1;
		end else begin
			counterX <= counterX + 1;
		end
	end
	
	// random seeds & cherry handle
	always @(posedge CLK_25MHz) begin
		LSFR_X = {LSFR_X[8:0], LSFR_X[9] ^ LSFR_X[6]};
		LSFR_Y = {LSFR_Y[7:0], LSFR_Y[8] ^ LSFR_Y[4]};
		
		if( !cherryDisplayed ) begin // generate cherry positions
			if( discreteLSFRX >= borderWidth && discreteLSFRX < xmax - borderWidth
					&& discreteLSFRY >= borderWidth && discreteLSFRY < ymax - borderWidth ) begin // if in bounds, the cherry is generated
				cherryX = discreteLSFRX;
				cherryY = discreteLSFRY;
				cherryFound = 1;
			end else begin
				cherryFound = 0;
			end
		end
	end
	
	// snake moves
	always @(posedge CLK_25MHz) begin
		if(advanceCounter >= maxAdvanceCounter-1) begin
			advanceCounter <= 0;
			
			case(direction)
				0: X = X + snakeWidth;
				1: Y = Y + snakeWidth;
				2: X = X - snakeWidth;
				3: Y = Y - snakeWidth;
				default: $display("error");
			endcase
			
			for(i=maxTail-1 ; i>=1 ; i=i-1)
				if(i<tailSize) begin
					tailX[i] = tailX[i-1];
					tailY[i] = tailY[i-1];
				end
			
			tailX[0] = X;
			tailY[0] = Y;
			
			// if on cherry, generate a new one & grow
			if( cherryDisplayed ) begin
				if( X >= cherryX && X < cherryX + snakeWidth
					&& Y >= cherryY && Y < cherryY + snakeWidth ) begin
				
					tailSize = tailSize + 1;
					cherryEaten = 1;
				end else begin
					cherryEaten = 0;
				end
			end else begin
				if( cherryFound == 1 ) begin
					cherryEaten = 0;
				end
			end
			
			
		end else begin
			advanceCounter <= advanceCounter + 1;
		end
	end
	
	// changes direction pressing switches
	always @(posedge CLK_25MHz) begin
		if( oldSwitchLeft != SwitchLeft ) begin
			oldSwitchLeft = SwitchLeft;
			if( SwitchLeft == 1'b0 )
				direction = direction - 1;
				
		end else if ( oldSwitchRight != SwitchRight ) begin
			oldSwitchRight = SwitchRight;
			if( SwitchRight == 1'b0 )
				direction = direction + 1;
		end
	end
	
	// drawing stuff
	always @(*) begin

		// out of range
		if( counterX >= xmax || counterY >= ymax ) begin
			R = 3'b000;
			G = 3'b000;
			B = 2'b00;
		
		// border
		end else if( counterX < borderWidth || counterX >= xmax - borderWidth
				|| counterY < borderWidth || counterY >= ymax - borderWidth ) begin
			R = 3'b111;
			G = 3'b111;
			B = 2'b11;
		
		// chery
		end else if( cherryDisplayed
				&& counterX >= cherryX && counterX < cherryX + snakeWidth
				&& counterY >= cherryY && counterY < cherryY + snakeWidth ) begin
			R = 3'b000;
			G = 3'b000;
			B = 2'b11;
			
		end else begin
			// else & !tail
			R = 3'b000;
			G = 3'b000;
			B = 2'b00;
			
			// tail
			for(i=0 ; i<maxTail ; i=i+1)
				if(i<tailSize)
					if( counterX >= tailX[i] && counterX < tailX[i] + snakeWidth
							&& counterY >= tailY[i] && counterY < tailY[i] + snakeWidth ) begin
						R = 3'b111;
						G = 3'b000;
						B = 2'b00;
					end
		end
		
	end

endmodule
