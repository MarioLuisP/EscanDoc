import os
for clase in sorted(os.listdir("G:/entrenamiento")):
    path = f"G:/entrenamiento/{clase}"
    if os.path.isdir(path):
        imgs = [f for f in os.listdir(path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
        print(f"{clase}: {len(imgs)} imágenes")