module vga_test;

	// Inputs
	reg CLK_100MHz;
	reg SwitchLeft;
	reg SwitchRight;

	// Outputs
	wire HSync;
	wire VSync;
	wire [2:0] Red;
	wire [2:0] Green;
	wire [1:0] Blue;
	
	wire clk;
	assign clk = CLK_100MHz;

	initial begin
		CLK_100MHz = 0;
		SwitchLeft = 1;
		SwitchRight = 1;
	end
	
	always begin
		#1 CLK_100MHz = !CLK_100MHz;
	end
	
	vga101 uut (
		.CLK_100MHz(clk),
		.SwitchLeft(SwitchLeft),
		.SwitchRight(SwitchRight),
		.HSync(HSync),
		.VSync(VSync),
		.Red(Red), 
		.Green(Green), 
		.Blue(Blue)
	);
      
endmodule

