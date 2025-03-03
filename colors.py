# Generate the color list from #000000 to #FFFFFF in the desired format
colors = [f'"{i}": #{i:06X}' for i in range(0x000000, 0xFFFFFF + 1)]

# Save to a text file
file_path_full = "./testing.txt"
with open(file_path_full, "w") as file:
    file.write("\n".join(colors))

file_path_full
