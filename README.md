# FPGA Image Filter
**Authors:** Sylvia Wang & Ishita Suresh


A hardware-accelerated image convolution implemented in Verilog on the DE1-SoC FPGA board. The system stores multiple 160×120 images in on-chip ROM and processes them sequentially through a fixed-point 3×3 kernel datapath—supporting signed multiply-accumulate, arithmetic bit-shift scaling, clamping, and edge-replicated border handling—before rendering the filtered output live to a VGA monitor. Users can toggle between stored images and preset filters (Original, Gaussian Blur, and Sobel Edge Detection) via onboard switches, or enter custom 3×3 kernel weights and shift values interactively using a PS/2 keyboard with real-time feedback displayed on the 7-segment HEX displays.
