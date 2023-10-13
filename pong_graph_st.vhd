library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
entity pong_graph_st is
	port(
		clk, reset: std_logic;
		btn: std_logic_vector(1 downto 0);		
--		video_on: in std_logic;
		pixel_x,pixel_y: in std_logic_vector(9 downto 0);
		gra_still: in std_logic;
		hit, miss: out std_logic;
		graph_rgb: out std_logic_vector(2 downto 0);
--		graph_on: out std_logic_vector(2 downto 0)
		graph_on: out std_logic
		);	
end pong_graph_st;

architecture arch of pong_graph_st is
	signal refr_tick: std_logic;
	-- x, y coordinates (0,0) to (639,479);
	signal pix_x, pix_y: unsigned (9 downto 0);
	constant MAX_X: integer := 640;
	constant MAX_Y: integer := 480;	
	---------------------------------------------
	--vertical stripe as wall 
	---------------------------------------------
	--wall left, right boundary 
	constant WALL_X_L: integer:=32;
	constant WALL_X_R: integer:=35;
	--------------------------------------------------------------------
	--right paddle bar
	-----------------------------------------------------------
	--bar left, right boundary
	constant BAR_X_L: integer:= 600;
	constant BAR_X_R: integer:= 603;
	-- bar top, bottom boundary
	signal bar_y_t, bar_y_b: unsigned(9 downto 0);
	constant BAR_Y_SIZE: integer:= 72;
	--reg to track top boundary (x position is fixed)
	signal bar_y_reg, bar_y_next: unsigned(9 downto 0);
	-- bar moving velocity when a button is pressed 
	constant BAR_V: integer := 4;
	--------------------------------------------------------------
	--SQUARE BALL
	-----------------------------------------------
	constant BALL_SIZE: integer:=8;
	-- ball left, right boundary
	signal ball_x_l, ball_x_r: unsigned(9 downto 0);
	-- ball top, bottom boundary
	signal ball_y_t, ball_y_b: unsigned(9 downto 0);
	-- reg to track left, top boundary 
	signal ball_x_reg, ball_x_next: unsigned(9 downto 0);
	signal ball_y_reg, ball_y_next: unsigned(9 downto 0);
	--reg to track ball speed
	signal ball_vx_reg, ball_vx_next: unsigned(9 downto 0);
	signal ball_vy_reg, ball_vy_next: unsigned(9 downto 0);
	-- ball velotcity can be pos and neg
	constant BALL_V_P: unsigned(9 downto 0)
				:=to_unsigned(2,10);
	constant BALL_V_N: unsigned(9 downto 0)
				:=unsigned(to_signed(-2,10));
	-----------------------------------------------------------------------------------
	--round ball image ROM
	---------------------------------------------------------------------
	type rom_type is array (0 to 7) of std_logic_vector(0 to 7);
	--ROM definition
	constant BALL_ROM: rom_type :=
	(
		"00111100", --   ****
		"01111110", --  ******
		"11111111", -- ********
		"11111111", -- ********
		"11111111", -- ********
		"11111111", -- ********
		"01111110", --  ******
		"00111100" --    ****
	);
	signal rom_addr, rom_col: unsigned(2 downto 0);
	signal rom_data: std_logic_vector(7 downto 0);
	signal rom_bit: std_logic;	
	--------------------------------------------------------
	--OBJECT OUTPUT SIGNALS
	--------------------------------------------------------
	signal wall_on, bar_on, sq_ball_on, rd_ball_on : std_logic;
	signal wall_rgb, bar_rgb, ball_rgb : std_logic_vector(2 downto 0);

