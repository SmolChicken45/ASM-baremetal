import math

amplitude = 1024
entries = 256
output_file = "include\common\sin_table.inc"

with open(output_file, "w") as f:
    f.write("sin_table:\n")
        
    for i in range(entries):
        angle = (i / entries) * 2 * math.pi
        
        sin_val = int(round(math.sin(angle) * amplitude))
        
        f.write(f"\tdd {sin_val}\n")
        
print(f"La table a été généré avec succès dans '{output_file}'")