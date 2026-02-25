d# UI — Navegación y Estilos (Feb 2026)

## Diagrama de Navegación

```
                        ┌─────────────────────────────┐
                        │         /onboarding          │
                        └─────────────┬───────────────┘
                                      │ (primera vez)
                                      ▼
                        ┌─────────────────────────────┐
                        │           /home              │
                        │         HomePage             │
                        │                              │
                        │  [ESCANEAR]  [Importar]      │
                        │  ─────────────────────────   │
                        │  Últimos 3 documentos        │
                        │  ─────────────────────────   │
                        │  [Ver Todos]   [Buscar]      │
                        └──┬──────────┬───────────────┘
                           │          │
               ┌───────────┘          └───────────┐
               ▼                                  ▼
┌──────────────────────────┐      ┌───────────────────────────┐
│       /documents         │      │          /search           │
│   DocumentsListPage      │      │        SearchPage          │
│                          │      │                            │
│  Sort: reciente/nombre/  │      │  Barra pill + mic grande   │
│        tipo/antiguo      │      │  (vacío) / FAB mic         │
│  Lista completa + chips  │      │  (con resultados)          │
│  [Inicio]   [Buscar]     │      │  [Inicio]   [Limpiar]      │
└────────────┬─────────────┘      └──────────────┬────────────┘
             │ tap doc                            │ tap resultado
             └──────────────┬─────────────────────┘
                            ▼
             ┌──────────────────────────────┐
             │      /document/detail         │
             │     DocumentDetailPage        │
             │                              │
             │  ← Nombre doc  ✏️  🗑️         │
             │  ┌────────────────────────┐  │
             │  │   Imagen 280px         │  │
             │  └────────────────────────┘  │
             │  ┌────────────────────────┐  │
             │  │ 📝 Nota          >     │  │
             │  └────────────────────────┘  │
             │  ┌────────────────────────┐  │
             │  │ 📄 Texto extraído  >   │  │
             │  └────────────────────────┘  │
             └──────────────┬───────────────┘
                            │ tap card Nota
                            ▼
 
  ┌────────────────────────────────┐
  │  ←  │  Nota: Factura ABC  │    │  header (← con confirm)
  ├────────────────────────────────┤
  │                                │
  │   Escribir aquí...             │  área de texto (crece libre)
  │                                │
  ├────────────────────────────────┤
  │  [🗑 Borrar]  [🎙 Dictar]  [✓ GUARDAR] │
  └────────────────────────────────┘
                ↑ teclado sube acá


### Rutas y clases

| Ruta              | Widget               | Archivo                        |
|-------------------|----------------------|--------------------------------|
| `/home`           | `HomePage`           | `home_page.dart`               |
| `/documents`      | `DocumentsListPage`  | `documents_list_page.dart`     |
| `/search`         | `SearchPage`         | `search_page.dart`             |
| `/document/detail`| `DocumentDetailPage` | `document_detail_page.dart`    |
| `/note/edit`      | `NoteEditorPage`     | `note_editor_page.dart`        |

### Argumentos de navegación

```dart
// → /document/detail
arguments: int documentId

