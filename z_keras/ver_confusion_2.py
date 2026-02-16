import tensorflow as tf
import numpy as np
from sklearn.metrics import confusion_matrix, classification_report
import matplotlib.pyplot as plt
import seaborn as sns

model = tf.keras.models.load_model("clasificador_doc_vs_manuscrito.keras")

IMG_SIZE = 224
BATCH_SIZE = 64

val_ds = tf.keras.utils.image_dataset_from_directory(
    "G:/entrenamiento_2clases",
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

plt.figure(figsize=(8, 6))
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
            xticklabels=class_names, yticklabels=class_names)
plt.xlabel('Predicción')
plt.ylabel('Real')
plt.title(f'Documentos vs Manuscrito - Accuracy: {accuracy*100:.1f}%')
plt.tight_layout()
plt.savefig('confusion_matrix_2clases.png')
print("Matriz guardada en: confusion_matrix_2clases.png")