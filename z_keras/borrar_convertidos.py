import os

# Leer lista de TIFs convertidos
with open('convertidos.txt', 'r', encoding='utf-8') as f:
    lineas = f.readlines()

folder = "G:/entrenamiento"
borrados = 0

for linea in lineas:
    if 'Convertido:' in linea:
        # Extrae el nombre del archivo TIF
        tif_name = linea.split('Convertido:')[1].strip()
        # Cambia .tif por .jpg
        jpg_name = tif_name.replace('.tif', '.jpg').replace('.tiff', '.jpg')
        
        # Busca el JPG en todas las subcarpetas
        for root, dirs, files in os.walk(folder):
            if jpg_name in files:
                jpg_path = os.path.join(root, jpg_name)
                os.remove(jpg_path)
                print(f"Borrado: {jpg_name}")
                borrados += 1
                break

print(f"\nTotal borrados: {borrados}")