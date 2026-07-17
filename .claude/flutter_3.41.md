Novedades de Flutter 3.41
Empoderar a la comunidad
Kevin Chisholm
Kevin Chisholm

Seguir
Lectura de 10 minutos

  ---
Beneficios concretos para este proyecto
1. Assets por plataforma (reducción de tamaño APK)                                                                                                                                                                               
   Esta es la más accionable. Podemos excluir assets pesados que solo aplican a ciertas plataformas:                                                                                                                                
   flutter:
   assets:
    - path: assets/models/        # modelos TFLite — solo mobile
      platforms: [android, ios]
      El proyecto tiene assets/models/ con modelos TFLite que no tienen sentido en otras plataformas.

2. Navigator.popUntilWithResult
   API nueva que simplifica flujos multi-pantalla retornando un valor en una sola llamada. Puede simplificar el flujo de escaneo cuando se navega de vuelta con resultado.

3. Accesibilidad en progress indicators
   CircularProgressIndicator y LinearProgressIndicator ahora anuncian actualizaciones a lectores de pantalla automáticamente — relevante dado el target de usuarios mayores.

4. RepeatingAnimationBuilder
   Útil si querés hacer animaciones de carga mientras procesa OCR/TFLite, declarativamente.

  ---
Alertas importantes

ve

  ---
¿Qué hacemos?

Lo más fácil y con mayor impacto inmediato es lo de los assets por plataforma en pubspec.yaml. ¿Querés que lo aplique? Necesito saber qué hay en assets/models/ para hacer bien la declaración.




·
11 de febrero de 2026
1,99 mil


28



Hoy nos complace anunciar el lanzamiento de Flutter 3.41, un hito transformador en nuestro camino juntos. ¡Qué momento tan emocionante para ser desarrollador! Este lanzamiento refleja nuestro compromiso de empoderar a nuestra comunidad para que defina el futuro de Flutter. Con 868 commits de 145 colaboradores únicos, Flutter 3.41 ofrece mayor transparencia y modularidad para mejorar aún más la experiencia de contribuir a Flutter.

Estamos implementando ventanas de lanzamiento público para que te resulte más fácil saber cuándo tus contribuciones se incluirán en una versión estable. Además, seguimos desacoplando nuestras bibliotecas de diseño, lo que a largo plazo nos ayudará a evolucionar los sistemas de diseño con mayor rapidez, a la vez que te brinda control sobre qué cambios de diseño adoptas en tus aplicaciones. Ya sea que estés aprovechando al máximo la GPU con nuevas mejoras en el sombreador de fragmentos o integrando Flutter sin problemas en aplicaciones nativas existentes con vistas del tamaño del contenido, esta versión te garantiza las herramientas necesarias para desarrollar con confianza y rapidez.

Hay tanto por explorar, así que ¡vamos a ello!

Pulsa Intro o haz clic para ver la imagen a tamaño completo.

Transparencia estructural y modularidad
Ventanas de lanzamiento público
La previsibilidad es clave para implementar funcionalidades complejas de forma segura. Estamos introduciendo ventanas de lanzamiento públicas para brindar a toda la comunidad la visibilidad necesaria para planificar con anticipación. Al anunciar públicamente las fechas límite de las ramas y los objetivos de lanzamiento, permitimos que toda la comunidad tenga claridad sobre cuándo se incorporarán sus cambios en futuras versiones estables.

¿Qué es una fecha límite para las ramas? Esta fecha es el plazo para que las solicitudes de extracción (pull requests) se incluyan en las ramas predeterminadas (tanto mainpara Dart como masterpara Flutter) y así garantizar su inclusión en la próxima versión estable. Si tu solicitud de extracción se fusiona antes de la fecha límite, se incluirá en la próxima versión estable. Si se fusiona después, se pospondrá al siguiente ciclo.

Para 2026, planeamos lanzar cuatro versiones estables (incluida esta), las fechas son las siguientes:

