## Partner A (Ishita Suresh) — Milestone #1: Image Load and VGA Display

### Overview
This milestone involves converting an image into read-only memory (via a `.mif` file) for Quartus, loading it onto the FPGA board, and displaying it on a VGA monitor.
* A Python script generates the `.mif` file, which Quartus compiles into on-chip FPGA memory.
* Counters track the `x` and `y` pixel coordinates across the `160×120` frame.
* A Finite State Machine (FSM) increments the coordinates, waits for the ROM read delay, plots each pixel to the VGA adapter, and repeats.

### End-to-End Process
1. **Memory Initialization (`.mif`):** An offline Python script converts the source image into a `.mif` file containing the memory depth/width and the 24-bit colour value of each pixel (`8-bit Red`, `8-bit Green`, `8-bit Blue`).
2. **ROM Compilation:** Quartus loads the `.mif` file into a 24-bit-wide on-chip ROM during compile time.
3. **Reset:** Pressing the reset button sets the FSM counters `x` and `y` to `(0, 0)` as the starting position.
4. **Address & Read Delay:** The FSM sends the current `(x, y)` address to the ROM; after one clock cycle, the ROM outputs the corresponding 24-bit colour data.
5. **VGA Plotting:** The FSM asserts the plot signal to draw the 24-bit colour at the `(x, y)` coordinate.
6. **Coordinate Increment:** The FSM advances to the next column (`x + 1`), or at the end of a row, resets `x` to `0` and increments `y` to the next row down.

### Python Script
* Uses the **Pillow (`PIL`)** image processing library to resize the input image to `160×120` pixels and extract the 24-bit RGB data for each pixel.

### Verilog Modules
* **`load_display` (Top-Level Module):**
  * Instantiates `image_rom` to read pixel data from the `.mif` file and `pixel_reader` to run the coordinate FSM.
  * Routes the resulting `(x, y)` coordinates, 24-bit RGB colour, and `plot` signal into `vga_adapter` for display.
* **`image_rom` (Memory Module):**
  * Acts as a synchronous registered ROM (D-flip-flop behavior): on each clock tick, it takes the 15-bit pixel address (`D`) and outputs its 24-bit RGB value (`Q`).
* **`pixel_reader` (Control FSM):**
  * Manages coordinate incrementation and reset logic (`x = 0, y = 0` on active reset) in a dedicated sequential block, driven by a 5-state FSM:
    * **`S_ADDR`:** Requests colour data from `image_rom` for the current `(x, y)` coordinate.
    * **`S_WAIT`:** Waits one clock tick for `image_rom` to output the valid 24-bit pixel data.
    * **`S_PLOT`:** Asserts `plot = 1` to signal `vga_adapter` to draw the pixel.
    * **`S_NEXT`:** Advances the `x` and `y` counters to the next pixel position.
    * **`S_DONE`:** Triggered once `x` and `y` reach the final pixel of the frame, resetting the position back to `(0, 0)` upon completion.
