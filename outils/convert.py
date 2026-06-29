import sys
from PIL import Image

def convert_to_bgra_raw(input_path, output_path):
    try:
        # 1. Ouvrir l'image et forcer la lecture en 4 canaux (RGBA)
        img = Image.open(input_path).convert('RGBA')
        
        # 2. Séparer chaque canal de couleur en calques indépendants
        r, g, b, a = img.split()
        
        # 3. Recombiner les calques dans l'ordre inverse (BGRA)
        # On utilise "RGBA" comme mode cible pour indiquer qu'on garde 4 canaux, 
        # mais on insère les calques dans le nouvel ordre.
        img_bgra = Image.merge("RGBA", (b, g, r, a))
        
        # 4. Extraire le tableau d'octets purs (sans aucun en-tête)
        raw_bytes = img_bgra.tobytes()
        
        # 5. Écrire ces octets dans le fichier de destination
        with open(output_path, 'wb') as f:
            f.write(raw_bytes)
            
        print(f"[SUCCÈS] Image convertie en BGRA RAW : {output_path}")

    except Exception as e:
        print(f"[ERREUR] Échec de la conversion de {input_path} : {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Vérifier que le script reçoit bien les bons arguments
    if len(sys.argv) != 3:
        print("Utilisation : python convert.py <image_entree.png> <fichier_sortie.raw>")
        sys.exit(1)
        
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    convert_to_bgra_raw(input_file, output_file)