Flutter 3.41 — Febrero | Ramificado el 6 de enero
Flutter 3.44 — Mayo | Ramificaciones el 7 de abril
Flutter 3.47 — Agosto | Ramificaciones el 7 de julio
Flutter 3.50 — Noviembre | Ramificaciones el 6 de octubre
Desacoplamiento para un núcleo más esbelto
Continuamos con nuestro proyecto para migrar las bibliotecas Material y Cupertino a paquetes separados. Este enfoque modular tiene varias ventajas:

Ciclos de lanzamiento más rápidos: Ya no necesitamos esperar al lanzamiento trimestral del SDK para implementar actualizaciones de diseño. Podemos lanzar nuevas funciones de Material Design o Cupertino, así como correcciones de errores, en cuanto estén listas.
Actualizaciones independientes: Si está utilizando una versión anterior del SDK debido a una limitación del proyecto, aún puede actualizar sus paquetes de diseño para obtener la apariencia y la experiencia más recientes.
Diseño adaptativo: Los paquetes versionados nos permiten reaccionar mucho más rápido cuando iOS o Android introducen cambios de diseño drásticos como "Liquid Glass" o "Material 3 Expressive", lo que garantiza que su aplicación nunca parezca desactualizada.
Mantente al tanto del progreso en el hilo de GitHub .

Adoptar estándares de ecosistema
Parte de empoderar a la comunidad consiste en garantizar que Flutter funcione correctamente con las herramientas en las que ya confiamos.

Administrador de paquetes Swift y UIScene
La transición de CocoaPods a Swift Package Manager continúa. Recomendamos encarecidamente a los desarrolladores de plugins que adopten Swift Package Manager, ya que ahora es el estándar del ecosistema de Apple. Además, para garantizar la compatibilidad con futuras versiones de iOS, Flutter ahora es totalmente compatible con el ciclo de vida de UIScene de forma predeterminada . Esta actualización es fundamental para cumplir con los requisitos de Apple para las próximas versiones de iOS. Para simplificar la migración desde la lógica del ciclo de vida de AppDelegate, que ya no se utiliza, consulta nuestra guía de migración .

Complemento de grado de Android (AGP) 9 y Kotlin DSL
Continuamos adaptándonos a los estándares modernos de Android. Con el lanzamiento de Android Gradle Plugin (AGP) 9, estamos trabajando para dar soporte a los nuevos requisitos de rigurosidad y proporcionar orientación sobre cómo gestionarlos.

