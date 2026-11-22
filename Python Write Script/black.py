with open("black.mif", "w") as f:
    f.write("WIDTH=24;\n")
    f.write("DEPTH=19200;\n")
    f.write("ADDRESS_RADIX=UNS;\n")
    f.write("DATA_RADIX=HEX;\n")
    f.write("CONTENT BEGIN\n")
    f.write("[0..19199] : 000000;\n")
    f.write("END;\n")

print("done black")