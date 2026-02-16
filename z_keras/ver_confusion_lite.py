import tensorflow as tf
import numpy as np
from sklearn.metrics import confusion_matrix, classification_report
import matplotlib.pyplot as plt
import seaborn as sns

# Cargar modelo TFLite
interpreter = tf.lite.Interpreter(model_path="clasificador_documento.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

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

y_true = []
y_pred = []

for images, labels in val_ds:
    for i in range(images.shape[0]):
        # Preparar input para TFLite
        input_data = np.expand_dims(images[i].numpy(), axis=0).astype(np.float32)
        
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]['index'])
        
        y_pred.append(np.argmax(output))
        y_true.append(labels[i].numpy())

y_true = np.array(y_true)
y_pred = np.array(y_pred)

accuracy = np.mean(y_true == y_pred)
print(f"\n>>> ACCURACY TFLite: {accuracy * 100:.2f}%\n")

cm = confusion_matrix(y_true, y_pred)
print("MATRIZ DE CONFUSIÓN:")
print(cm)
print("\n" + "="*60 + "\n")
print(classification_report(y_true, y_pred, target_names=class_names))

plt.figure(figsize=(10, 8))
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
            xticklabels=class_names, yticklabels=class_names)
plt.xlabel('Predicción')
plt.ylabel('Real')
plt.title(f'Accuracy: {accuracy*100:.1f}%')
plt.tight_layout()
plt.savefig('confusion_matrix_tflite.png')
print("Matriz guardada")