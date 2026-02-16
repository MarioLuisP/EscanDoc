import tensorflow as tf
from tensorflow.keras import layers

IMG_SIZE = 224
BATCH_SIZE = 64
NUM_CLASSES = 5

train_ds = tf.keras.utils.image_dataset_from_directory(
    "G:/entrenamiento",
    validation_split=0.2,
    subset="training",
    seed=123,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode="int"
)

val_ds = tf.keras.utils.image_dataset_from_directory(
    "G:/entrenamiento",
    validation_split=0.2,
    subset="validation",
    seed=123,
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    label_mode="int"
)

# Data augmentation SEPARADO (solo para training)
data_augmentation = tf.keras.Sequential([
    layers.RandomFlip("horizontal"),
    layers.RandomRotation(0.1),
    layers.RandomZoom(0.15),
    layers.RandomContrast(0.2),
])

# Aplicar augmentation SOLO a train_ds
def apply_augmentation(x, y):
    return data_augmentation(x, training=True), y

train_ds_augmented = train_ds.map(apply_augmentation)

# Modelo SIN data augmentation adentro
base_model = tf.keras.applications.MobileNetV3Small(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights="imagenet"
)
base_model.trainable = False

model = tf.keras.Sequential([
    base_model,  # NO incluye data_augmentation
    layers.GlobalAveragePooling2D(),
    layers.Dense(128, activation="relu"),
    layers.Dropout(0.3),
    layers.Dense(NUM_CLASSES, activation="softmax")
])

model.compile(
    optimizer="adam",
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

# Entrenar con dataset augmentado
history = model.fit(train_ds_augmented, validation_data=val_ds, epochs=10)

# Fine-tuning
base_model.trainable = True
fine_tune_at = len(base_model.layers) - 40
for layer in base_model.layers[:fine_tune_at]:
    layer.trainable = False

model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-5),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

model.fit(train_ds_augmented, validation_data=val_ds, epochs=8)

# Guardar en formato nuevo
model.save("clasificador_documento.keras")
print("Modelo guardado en formato .keras")