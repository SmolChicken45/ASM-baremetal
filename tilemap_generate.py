from PIL import Image

def extraire_tiles(chemin_entree, chemin_tileset, chemin_map_bin, taille_bloc=20):
    img = Image.open(chemin_entree).convert('RGBA')
    largeur, hauteur = img.size
    
    blocs_uniques = []
    signatures_blocs = {}
    
    donnees_map = bytearray()
    
    for y in range(0, hauteur, taille_bloc):
        if y + taille_bloc > hauteur: break
        
        for x in range(0, largeur, taille_bloc):
            if x + taille_bloc > largeur: break
            
            box = (x,y, x + taille_bloc, y + taille_bloc)
            bloc = img.crop(box)
            
            signature = bloc.tobytes()
            
            if signature not in signatures_blocs:
                nouvel_id = len(blocs_uniques)
                
                if nouvel_id > 255:
                    raise ValueError("Plus de 256 blocs uniques détectés. Un octet par tile n'est plus suffisant.")
                
                signatures_blocs[signature] = nouvel_id
                blocs_uniques.append(bloc)
                
            donnees_map.append(signatures_blocs[signature])
            
    hauteur_tileset = len(blocs_uniques) * taille_bloc
    img_tileset = Image.new('RGBA', (taille_bloc, hauteur_tileset))
    
    for i, bloc in enumerate(blocs_uniques):
        img_tileset.paste(bloc, (0, i * taille_bloc))
        
    img_tileset.save(chemin_tileset)
    print(f"[{len(blocs_uniques)} blocs uniques] Tileset sauvegardé : {chemin_tileset} ")
    
    with open(chemin_map_bin, 'wb') as f:
        f.write(donnees_map)
        
    print(f"Map binaire générée : {chemin_map_bin} ({len(donnees_map)} octets)")
    
if __name__ == "__main__":
    image_source = "assets/images/aseprite/kris_bedroom.png"
    fichier_tileset = "assets/images/sprite_sheet/kris_bedroom.png"
    fichier_map_bin = "assets/images/sprite_sheet/kris_bedroom.bin"
    
    extraire_tiles(image_source, fichier_tileset, fichier_map_bin)