begin
	-- registers
	process (clk,reset)
	begin
		if reset = '1' then 
			bar_y_reg <= (others=>'0');
			ball_x_reg <= (others=>'0');
			ball_y_reg <= (others=>'0');
			ball_vx_reg <= ("0000000100");
			ball_vy_reg <= ("0000000100");
		elsif (clk'event and clk ='1') then
			bar_y_reg <= bar_y_next;
			ball_x_reg <= ball_x_next;
			ball_y_reg <= ball_y_next;
			ball_vx_reg <= ball_vx_next;
			ball_vy_reg <= ball_vy_next;
		end if;
	end process;

	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	-- refr_tick:1-clock tick asserted at start of v-sync
	-- 		i.e., when the screen refreshed(60 Hz)
	refr_tick <= '1' when (pix_y=481) and (pix_x=0) else 
					 '0';
	-------------------------------------
	--(wall) left vertical stripe
	-----------------------------------
	-- pixel within wall 
	wall_on <=
		'1' when (WALL_X_L <= pix_x) and (pix_x <= WALL_X_R) else 
		'0';
	-- wall rgb output
	wall_rgb <= "001"; --blue
	----------------------------------------------------------------------------------------------
	--										right vertical bar
	----------------------------------------------------------------------------------------------------------
	--boundary 
	bar_y_t <= bar_y_reg;
	bar_y_b <= bar_y_t + BAR_Y_SIZE - 1;
	-- pixel within bar	
	bar_on <= 
		'1' when (BAR_X_L <= pix_x) and (pix_x <= BAR_X_R) and 
					(bar_y_t <= pix_y) and (pix_y <= bar_y_b) else 
		'0';
		--bar rgb output
	bar_rgb <= "010"; -- green
	-- new bar y-position
	process(bar_y_reg,bar_y_b,bar_y_t,refr_tick,btn)
	begin
		bar_y_next <= bar_y_reg; -- no move 
		if refr_tick = '1' then
			if btn(1) = '1' and bar_y_b < (MAX_Y-1-BAR_V) then
				bar_y_next <= bar_y_reg + BAR_V; -- move down
			elsif btn(0) = '1' and bar_y_t > BAR_V then
				bar_y_next <= bar_y_reg - BAR_V; -- move up
			end if;
		end if;
	end process;
		
	----------------------------------------------------------------------------
	-- 									square ball 
	-----------------------------------------------------------------------------------
	-- boundary 
	ball_x_l <= ball_x_reg;
	ball_y_t <= ball_y_reg;
	ball_x_r <= ball_x_l + BALL_SIZE -1;
	ball_y_b <= ball_y_t + BALL_SIZE -1;	
	-- pixel within  ball 
	sq_ball_on <= 
		'1' when (ball_x_l <= pix_x) and (pix_x <= ball_x_r) and
					(ball_y_t <= pix_y) and (pix_y <= ball_y_b) else 
		'0';
	-- map current pixel location to ROM addr/col
	rom_addr <= pix_y(2 downto 0) - ball_y_t(2 downto 0);
	rom_col <= pix_x(2 downto 0) - ball_x_l(2 downto 0);
	rom_data <= BALL_ROM(to_integer(rom_addr));
	rom_bit <= rom_data(to_integer(rom_col));
	
	-- pixel within ball
	rd_ball_on <=
		'1' when (sq_ball_on ='1') and (rom_bit = '1') else 
		'0';
	-- ball rgb output 	
	ball_rgb <= "100"; -- red 
	---------------------------------------------------------------------------
	-- new ball position
	------------------------------------------------------------------
	ball_x_next <= 
		to_unsigned((MAX_X)/2,10) when gra_still ='1' else 
		ball_x_reg + ball_vx_reg when refr_tick = '1' else 
		ball_x_reg;
	ball_y_next <= 
		to_unsigned((MAX_Y)/2,10) when gra_still ='1' else 
		ball_y_reg + ball_vy_reg when refr_tick = '1' else 
		ball_y_reg;
	-- new ball velocity 
	process (ball_vx_reg, ball_vy_reg, ball_y_t, ball_x_l, ball_x_r,
				ball_y_t, ball_y_b, bar_y_t, bar_y_b, gra_still)
	begin
		hit <= '0';
		miss <= '0';
		ball_vx_next <= ball_vx_reg;
		ball_vy_next <= ball_vy_reg;
		if gra_still ='1' then			-- intitial velocity 
			ball_vx_next <= BALL_V_N;
			ball_vy_next <= BALL_V_P;
		elsif ball_y_t < 1 then            -- reach top
			ball_vy_next <= BALL_V_P;
		elsif ball_y_b > (MAX_Y-1) then -- reach bottom
			ball_vy_next<= BALL_V_N;
		elsif ball_x_l <= (WALL_X_R) then -- reach wall
			ball_vx_next <= BALL_V_P;
		elsif (BAR_X_L <= ball_x_r) and (ball_x_r <= BAR_X_R) and
				(bar_y_t <= ball_y_b) and (ball_y_t <= bar_y_b) then
				--reach x of right bar, a hit
				ball_vx_next <= BALL_V_N; -- bounce back 
				hit <= '1';
		elsif (ball_x_r>MAX_X) then -- reach right border
			miss <= '1';		
		
		end if;
	end process;
	
	-------------------------------------------------------------------------------------------------
	-- 										rgb multiplexing circuit 
	-------------------------------------------------------------------------------------------------------------
	process (wall_on, bar_on, rd_ball_on, 
				wall_rgb, bar_rgb, ball_rgb)
	begin 
	
		graph_rgb <= "000"; -- blank 
	
		if wall_on='1' then 
			graph_rgb <= wall_rgb;
		elsif bar_on = '1' then 
			graph_rgb <= bar_rgb;
		elsif rd_ball_on = '1' then
			graph_rgb <= ball_rgb;
		else 
			graph_rgb <= "110"; -- yellow background 
		end if;
		
	end process;
--	graph_on <= wall_on & bar_on & rd_ball_on;
	graph_on <= wall_on or bar_on or rd_ball_on;
end arch;
	
	
	
	
	
	
	
	
	
	
	
	





