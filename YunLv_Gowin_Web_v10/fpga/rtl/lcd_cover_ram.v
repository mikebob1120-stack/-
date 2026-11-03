// Native 480x272 indices in 128K x 4 RAM: shared read/write port A, LCD read port B.
// Used: 130560 pixels x 4 bits = 522240 bits (65280 bytes).
// Palette is stable before cover_ready; only the boot loader writes it.
module lcd_cover_ram (
    input wire write_clk, write_enable,
    input wire [16:0] phone_address,
    output reg [3:0] phone_index=0,
    input wire [3:0] phone_palette_address,
    output wire [15:0] phone_palette_color,
    input wire [16:0] write_address,
    input wire [3:0] write_pixel,
    input wire palette_write_enable,
    input wire [3:0] palette_write_address,
    input wire [15:0] palette_write_pixel,
    input wire read_clk,
    input wire [16:0] read_address,
    output wire [15:0] read_pixel
);
    reg [3:0] pixels [0:131071];
    reg [15:0] palette [0:15];
    reg [3:0] read_index;
    // No array resets and no asynchronous framebuffer read: infer BSRAM.
    wire [16:0] port_a_address=write_enable ? write_address : phone_address;
    assign phone_palette_color=palette[phone_palette_address];
    // NORMAL / no-change write mode (WRITE_MODE0=2'b00): the A-port
    // output holds while loading a pixel. Reading the old value on a write
    // edge would infer READ-BEFORE-WRITE (2'b10), rejected by this device.
    // The phone requests cover data only after cover_ready, when writes stop.
    always @(posedge write_clk) begin
        if (write_enable)
            pixels[port_a_address] <= write_pixel;
        else
            phone_index <= pixels[port_a_address];
        if (palette_write_enable)
            palette[palette_write_address] <= palette_write_pixel;
    end
    always @(posedge read_clk) read_index <= pixels[read_address];
    assign read_pixel=palette[read_index];
endmodule
