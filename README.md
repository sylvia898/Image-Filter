## Partner A (Ishita Suresh) Milestone #1 - Image Load and VGA Display

### Overview
* This milestone involves sending an image as read-only memory (via a `.mif` file) to Quartus, loading it onto the FPGA board, and displaying it to the VGA display.
* A Python file writes the `.mif` file, which Quartus then loads onto the FPGA board. Counters are used for the x and y pixel coordinates. An FSM is used to increment the counters, wait for the ROM to deliver its pixel data, plot the pixel onto the VGA board, and repeat.

### Process
1. Using an offline python script, an image’s data is written into a `.mif` file. The data includes length and width, and the 24-bit colour value of each pixel (red: 8-bits, green: 8-bits, blue: 8-bits).
2. Quartus then loads the `.mif` file into a 24-bit-wide ROM on the FPGA board during compile time.
3. At the reset button, the FSM sets counters x and y to (0, 0), as the starting position.
4. The FSM sends the x-y address of each pixel to the ROM to deliver back the pixel colour. After one clock tick, the ROM delivers the 24-bit colour data.
5. The FSM then plots the pixel given the colour data to the x-y pixel position.
6. The FSM moves to the next column in each row, or at the end of each column, sets x back to 0 and moves y one row down.

### Python Script
* I am using the image processing library PILLOW (PIL) to both resize the image into a 160x120-pixel image and to get the colour data of each pixel.

### Verilog Script
* **Load_Display Module:**
  * Calls `image_rom` module to read from the `.mif` file, `pixel_rom` module to run through the FSM and increment pixel position, and puts all of that data to the `vga_adapter` function to plot the colour at each x-y pixel.
* **Image_ROM Module:**
  * This module is a D-flip-flop that, at every clock tick, the 15-bit address of each pixel is taken as D and its 24-bit RGB value is captured into Q.
* **Pixel_Reader Module:**
  * 5 states: `S_ADDR`, `S_WAIT`, `D_PLOT`, `S_NEXT`, and `S_DONE`
  * **`S_ADDR`:** state to ask for the colour data.
  * **`S_WAIT`:** state to wait for one clock tick for `image_rom` to read the data.
  * **`S_PLOT`:** sets plot to 1, queue for `VGA_DIsplay` to plot the pixel.
  * **`S_NEXT`:** increments both x- and y- coordinates of the pixel (next pixel).
    * I can increment coordinates in a separate always block, along with resetting x and y to zero if the reset button is pressed.
  * **`S_DONE`:** x- and y- coords hit the last possible number, all pixels drawn. The pixel position resets back to (0, 0) before the program terminates.
