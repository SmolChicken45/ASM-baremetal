import json
import os

def convert_json_to_inc(json_filename, inc_filename, label_name):
    
    if not os.path.exists(json_filename):
        print(f"Erreur: Le fichier {json_filename} est introuvable.")
        return
    
    with open(json_filename, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    with open(inc_filename, 'w', encoding='utf-8') as out:
        out.write(f"; --- Fichier généré automatiquement par script Python ---\n")
        out.write(f"; Source : {json_filename}\n\n")
        
        out.write(f"SPRITE_FRAME_SIZE equ 12 ; (6 valeurs * 2 octets)\n\n")
        
        out.write("; --- Constantes d'index --- \n")
        frames = data.get('frames', [])
        for i, frame_node in enumerate(frames):
            
            clean_name = frame_node['filename'].replace(' ', '_').replace('.', '').replace('-', '_').upper()
            out.write(f"{clean_name} equ {i}\n")
            
        out.write("\nsection .rodata\n")
        out.write(f"global {label_name}\n\n")
        
        out.write(f"{label_name}:\n")
        
        for i, frame_node in enumerate(frames):
            filename = frame_node['filename']
            f = frame_node['frame']
            s = frame_node['spriteSourceSize']
            
            out.write(f"    ; Index {i}: {filename}\n")
            out.write(f"    db {f['x']}, {f['y']}, {f['w']}, {f['h']}, {s['x']}, {s['y']}\n\n")
    
    print(f"Succès ! Fichier {inc_filename} généré avec {len(frames)} sprites.")
    
    
if __name__ == "__main__":
    
    INPUT_JSON = "assets/images/aseprite/kris_bedroom_atlas.json"
    OUTPUT_INC = "include/assets/atlases/kris_bedroom_atlas.inc"
    LABEL_NAME = "kris_bedroom_atlas"
    
    convert_json_to_inc(INPUT_JSON, OUTPUT_INC, LABEL_NAME)