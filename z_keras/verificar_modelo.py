import tensorflow as tf
import numpy as np

# 1. Verificar arquitectura del modelo
model = tf.keras.models.load_model("clasificador_documento.keras")

print("=== ÚLTIMA CAPA DEL MODELO ===")
print(model.layers[-1])
print(f"Activación: {model.layers[-1].activation}")
print()

# 2. Convertir SIN optimizaciones
print("=== CONVIRTIENDO SIN OPTIMIZACIONES ===")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
# SIN optimizaciones
tflite_model = converter.convert()

with open("clasificador_sin_opt.tflite", "wb") as f:
    f.write(tflite_model)

print(f"Modelo sin optimizaciones: {len(tflite_model) / 1024 / 1024:.2f} MB")
print()

# 3. Probar con una imagen de prueba
print("=== PRUEBA DE SALIDA ===")
# Crear imagen de prueba (224x224x3 con valores random)
test_image = np.random.rand(1, 224, 224, 3).astype(np.float32)

# Predicción con modelo Keras
keras_output = model.predict(test_image, verbose=0)[0]

print("Salida Keras:")
clases = ['documentos', 'folletos', 'fotos', 'manuscrito', 'tickets']
for i, clase in enumerate(clases):
    print(f"  {clase}: {keras_output[i]:.4f}")
print(f"  SUMA: {keras_output.sum():.4f}")
print()

# Predicción con TFLite
interpreter = tf.lite.Interpreter(model_path="clasificador_sin_opt.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

interpreter.set_tensor(input_details[0]['index'], test_image)
interpreter.invoke()
tflite_output = interpreter.get_tensor(output_details[0]['index'])[0]

print("Salida TFLite (sin opt):")
for i, clase in enumerate(clases):
    print(f"  {clase}: {tflite_output[i]:.4f}")
print(f"  SUMA: {tflite_output.sum():.4f}")