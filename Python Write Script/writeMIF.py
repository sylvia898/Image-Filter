from PIL import Image

input_img = "test_image.jpg"
output_img = "ouput_test_image.mif"

img = Image.open(input_img) # load image
img = img.convert("RGB") # extract RGB values
img = img.resize((160, 120)) # resize to 4:3

with open(output_img, "w") as mif_file:
    # SUMMARY VALUES -----------------------------------------------------
    mif_file.write("WIDTH=24;\n") # each piece of data is 24 bits wide
    # 7 bits needed to store 120 columns, 8 bits to store 160 rows 
    # --> so 2^7 * 2^8 = 32,768
    mif_file.write("DEPTH=32768;\n")
    mif_file.write("ADDRESS_RADIX=BIN;\n") # address is written in binary
    mif_file.write("DATA_RADIX=BIN;\n") # data is written in binary
    mif_file.write("CONTENT BEGIN\n") 
    # --------------------------------------------------------------------

    for y in range(128): # 2^7 columns
        for x in range(256): # 2^8 rows
            adress = (y*256) + x # which line that pixel is stored at
            if x < 160 and y < 120:
                r, g, b = img.getpixel((x, y))
            else:
                r, g, b,  = 0, 0, 0

            mif_file.write(f"{adress:015b} : {r:08b}{g:08b}{b:08b};\n")

    mif_file.write("END\n")

    print("Writing complete.\n")