Advertencia: No actualice su aplicación Flutter para Android a AGP 9, ya que la migración de complementos a AGP 9 y las aplicaciones Flutter en AGP 9 que utilizan complementos aún no son compatibles ( #181383) . Esta compatibilidad está suspendida mientras el equipo de Flutter audita la migración para verificar la compatibilidad con versiones anteriores de AGP. Este documento de migración se actualizará a medida que cambien las directrices.

Gracias a las contribuciones del miembro de la comunidad Byoungchan Lee (bc-lee@) , los nuevos proyectos de complementos ahora utilizan por defecto el DSL de Kotlin para Gradle.

activos específicos de la plataforma
Optimizar ahora es más fácil gracias al trabajo de Alex Frei (hm21@) . Ahora puedes especificar en tu archivo pubspec.yaml para qué plataformas se debe empaquetar un recurso. Esto permite optimizaciones como excluir recursos pesados ​​de escritorio de las compilaciones para móviles, lo que reduce significativamente el tamaño de la aplicación.

flutter:
assets:
-  path:  assets/logo.png
-  path:  assets/web_worker.js
platforms: [ web ]
-  path:  assets/desktop_icon.png
platforms: [ windows , linux , macos ]
Escuchar a la comunidad
El equipo de Flutter en Google sigue dando prioridad a lo que más te importa.

La experiencia de inicio
Pulsa Intro o haz clic para ver la imagen a tamaño completo.

Durante años, la comunidad ha señalado que, si bien Flutter es una herramienta excelente y productiva, puede resultar difícil saber por dónde empezar a aprender a usarla.

Recientemente lanzamos una experiencia de inicio para Dart y Flutter completamente rediseñada .

Recibe las historias de Kevin Chisholm en tu correo electrónico.
Regístrate gratis en Medium para recibir actualizaciones de este autor.

Introduce tu correo electrónico
Suscribir

Recuérdame para iniciar sesión más rápido.

Se trata de una nueva ruta de aprendizaje diseñada para guiarte a través de los fundamentos de la creación de aplicaciones con Flutter y Dart. Echemos un vistazo rápido a algunos de los cambios:

Hemos lanzado una nueva guía de instalación rápida que aprovecha la recarga instantánea en la web, lo que permite a los usuarios experimentar todo el potencial de Flutter rápidamente, sin necesidad de configurar previamente un entorno específico para cada plataforma. El programa incluye tutoriales escritos, cuestionarios sencillos y ocho nuevos vídeos con la participación de miembros conocidos del equipo de Flutter en Google.
Los alumnos finalizarían el programa de aprendizaje habiendo creado 4 aplicaciones completamente desde cero.
Prueba la nueva experiencia de inicio en la sección de aprendizaje de nuestro sitio web, que ha sido rediseñada recientemente y funciona con tecnología Jaspr .

Mejoras en el sombreador de fragmentos
En el cuarto trimestre de 2025, encuestamos a desarrolladores que utilizaban la FragmentShaderAPI y les preguntamos simplemente: ¿Qué les dificulta el trabajo? Nos comentaron que necesitaban una ergonomía mejorada al usar la API, además de mayor flexibilidad al definir sus sombreadores. En respuesta a esto, realizamos los siguientes cambios:

En la versión 3.41, añadimos la decodificación síncrona de imágenes. Anteriormente, la creación de texturas para sombreadores podía introducir un retardo de un fotograma. decodeImageFromPixelsSyncAhora, puedes generar texturas y utilizarlas como muestreadores en el mismo fotograma.
También hemos añadido compatibilidad con texturas de alta tasa de bits (hasta 128 bits de coma flotante), lo que permite utilizar tablas de búsqueda (LUT) de alta resolución para filtros fotográficos acelerados por GPU y SDF.
void  attachTexture (ui.FragmentShader shader)  {
ui.PictureRecorder recorder = ui.PictureRecorder();  Canvas canvas = Canvas ( recorder );  canvas.drawCircle ( const Offset ( 64 , 64 ), 64 , Paint ()..color = Colors.red);  ui.Picture picture = recorder.endRecording();  ui.Image image =picture.toImageSync ( 128 , 128 , targetFormat :    ui.TargetPixelFormat.rFloat32,  );  shader.setImageSampler( 0 , image) ; }









Vistas previas de widgets (experimental)
Basándonos en sus comentarios iniciales, estamos trabajando rápidamente en las vistas previas de los widgets. Con esta versión, las vistas previas de los widgets han mejorado de la siguiente manera:

Compatibilidad con Flutter Inspector: El entorno de vista previa de widgets ahora tiene acceso a una instancia integrada de Flutter Inspector, lo que facilita la inspección de diseños y el estado de los widgets previsualizados. Nota importante: Es posible que deba configurar directorios de paquetes adicionales para ver los widgets de su proyecto de forma predeterminada. Para ello, abra la configuración de Flutter Inspector haciendo clic en el icono de engranaje y agregue un nuevo directorio de paquetes que apunte a su proyecto.
Pulsa Intro o haz clic para ver la imagen a tamaño completo.

Compatibilidad con aplicaciones con dart:ffidependencias: Anteriormente, las vistas previas que incluían widgets con dependencias transitivas de bibliotecas que importaban dart:fficausaban errores de compilación e impedían que el entorno de vista previa se actualizara. Esto ocurría porque dart:ffino es compatible con plataformas web ( flutter/flutter#166431 ). El previsualizador de widgets ahora puede manejar vistas previas que tienen dependencias de bibliotecas específicas de la plataforma, incluidas dart:ffiy dart:io. Nota importante : la invocación de API de estas bibliotecas no es compatible con el previsualizador de widgets y dará como resultado que se muestre un error para las vistas previas que llamen a estas API específicas de la plataforma. Consulte la documentación de Dart sobre importaciones condicionales para ver ejemplos de cómo escribir código que sea compatible con plataformas nativas y web.
Fidelidad y refinamiento del marco
Continuamos perfeccionando la experiencia actual, centrándonos en la fidelidad a la plataforma y la eficiencia de los desarrolladores.

Pulido de iOS
En Flutter 3.41 hemos realizado mejoras visuales con el nuevo estilo de "desenfoque delimitado". Anteriormente, los widgets translúcidos que utilizaban este estilo BackdropFilterpodían sufrir de sangrado de color en los bordes. Gracias a las mejoras en el motor de renderizado Impeller, hemos eliminado este problema.

Pulsa Intro o haz clic para ver la imagen a tamaño completo.
Pulsa Intro o haz clic para ver la imagen a tamaño completo.
También hemos añadido compatibilidad con el manejo de arrastre de estilo nativo a CupertinoSheettravés de la showDragHandlepropiedad.

Pulsa Intro o haz clic para ver la imagen a tamaño completo.

Agregar a la aplicación
¡Añadir vistas de Flutter a aplicaciones Android e iOS existentes ahora es más fácil! Las vistas de Flutter integradas en aplicaciones nativas existentes pueden redimensionarse automáticamente según su contenido. Anteriormente, una vista de Flutter necesitaba un tamaño fijo proporcionado por su componente nativo. Esto dificultaba algunos casos, como añadir vistas de Flutter a una vista nativa desplazable.

Para usar esta función, el widget raíz debe admitir restricciones sin límite. Evite usar widgets que requieran un tamaño predefinido (como ListViewo LayoutBuilder) en la parte superior del árbol, ya que entrarán en conflicto con la lógica de dimensionamiento dinámico.

Para habilitar este comportamiento en iOS, establezca FlutterViewController.isAutoResizableen true . Para Android, habilite el dimensionamiento del contenido en su Android Manifest y establezca el ancho o alto de su FlutterView en content_wrap.

Pulsa Intro o haz clic para ver la imagen a tamaño completo.
Pulsa Intro o haz clic para ver la imagen a tamaño completo.
Navegación y desplazamiento
Hemos trabajado arduamente para pulir los aspectos menos pulidos de los modelos de interacción principales mediante los siguientes cambios:

Hemos introducidoNavigator.popUntilWithResult, lo que permite mostrar varias pantallas y devolver un valor a la ruta de destino en una sola llamada, simplificando drásticamente la gestión del estado en flujos de varios pasos.
Lo reimplementamosStretchingOverscrollIndicatorUtilizando un enfoque basado en simulación, adaptado de Android 12, se garantiza un efecto de desplazamiento más natural y fluido que responde correctamente a los movimientos bruscos de alta velocidad.

Hemos corregido un problema con los encabezados fijados en NestedScrollViewy SliverMainAxisGroup, asegurando que los encabezados se superpongan correctamente a los fragmentos subsiguientes.
Accesibilidad
Ayudarte a crear experiencias accesibles que lleguen a los usuarios en cualquier pantalla es la esencia de nuestra misión. En esta actualización, hemos añadido lo siguiente:

Compatibilidad nativa con la accesibilidad para CircularProgressIndicatory LinearProgressIndicator, lo que permite que las tecnologías de asistencia anuncien actualizaciones de progreso.
Flutter ahora respeta las configuraciones personalizadas de espaciado de texto de los usuarios web para mejorar la experiencia de lectura.
Hemos introducido nuevos comparadores como isSemanticsy accessibilityAnnouncementen flutter_test para facilitar la validación de la accesibilidad.
Material y animación
Hemos introducido nuevas primitivas y propiedades para ampliar el control sobre las animaciones y el diseño. Gracias al trabajo del miembro de la comunidad Bernardo Ferrari (bernaferrari@) , RepeatingAnimationBuilderse introduce una forma declarativa de crear animaciones continuas como un indicador de carga, un botón pulsante o un efecto de marcador de posición brillante.

Por ejemplo, así es como puedes hacer que un cuadrado se deslice hacia adelante y hacia atrás:

RepeatingAnimationBuilder<Offset>(
animatable: Tween<Offset>(
begin: const Offset( -1.0 , 0.0 ),
end: const Offset( 1.0 , 0.0 ),
),
duration: const  Duration (seconds: 1 ),
repeatMode: RepeatMode.reverse,
curve: Curves.easeInOut,
builder: (BuildContext context, Offset offset, Widget child) {
return FractionalTranslation(
translation: offset,
child: child,
);
},
child: const ColoredBox(
color: Colors.green,
child: SizedBox.square(dimension: 100 ),
),
),
También actualizamos CarouselViewcon un .builderconstructor, lo que facilita la creación de carruseles con contenido dinámico. DropdownMenuFormFieldAhora admite un personalizado errorBuildery RawAutoCompleteahora incluye una OptionsViewOpenDirection.mostSpaceopción para posicionar de forma inteligente las opciones en función del espacio disponible en la pantalla.

evolución liderada por la comunidad
Uno de los mejores ejemplos de colaboraciones de código abierto en Flutter es nuestra larga relación con Canonical. Su equipo sigue impulsando la hoja de ruta de Flutter Desktop, ofreciendo funciones esenciales que benefician a todo el ecosistema.

Gracias al liderazgo de ingeniería de Canonical, estamos reduciendo la brecha en los requisitos de interfaz de usuario de escritorio complejos. Esta versión introduce API experimentales para crear ventanas emergentes y ventanas de información sobre herramientas, junto con compatibilidad multiplataforma para ventanas de diálogo en Linux, macOS y Windows. Finalmente, se agregaron nuevas API para que puedas probar aplicaciones con múltiples ventanas. Si quieres echar un vistazo a estas próximas API de ventanas, ¡echa un vistazo a la aplicación de ejemplo multiple_windows de Flutter !

Flutter Linux ahora también habilita los subprocesos combinados de forma predeterminada, lo que simplifica el modelo de subprocesos y mejora el rendimiento, además de contribuir a la estabilidad en Windows. Tenemos previsto eliminar la opción de desactivar los subprocesos combinados en una futura versión. Si tiene algún problema con los subprocesos combinados, por favor, háganoslo saber .

Herramientas para desarrolladores
Devtools ha experimentado mejoras en rendimiento y estabilidad:

Las herramientas para desarrolladores de Flutter se compilan con dart2wasm, lo que mejora el rendimiento. Si lo desea, puede optar por no usar la compilación con dart2js en las herramientas para desarrolladores a través del cuadro de diálogo de configuración.
Las conexiones interrumpidas con el demonio de herramientas de dardos (DTD) ahora se reintentan automáticamente para mejorar la experiencia cuando su máquina se reanuda después del modo de suspensión.
Estos son solo algunos de los aspectos más destacados de esta versión. Para conocer todas las actualizaciones incluidas en Flutter 3.41, consulta las notas de la versión de DevTools 2.52.0 , 2.53.0 y 2.54.0 .

Siguiente parada:flutter upgrade
Flutter 3.41 representa un avance hacia la mejora de nuestra experiencia de contribución al código abierto, a la vez que optimiza las características fundamentales de Flutter para mejorar tu experiencia de desarrollo, ya sea que estés migrando un plugin a Swift Package Manager, optimizando recursos para plataformas específicas o trabajando con nuevas API de sombreado. Estamos agradecidos por la increíble comunidad que hemos construido juntos.

Para obtener una lista completa de todos los cambios, asegúrese de consultar los cambios importantes y las notas de la versión . Para probar las nuevas funciones de Flutter 3.41, solo necesita un flutter upgrade!