// → /note/edit
arguments: {
  'documentId':    int,
  'isEditing':     bool,
  'documentTitle': String,
}
```

### Navegación especial

- **Inicio** (desde notas): `pushNamedAndRemoveUntil('/home', (r) => false)`
- **Ver Todos** (desde notas): `pushNamedAndRemoveUntil('/documents', (r) => false)`
- Resto: `Navigator.pop` / `Navigator.pushNamed`

---

## Estilos reutilizables

### Fondo global
```dart
backgroundColor: const Color(0xFFF5F0E8)  // crema cálido
```

### Paleta de colores

| Uso                      | Color                          |
|--------------------------|--------------------------------|
| Fondo app                | `Color(0xFFF5F0E8)` crema      |
| Verde primario (botones) | `Color(0xFF388E3C)`            |
| Verde degradé top        | `Color(0xFF6FBF6F)`            |
| Verde degradé bottom     | `Color(0xFF2E7D32)`            |
| Sombra verde             | `Color(0xFF1A5C1A)` op. 50-55% |
| Verde apagado (Importar) | `Color(0xFF6A9E6A)`            |
| Borde crema              | `Color(0xFFBBAA88)`            |
| Sombra crema             | `Color(0xFF9A8060)` op. 40-45% |
| Chip fondo               | `Color(0xFFEEE4CC)`            |
| Chip texto               | `Color(0xFF5A4A30)`            |
| Texto sobre papel        | `Color(0xFFFDFAF2)` fondo      |

### Header compacto (sub-pantallas)

```dart
// Logo 38px + "EscanDocs" 24sp (centrado)
// Mismo en: DocumentsListPage, SearchPage
Padding(
  padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Image.asset('assets/images/logo.png', width: 38, height: 38),
    SizedBox(width: 8),
    RichText(text: TextSpan(children: [
      TextSpan('Escan', style: bold 24sp Color(0xFF388E3C)),
      TextSpan('Docs',  style: w400 24sp Color(0xFF1B5E20)),
    ])),
  ]),
)
```

### Botón 3D crema (outline, bottom bars y sort)

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.circular(50),
    border: Border.all(color: Color(0xFFBBAA88), width: 1.5),
    boxShadow: [BoxShadow(
      color: Color(0xFF9A8060).withOpacity(0.45),
      offset: Offset(0, 4), blurRadius: 7, spreadRadius: -1,
    )],
  ),
  child: Material(color: Colors.transparent,
    child: InkWell(borderRadius: BorderRadius.circular(50), ...)),
)
// Texto: 22sp, Color(0xFF5A4A30), w500 | Ícono: 20px, mismo color
```

### Botón verde degradé (ESCANEAR / GUARDAR)

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF6FBF6F), Color(0xFF2E7D32)],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.circular(50),
    boxShadow: [BoxShadow(
      color: Color(0xFF1A5C1A).withOpacity(0.50),
      offset: Offset(0, 4), blurRadius: 8, spreadRadius: -1,
    )],
  ),
  child: Material(color: Colors.transparent, ...),
)
// Texto: blanco, bold | Ícono: blanco
```

### Header de página con acciones (document_detail)

```dart
// ← Título centrado ✏️ 🗑️
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: Color(0xFFF5F0E8),
    border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
  ),
)
// ✏️ → Color(0xFF388E3C)  |  🗑️ → Colors.red[400]
```

### Card de sección (notas / OCR)

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(
      color: Colors.black.withOpacity(0.07),
      offset: Offset(0, 3), blurRadius: 8, spreadRadius: -1,
    )],
  ),
)
// Header interno: ícono 22px + título 17sp bold + Spacer + chevron_right gris
// Divider interno: Color(0xFFEEE4CC)
```

### Área de texto "papel" (NoteEditorPage)

```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFFFDFAF2),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Color(0xFFDDD0B8), width: 1.5),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), ...)],
  ),
  child: Stack(children: [
    TextField(maxLines: null, expands: true, border: InputBorder.none,
              style: TextStyle(fontSize: 17, height: 1.65)),
    Positioned(top: 14, right: 14,
      child: Icon(Icons.edit_note, size: 26, color: Colors.grey[300])),
  ]),
)
```

### Chip de tipo de documento

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: Color(0xFFEEE4CC),
    borderRadius: BorderRadius.circular(50),
    border: Border.all(color: Color(0xFFBBAA88), width: 1),
  ),
  child: Text(label, style: TextStyle(fontSize: 12, color: Color(0xFF5A4A30), w500)),
)
```

### Tamaños tipográficos referencia

| Elemento                   | Tamaño |
|----------------------------|--------|
| Logo home                  | 64px   |
| Logo sub-pantallas         | 38px   |
| Título home "EscanDocs"    | 32sp   |
| Título sub-pantallas       | 24sp   |
| Título página (Documents)  | 26sp   |
| Header detalle / nota      | 17-18sp|
| Texto botón bottom bar     | 22sp   |
| Texto botón acción         | 18sp   |
| Texto botón ESCANEAR       | 22sp   |
| Contenido nota             | 17sp   |
| Texto lista docs           | 17sp   |
| Fecha lista docs           | 14sp   |
| Chip tipo                  | 12sp   |
