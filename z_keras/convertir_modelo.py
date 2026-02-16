import tensorflow as tf

model = tf.keras.models.load_model("clasificador_documento.keras")

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open("clasificador_documento.tflite", "wb") as f:
    f.write(tflite_model)

print("¡Modelo TFLite listo para Flutter!")
print(f"Tamaño: {len(tflite_model) / 1024 / 1024:.2f} MB")