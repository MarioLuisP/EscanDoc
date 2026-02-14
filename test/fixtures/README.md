# Test Fixtures

Este directorio contiene archivos de prueba para los tests.

## Imágenes Requeridas

Para que los tests de `TFLiteImageClassifier` funcionen completamente, agrega:

- `test_document.jpg` - Una imagen de documento real (puede ser cualquier documento escaneado)

Si no existen, los tests se saltarán automáticamente con un warning.

## Cómo agregar

1. Toma una foto de cualquier documento
2. Renómbrala a `test_document.jpg`
3. Cópiala a este directorio

El modelo clasificará esta imagen y verificaremos que retorna un resultado válido.
