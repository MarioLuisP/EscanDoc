import tensorflow as tf
import numpy as np
from sklearn.metrics import confusion_matrix, classification_report
import matplotlib.pyplot as plt

model = tf.keras.models.load_model("clasificador_documento4.keras")

IMG_SIZE = 224
BATCH_SIZE = 64

val_ds = tf.keras.utils.image_dataset_from_directory(
    "G:/entrenamiento",
    validation_split=0.2,
    subset="validation",
    seed=123,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode="int"
)

class_names = val_ds.class_names
loss, accuracy = model.evaluate(val_ds)
print(f"\n>>> ACCURACY: {accuracy * 100:.2f}%\n")

y_true = []
y_pred = []

for images, labels in val_ds:
    preds = model.predict(images, verbose=0)
    y_pred.extend(np.argmax(preds, axis=1))
    y_true.extend(labels.numpy())

y_true = np.array(y_true)
y_pred = np.array(y_pred)

cm = confusion_matrix(y_true, y_pred)
print("MATRIZ DE CONFUSIÓN:")
print(cm)
print("\n" + "="*60 + "\n")
print(classification_report(y_true, y_pred, target_names=class_names))

# Gráfico de barras: por cada clase real, cuántas predijo bien vs mal
fig, axes = plt.subplots(1, len(class_names), figsize=(4 * len(class_names), 5))
fig.suptitle(f'Accuracy: {accuracy*100:.1f}%', fontsize=14, fontweight='bold')

for i, clase in enumerate(class_names):
    total = cm[i].sum()
    correctas = cm[i][i]
    incorrectas = total - correctas

    axes[i].bar(['✅ Correctas', '❌ Errores'], 
                [correctas, incorrectas], 
                color=['#2ecc71', '#e74c3c'])
    
    axes[i].set_title(f'{clase}\n({correctas}/{total})', fontweight='bold')
    axes[i].set_ylim(0, total + 10)
    
    # Mostrar números arriba de cada barra
    axes[i].text(0, correctas + 1, str(correctas), ha='center', fontweight='bold')
    axes[i].text(1, incorrectas + 1, str(incorrectas), ha='center', fontweight='bold')

plt.tight_layout()
plt.savefig('confusion_barras.png')
print("Gráfico guardado en: confusion_barras.png")