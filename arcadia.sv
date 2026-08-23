//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,
 
`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[7:6];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"Arcadia;;",
	"-;",
	"F,BIN,Load Cartridge;",
	//"O5,Video standard,PAL,NTSC;",
	"O3,Auto-Center,On,Off;",
	"O4,Swap Joystick XY,Off,On;",
	"O5,D-Pad Analog Emulation,Off,On;",
	"O8,Swap Controllers,Off,On;",
	"O9,Pause Core on OSD,Off,On;",
	"O67,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"J,Start,Select(A),Option(B),Enter,Clear,0,1,2,3,4,5,6,7,8,9,Action,Action2;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [63:0] status;
wire [10:0] ps2_key;
reg   [9:0] kb1_keys, kb2_keys;
reg kb1_enter, kb1_clear, kb2_enter, kb2_clear;

wire        ioctl_download;
wire [15:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wait;
wire [31:0] joystick_0,joystick_1;
wire [15:0] joystick_analog_0,joystick_analog_1;

wire        info_req = 0;
wire  [7:0] info = 0;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clksys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),

	.info_req(info_req),
	.info(info),
	
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_r_analog_0(joystick_analog_0),
	.joystick_r_analog_1(joystick_analog_1),

	.ps2_key(ps2_key)
);

reg old_toggle = 0;

always @(posedge clksys) begin
    old_toggle <= ps2_key[10];

    if (old_toggle != ps2_key[10]) begin
        if (ps2_key[9]) begin  // Press
            case (ps2_key[7:0])
                'h16: kb1_keys[1] <= 1'b1;
                'h1E: kb1_keys[2] <= 1'b1;
                'h26: kb1_keys[3] <= 1'b1;
                'h15: kb1_keys[4] <= 1'b1;
                'h1D: kb1_keys[5] <= 1'b1;
                'h24: kb1_keys[6] <= 1'b1;
                'h1C: kb1_keys[7] <= 1'b1;
                'h1B: kb1_keys[8] <= 1'b1;
                'h23: kb1_keys[9] <= 1'b1;
                'h1A: kb1_clear   <= 1'b1;
                'h22: kb1_keys[0] <= 1'b1;
                'h21: kb1_enter   <= 1'b1;
                'h3E: kb2_keys[1] <= 1'b1;
                'h46: kb2_keys[2] <= 1'b1;
                'h45: kb2_keys[3] <= 1'b1;
                'h43: kb2_keys[4] <= 1'b1;
                'h44: kb2_keys[5] <= 1'b1;
                'h4D: kb2_keys[6] <= 1'b1;
                'h42: kb2_keys[7] <= 1'b1;
                'h4B: kb2_keys[8] <= 1'b1;
                'h4C: kb2_keys[9] <= 1'b1;
                'h41: kb2_clear   <= 1'b1;
                'h49: kb2_keys[0] <= 1'b1;
                'h4A: kb2_enter   <= 1'b1;
            endcase
        end else begin  // Release
            case (ps2_key[7:0])
                'h16: kb1_keys[1] <= 1'b0;
                'h1E: kb1_keys[2] <= 1'b0;
                'h26: kb1_keys[3] <= 1'b0;
                'h15: kb1_keys[4] <= 1'b0;
                'h1D: kb1_keys[5] <= 1'b0;
                'h24: kb1_keys[6] <= 1'b0;
                'h1C: kb1_keys[7] <= 1'b0;
                'h1B: kb1_keys[8] <= 1'b0;
                'h23: kb1_keys[9] <= 1'b0;
                'h1A: kb1_clear   <= 1'b0;
                'h22: kb1_keys[0] <= 1'b0;
                'h21: kb1_enter   <= 1'b0;
                'h3E: kb2_keys[1] <= 1'b0;
                'h46: kb2_keys[2] <= 1'b0;
                'h45: kb2_keys[3] <= 1'b0;
                'h43: kb2_keys[4] <= 1'b0;
                'h44: kb2_keys[5] <= 1'b0;
                'h4D: kb2_keys[6] <= 1'b0;
                'h42: kb2_keys[7] <= 1'b0;
                'h4B: kb2_keys[8] <= 1'b0;
                'h4C: kb2_keys[9] <= 1'b0;
                'h41: kb2_clear   <= 1'b0;
                'h49: kb2_keys[0] <= 1'b0;
                'h4A: kb2_enter   <= 1'b0;
            endcase
        end
    end
end

// OR keyboard keys into joystick keypad bits before feeding the core
wire [31:0] joy0_combined, joy1_combined;

// P1 combined
assign joy0_combined[3:0]   = joystick_0[3:0];                // d-pad
assign joy0_combined[6:4]   = joystick_0[6:4];                // Start, Select, Option
assign joy0_combined[7]     = joystick_0[7]  | kb1_enter;     // ENTER
assign joy0_combined[8]     = joystick_0[8]  | kb1_clear;     // CLEAR
assign joy0_combined[9]     = joystick_0[9]  | kb1_keys[0];   // 0
assign joy0_combined[10]    = joystick_0[10] | kb1_keys[1];   // 1
assign joy0_combined[11]    = joystick_0[11] | kb1_keys[2];   // 2
assign joy0_combined[12]    = joystick_0[12] | kb1_keys[3];   // 3
assign joy0_combined[13]    = joystick_0[13] | kb1_keys[4];   // 4
assign joy0_combined[14]    = joystick_0[14] | kb1_keys[5];   // 5
assign joy0_combined[15]    = joystick_0[15] | kb1_keys[6];   // 6
assign joy0_combined[16]    = joystick_0[16] | kb1_keys[7];   // 7
assign joy0_combined[17]    = joystick_0[17] | kb1_keys[8];   // 8
assign joy0_combined[18]    = joystick_0[18] | kb1_keys[9];   // 9
assign joy0_combined[19]    = joystick_0[19] | kb1_keys[2];   // 2 alt
assign joy0_combined[20]    = joystick_0[20] | kb1_keys[2];   // 2 alt

// P2 combined
assign joy1_combined[3:0]   = joystick_1[3:0];                // d-pad
assign joy1_combined[6:4]   = joystick_1[6:4];                // Start, Select, Option
assign joy1_combined[7]     = joystick_1[7]  | kb2_enter;     // ENTER
assign joy1_combined[8]     = joystick_1[8]  | kb2_clear;     // CLEAR
assign joy1_combined[9]     = joystick_1[9]  | kb2_keys[0];   // 0
assign joy1_combined[10]    = joystick_1[10] | kb2_keys[1];   // 1
assign joy1_combined[11]    = joystick_1[11] | kb2_keys[2];   // 2
assign joy1_combined[12]    = joystick_1[12] | kb2_keys[3];   // 3
assign joy1_combined[13]    = joystick_1[13] | kb2_keys[4];   // 4
assign joy1_combined[14]    = joystick_1[14] | kb2_keys[5];   // 5
assign joy1_combined[15]    = joystick_1[15] | kb2_keys[6];   // 6
assign joy1_combined[16]    = joystick_1[16] | kb2_keys[7];   // 7
assign joy1_combined[17]    = joystick_1[17] | kb2_keys[8];   // 8
assign joy1_combined[18]    = joystick_1[18] | kb2_keys[9];   // 9
assign joy1_combined[19]    = joystick_1[19] | kb2_keys[2];   // 2 alt
assign joy1_combined[20]    = joystick_1[20] | kb2_keys[2];   // 2 alt

assign joy0_combined[31:21] = joystick_0[31:21];
assign joy1_combined[31:21] = joystick_1[31:21];

// ====================================================================
// D-PAD ANALOG EMULATION
// ====================================================================
// When status[5] is enabled, D-pad presses generate emulated analog
// values that ramp up over time and decay when released, so an
// NTT Data controller (D-pad only) can drive analog-sensitive games.
// The emulated analog replaces joystick_analog_0/1 to the core.
// ====================================================================

// Ramp prescaler: ~131k clocks per step at ~35.5 MHz gives ~0.5s
// for a full 0-to-127 sweep (127 steps * 131k = ~16.6M clocks).
localparam RAMP_PRE = 17'd131071;

// Player 1 emulated analog state
reg  [16:0] p1_ramp_cnt;       // prescaler counter
reg   [7:0] p1_analog_x;       // signed: 0x00=center, 0x7F=max+, 0x80=max-
reg   [7:0] p1_analog_y;       // signed: 0x00=center, 0x7F=max+, 0x80=max-
reg   [3:0] p1_dpad_d;         // delayed D-pad for edge detection

// Player 2 emulated analog state
reg  [16:0] p2_ramp_cnt;
reg   [7:0] p2_analog_x;
reg   [7:0] p2_analog_y;
reg   [3:0] p2_dpad_d;

// Muxed analog outputs to the core
wire [15:0] analog_0_core, analog_1_core;

assign analog_0_core = status[5] ? {p1_analog_x, p1_analog_y} : joystick_analog_0;
assign analog_1_core = status[5] ? {p2_analog_x, p2_analog_y} : joystick_analog_1;

// D-pad direction bits from the COMBINED joystick (includes keyboard)
// joystick_0 bits: 0=Up, 1=Down, 2=Left, 3=Right
wire [3:0] p1_dpad = joy0_combined[3:0];
wire [3:0] p2_dpad = joy1_combined[3:0];

always @(posedge clksys) begin
    // ---- Player 1 ----
    p1_dpad_d <= p1_dpad;
    
    // Edge detect: jump prescaler for immediate response
    if (p1_dpad != 4'd0 && p1_dpad_d == 4'd0)
        p1_ramp_cnt <= RAMP_PRE;
    else if (p1_ramp_cnt == RAMP_PRE) begin
        p1_ramp_cnt <= 17'd0;
        
        // X axis (Left/Right)
        // Real analog stick: Right = negative, Left = positive
        if (p1_dpad[3] && !p1_dpad[2]) begin
            // Right pressed, Left not: ramp toward -128 (0x80)
            if (p1_analog_x[7] == 1'b1 && p1_analog_x != 8'h80)
                p1_analog_x <= p1_analog_x - 8'd1;
            else if (p1_analog_x[7] == 1'b0)
                p1_analog_x <= p1_analog_x - 8'd1;
        end else if (p1_dpad[2] && !p1_dpad[3]) begin
            // Left pressed, Right not: ramp toward +127 (0x7F)
            if (p1_analog_x[7] == 1'b0 && p1_analog_x != 8'h7F)
                p1_analog_x <= p1_analog_x + 8'd1;
            else if (p1_analog_x[7] == 1'b1)
                p1_analog_x <= p1_analog_x + 8'd1;
        end else begin
            // Neither or both: decay toward center (0x00) if auto-center enabled
            if (!status[3]) begin
                if (p1_analog_x[7] == 1'b0 && p1_analog_x != 8'h00)
                    p1_analog_x <= p1_analog_x - 8'd1;
                else if (p1_analog_x[7] == 1'b1 && p1_analog_x != 8'h00)
                    p1_analog_x <= p1_analog_x + 8'd1;
            end
        end
        
        // Y axis (Up/Down)
        // Real analog stick: Down = negative, Up = positive
        if (p1_dpad[1] && !p1_dpad[0]) begin
            // Down pressed, Up not: ramp toward -128 (0x80)
            if (p1_analog_y[7] == 1'b1 && p1_analog_y != 8'h80)
                p1_analog_y <= p1_analog_y - 8'd1;
            else if (p1_analog_y[7] == 1'b0)
                p1_analog_y <= p1_analog_y - 8'd1;
        end else if (p1_dpad[0] && !p1_dpad[1]) begin
            // Up pressed, Down not: ramp toward +127 (0x7F)
            if (p1_analog_y[7] == 1'b0 && p1_analog_y != 8'h7F)
                p1_analog_y <= p1_analog_y + 8'd1;
            else if (p1_analog_y[7] == 1'b1)
                p1_analog_y <= p1_analog_y + 8'd1;
        end else begin
            // Neither or both: decay toward center if auto-center enabled
            if (!status[3]) begin
                if (p1_analog_y[7] == 1'b0 && p1_analog_y != 8'h00)
                    p1_analog_y <= p1_analog_y - 8'd1;
                else if (p1_analog_y[7] == 1'b1 && p1_analog_y != 8'h00)
                    p1_analog_y <= p1_analog_y + 8'd1;
            end
        end
    end else begin
        p1_ramp_cnt <= p1_ramp_cnt + 17'd1;
    end
    
    // ---- Player 2 ----
    p2_dpad_d <= p2_dpad;
    
    // Edge detect for immediate response
    if (p2_dpad != 4'd0 && p2_dpad_d == 4'd0)
        p2_ramp_cnt <= RAMP_PRE;
    else if (p2_ramp_cnt == RAMP_PRE) begin
        p2_ramp_cnt <= 17'd0;
        
        // X axis: Right = negative, Left = positive
        if (p2_dpad[3] && !p2_dpad[2]) begin
            if (p2_analog_x[7] == 1'b1 && p2_analog_x != 8'h80)
                p2_analog_x <= p2_analog_x - 8'd1;
            else if (p2_analog_x[7] == 1'b0)
                p2_analog_x <= p2_analog_x - 8'd1;
        end else if (p2_dpad[2] && !p2_dpad[3]) begin
            if (p2_analog_x[7] == 1'b0 && p2_analog_x != 8'h7F)
                p2_analog_x <= p2_analog_x + 8'd1;
            else if (p2_analog_x[7] == 1'b1)
                p2_analog_x <= p2_analog_x + 8'd1;
        end else begin
            if (!status[3]) begin
                if (p2_analog_x[7] == 1'b0 && p2_analog_x != 8'h00)
                    p2_analog_x <= p2_analog_x - 8'd1;
                else if (p2_analog_x[7] == 1'b1 && p2_analog_x != 8'h00)
                    p2_analog_x <= p2_analog_x + 8'd1;
            end
        end
        
        // Y axis: Down = negative, Up = positive
        if (p2_dpad[1] && !p2_dpad[0]) begin
            if (p2_analog_y[7] == 1'b1 && p2_analog_y != 8'h80)
                p2_analog_y <= p2_analog_y - 8'd1;
            else if (p2_analog_y[7] == 1'b0)
                p2_analog_y <= p2_analog_y - 8'd1;
        end else if (p2_dpad[0] && !p2_dpad[1]) begin
            if (p2_analog_y[7] == 1'b0 && p2_analog_y != 8'h7F)
                p2_analog_y <= p2_analog_y + 8'd1;
            else if (p2_analog_y[7] == 1'b1)
                p2_analog_y <= p2_analog_y + 8'd1;
        end else begin
            if (!status[3]) begin
                if (p2_analog_y[7] == 1'b0 && p2_analog_y != 8'h00)
                    p2_analog_y <= p2_analog_y - 8'd1;
                else if (p2_analog_y[7] == 1'b1 && p2_analog_y != 8'h00)
                    p2_analog_y <= p2_analog_y + 8'd1;
            end
        end
    end else begin
        p2_ramp_cnt <= p2_ramp_cnt + 17'd1;
    end
    
    // Reset all analog state to center
    if (reset) begin
        p1_analog_x <= 8'h00;
        p1_analog_y <= 8'h00;
        p1_ramp_cnt <= 17'd0;
        p1_dpad_d   <= 4'd0;
        p2_analog_x <= 8'h00;
        p2_analog_y <= 8'h00;
        p2_ramp_cnt <= 17'd0;
        p2_dpad_d   <= 4'd0;
    end
end

/////////////////////// CLOCKS ///////////////////////////////

wire clksys,clksys_ntsc,clksys_pal,pll_locked;
assign clksys = clksys_pal;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clksys_ntsc),
	.outclk_1(clksys_pal),
	.locked(pll_locked)
);

  
/* CLK = Pix CLK * 8
   NTSC : 3.579545MHz   * 8
   PAL  : 4.43361875MHz * 8
*/
wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

wire [7:0] sound;

arcadia_core arcadia_core
(
	.clk(clksys),
	.reset(reset),
	.OSD_STATUS(OSD_STATUS),
	.pause_osd(status[9]),

	.ntsc_pal(1'b1),
	.swapxy(status[4]),
	.swap_controllers(status[8]),

	.clk_video(CLK_VIDEO),
	.ce_pixel(CE_PIXEL),
	.vga_r(VGA_R),
	.vga_g(VGA_G),
	.vga_b(VGA_B),
	.vga_hs(VGA_HS),
	.vga_vs(VGA_VS),
	.vga_de(VGA_DE),

	.sound(sound),

	.ps2_key(ps2_key),
	.joystick_0(joy0_combined),
	.joystick_1(joy1_combined),
	.joystick_analog_0(analog_0_core),
	.joystick_analog_1(analog_1_core),
	.dpad_analog_en(status[5]),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait)
    
);

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_L   = {sound,8'b0};
assign AUDIO_R   = {sound,8'b0};
assign AUDIO_S   = 1'b1;
assign AUDIO_MIX = 2'b11;

endmodule
