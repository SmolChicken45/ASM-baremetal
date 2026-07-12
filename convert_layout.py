import os

def convert_csv_to_inc(csv_filename, inc_filename, label_name):
    
    if not os.path.exists(csv_filename):
        print(f"Erreur: Le fichier {csv_filename} est introuvable.")
        return
    
    with open(inc_filename, 'w', encoding='utf-8') as out:
        
        out.write(f"; --- Fichier généré automatiquement par script Python ---\n")
        out.write(f"; Source : {csv_filename}\n\n")
        
        out.write("section .rodata\n")
        out.write(f"global {label_name}\n")
        
        out.write(f"{label_name}:\n")
        out.write("    ; Structure : dw ID_Objet, Pos_X, Pos_Y\n\n")
        
        count = 0
        
        with open(csv_filename, 'r', encoding='utf-8') as f:
            for line in f:
                
                line = line.strip()
                if not line:
                    continue
                    
                parts = [p.strip() for p in line.split(',')]
                
                if len(parts) >= 3:
                    id = parts[0]
                    x = parts[1]
                    y = parts[2]
                    
                    out.write(f"    dw {id}, {x}, {y}\n")
                    count += 1
                    
        out.write("\n    ; Marqueur de fin de liste\n")
        out.write(f"    dw 0xFFFF, 0, 0\n")
    
    print(f"Succès ! Fichier {inc_filename} généré avec {count} objets statiques.")
    
    
if __name__ == "__main__":
    INPUT_CSV = "assets/images/layout/kris_bedroom_layout.csv"
    OUTPUT_INC = "include/assets/layouts/kris_bedroom_layout.inc"
    LABEL_NAME = "kris_bedroom_layout"
    
    convert_csv_to_inc(INPUT_CSV, OUTPUT_INC, LABEL_NAME)