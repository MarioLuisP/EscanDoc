Visualización de OCR

**Estado actual:**
- Texto extraído se guarda pero nunca se muestra
- Solo se usa para búsqueda interna

**Cambio:**
- OCR debe ser visible para el usuario
- Casos de uso: copiar texto, verificar extracción, entender naming

---

### . Rediseño DocumentDetailPage

**Nueva estructura (3 secciones verticales):**

**Sección 1 - Foto (50% altura):**
- Preview del documento escaneado
- Tap → abre fullscreen con zoom

**Sección 2 - Nota (20% altura):**
- Preview de la nota del usuario
- Tap → abre editor de nota

**Sección 3 - Texto OCR (30% altura):**
- Preview del texto extraído
- Tap → abre vista completa para lectura/copia
- Si OCR vacío → mostrar "No se pudo extraer texto"

**Características:**
- Las 3 secciones siempre visibles
- Sin tabs, sin opciones, sin configuración
- Navegación por tap directo
- Sin settings de visibilidad de secciones