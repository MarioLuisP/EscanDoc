from PIL import Image
import os

folder = "G:/entrenamiento"

for root, dirs, files in os.walk(folder):
    for file in files:
        if file.lower().endswith(('.tif', '.tiff')):
            path = os.path.join(root, file)
            try:
                img = Image.open(path)
                new_path = path.rsplit('.', 1)[0] + '.jpg'
                img.convert('RGB').save(new_path, 'JPEG')
                os.remove(path)
                print(f"Convertido: {file}")
            except Exception as e:
                print(f"Error en {file}: {e}")

print("¡Listo!")