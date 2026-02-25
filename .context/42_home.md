Quiero que me crees un widget Flutter (pantalla completa) que replique **lo más exactamente posible** esta UI de la captura adjunta. Es la pantalla principal de una app de escaneo/almacenamiento de documentos.

Requisitos obligatorios (sigue la captura al 100% en disposición, proporciones, redondeados, sombras, tipografías visuales y espaciados):

- Fondo de pantalla: blanco puro o #FAFAFA muy claro
- Header superior (no AppBar, sino parte del body):
    - Alineado a la izquierda: logo (ícono de libro abierto o caja verde oscuro) + texto "EscanCanDocs" en verde oscuro bold (~#166534 o #15803d)
    - Tamaño de texto del logo ~24-28 sp, bold
    - Sin ícono de búsqueda arriba (está abajo)

- Espacio grande central (~35-40% de la altura):
    - Botón principal enorme "ESCANEAR"
        - Forma: cápsula muy redondeada (border radius ~999)
        - Fondo: verde fuerte (#22c55e o similar al de la captura)
        - Texto: blanco, bold, ~28-32 sp, centrado
        - Sombra: elevation 6-10 o BoxShadow verde suave difuminado
        - Debajo del botón: texto pequeño gris medio (~#6b7280) "Escaneará y guardará tus documentos." centrado

- Sección "Últimos documentos" (debajo, con buen padding):
    - Título: "Últimos documentos" en gris oscuro (#1f2937), bold, ~20 sp
    - Lista de 3 cards verticales (sin scroll por ahora, solo 3 fijos):
        - Cada card:
            - Container con border radius ~12-16, fondo blanco, sombra sutil (elevation 2-3)
            - Row:
                - Izquierda: imagen/thumbnail del documento (~64-80 width, height ~90-110, border radius ~8, fit: cover o contain)
                - Derecha: Column con
                    - Nombre del doc en bold ~16-18 sp (ej: "Factura Luz Enero")
                    - Fecha debajo en gris claro ~14 sp (ej: "25 Ene 2026")
            - Padding interno generoso (~16-20 horizontal y vertical)
        - Datos exactos de la captura:
            1. "Factura Luz Enero" – 25 Ene 2026
            2. "Recibo de Alquiler" – 18 Ene 2026
            3. "Nota Médica" – 10 Ene 2026
        - Todas las cards deben ser GestureDetector / InkWell (clickeables, con ripple effect sutil)

- Parte inferior (fondo de pantalla, no BottomNavigationBar):
    - Row con dos botones grandes lado a lado (mainAxisAlignment: spaceEvenly o con padding simétrico)
        - Botón izquierdo: "Ver Todos"
            - Fondo: blanco o muy claro
            - Borde: verde 1.5-2px
            - Texto: verde bold ~18 sp
            - Ícono: carpeta (Icons.folder o Icons.folder_open) a la izquierda, verde
            - borderRadius ~16-20
        - Botón derecho: "Buscar"
            - Fondo: verde fuerte (mismo del botón ESCANEAR)
            - Texto: blanco bold ~18 sp
            - Ícono: lupa (Icons.search) a la izquierda, blanco
            - borderRadius ~16-20
        - Ambos botones con altura ~56-64, sombra ligera (elevation 3-5)

- **Botón extra que necesito agregar**: "Importar desde celular" (o "Importar documento")
    - Sugerencia de ubicación: ponlo **justo debajo del botón ESCANEAR**, antes de la sección "Últimos documentos", centrado, mismo estilo que "Ver Todos" y "Buscar" (borde verde, fondo blanco, ícono de upload o add_from_drive)
    - Texto: "Importar desde celular" o "Agregar documento"
    - Hazlo un poco más pequeño que el botón ESCANEAR pero igual de prominente

Usa:
- Solo widgets nativos de Flutter (Container, Column, Row, GestureDetector/InkWell, etc.)
- Google Fonts si quieres (Inter o Roboto), pero si no, usa Theme.of(context).textTheme con pesos bold/medium
- Tamaños en sp para textos, dp-like en paddings/margins (usa MediaQuery para escalar si quieres, pero prioriza proporciones visuales de la captura)
- Hazlo optimizado para móvil (SafeArea, padding horizontal 16-24)
- Todos los botones y cards deben ser totalmente interactivos (onTap con print o callback vacío por ahora)

Devuélveme SOLO el código completo del StatelessWidget (o Stateful si lo necesitas) listo para pegar en un archivo .dart.
No agregues explicaciones largas, comentarios mínimos, solo el código limpio y funcional.

Si necesitas aproximar mejor los colores exactos del logo/botones, usa estos como guía aproximada:
- Verde principal botón: #22c55e o #16a34a
- Verde logo/texto: #166534
- Gris títulos: #1f2937
- Gris secundario: #6b7280
- Gris fecha: #9ca3af

Gracias.