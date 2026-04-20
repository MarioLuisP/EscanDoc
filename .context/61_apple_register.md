Identificó solicitud específica e ignoró contexto previoPerfecto. Entonces vamos con iOS build en CodeMagic para EscanDoc.
Antes de empezar necesito confirmar el estado actual:

¿Ya tenés CodeMagic conectado al repo de EscanDoc?
¿Ya existe un archivo codemagic.yaml en el proyecto, o partimos de cero?
¿Tenés acceso al Apple Developer Portal y App Store Connect?
¿Ya hay un Team ID de Apple identificado, o necesitamos obtenerlo?

Con eso claro, te guío paso a paso por:

Registrar el Bundle ID en Developer Portal
Crear la app en App Store Connect
Configurar el codemagic.yaml con BUNDLE_ID = com.passalia.escandoc hardcodeado

¿Qué tenemos listo y qué falta? 🔑olvidate de los puntos 1 y 2
tengo acceso a apple develope portal y connectEl Team ID es el mismo para toda la cuenta Apple — QuéHacemos , mi otra app, ya está en producción, ya lo tengo. Es el ID de tu Apple Developer membership, único por cuenta.1:16 p. m.Recalibró enfoque hacia configuración única de Bundle IDRecalibró enfoque hacia configuración única de Bundle IDCopy. Entonces arrancamos así:

PASO 1: Registrar Bundle ID en Apple Developer Portal

Ve a developer.apple.com → Certificates, Identifiers & Profiles
Selecciona Identifiers en el menú izquierdo
Clickea el + (registrar nuevo identifier)
Selecciona App IDs y sigue
Tipo: App (no Wildcard)
Description: EscanDoc
Bundle ID: com.passalia.escandoc (explícito, no wildcard)
Capabilities: habilita lo que EscanDoc usa (típicamente: Push Notifications si tiene, Camera, File Sharing, etc. — ¿cuáles usa EscanDoc?)
Registra


PASO 2: Crear la app en App Store Connect

Ve a appstoreconnect.apple.com
My Apps → + (nueva app)
Selecciona iOS (no macOS, tvOS, etc.)
Completa:

Name: EscanDoc
Primary Language: Spanish (Spain) o tu preferencia
Bundle ID: com.passalia.escandoc (debe matchear lo que registraste)
SKU: algo único, ej. com.passalia.escandoc.2026


Crea la app


¿Ya? Avanzamos al paso 3 (el yaml de CodeMagic)?
¿Cuáles son las capabilities que EscanDoc necesita? (Camera, Photos, notifications, etc.)vamos con el paso 1: y vamos punto por punto y me esperas hasta que digo listo1:17 p. m.Orchestrated methodical breakdown awaiting confirmation at each stepOrchestrated methodical breakdown awaiting confirmation at each step👍 Perfecto.

PASO 1: Registrar Bundle ID en Apple Developer Portal
Punto 1.1: Acceder a Developer Portal
Ve a developer.apple.com e inicia sesión con tu cuenta Apple.
Una vez dentro, clickea en "Certificates, Identifiers & Profiles" (debería salir en la pantalla principal o en el menú).
Avísame cuando estés ahí. 👀listo, tengo estas opciones:Certificados (inglés)Identificadores (inglés)Dispositivos (inglés)Perfiles (inglés)Claves (inglés)
*1:20 p. m.Pensando en clarificar la intención detrás de estas opciones listadasPensando en clarificar la intención detrás de estas opciones listadasPerfecto. Ahora clickea en Identificadores (que es "Identifiers" en inglés).
Avísame cuando estés dentro. 👇listo
tengo estas opciones
Certificates, Identifiers & Profiles
All Identifiers
Register an App ID
BackContinue
Platform
iOS, iPadOS, macOS, tvOS, watchOS, visionOS
App ID PrefixU39UK4J4WR (Team ID)
DescriptionYou cannot use special characters such as @, &, *, "
Bundle ID
ExplicitWildcard
We recommend using a reverse-domain name style string (i.e., com.domainname.appname). It cannot contain an asterisk (*).
Capabilities
App Services
Capability Requests*Mostrar más1:22 p. m.Delineó pasos secuenciales para registrar identificador de aplicaciónDelineó pasos secuenciales para registrar identificador de aplicaciónPerfecto. Estás en la pantalla de registrar un nuevo App ID.
Ahora sigue esto:
Punto 1.2: Seleccionar Platform
En la sección Platform, selecciona iOS (es la más común para EscanDoc).
Avísame cuando lo hayas clickeado. 👆listo1:23 p. m.Thinking about interpreting a minimal affirmation or readiness signalThinking about interpreting a minimal affirmation or readiness signalBien. Ahora ve a la sección Description y escribe:
EscanDoc
Avísame cuando lo hayas ingresado. ✍️hecho1:24 p. m.Thinking about the meaning of "hecho" in SpanishThinking about the meaning of "hecho" in SpanishBien. Ahora en la sección Bundle ID, selecciona la opción Explicit (porque necesitamos un Bundle ID específico, no un wildcard).
Avísame cuando lo hayas seleccionado. 🎯adelante1:24 p. m.Thinking about interpreting a single Spanish word with minimal contextThinking about interpreting a single Spanish word with minimal contextPerfecto. Ahora en el campo Bundle ID ingresa:
com.passalia.escandoc
Avísame cuando lo hayas ingresado. ✍️listo
¿tenemos que seleccionar algo de
Capabilities
App Services
Capability Requests?1:25 p. m.Deliberó sobre capabilities necesarios sin asumir detallesDeliberó sobre capabilities necesarios sin asumir detallesBuena pregunta. Depende de lo que EscanDoc necesite:
Según lo que sé del proyecto, necesitaría al menos:

Camera (para el escaneo de documentos)
Push Notifications (para los avisos de vencimiento de facturas)

¿EscanDoc usa otras capabilities? (ej: Photos library, File Sharing, etc.)
O si preferís, podés dejar esto vacío ahora y agregarlo después si lo necesitás. La decisión es tuya. 🤔Capabilities reales (necesitan entitlement en el provisioning profile):                                                                                                                                                            - Push Notifications — flutter_local_notifications necesita aps-environment en el entitlement
- App Groups — receive_sharing_intent necesita un App Group para recibir archivos compartidos desde otras apps (share extension). Este es el más complejo.                                                                         Permisos de Info.plist (ya están todos en tu Info.plist, no son capabilities de Xcode):                                                                                                                                            - Camera → NSCameraUsageDescription ✓                                                                                                                                                                                              - Photo Library → NSPhotoLibraryUsageDescription + NSPhotoLibraryAddUsageDescription ✓
- Microphone → NSMicrophoneUsageDescription ✓
- Speech Recognition → NSSpeechRecognitionUsageDescription ✓Mostrar más1:30 p. m.Delineated essential capabilities versus Info.plist permissions for iOS configurationDelineated essential capabilities versus Info.plist permissions for iOS configurationClaro. Entonces en esta pantalla de Apple Developer Portal, en la sección Capabilities, selecciona:

Push Notifications
App Groups

Esos son los que necesitan entitlement en el provisioning profile.
Los otros (Camera, Photo Library, Microphone, Speech Recognition) ya están en tu Info.plist, así que no los tocamos aquí.
Avísame cuando hayas seleccionado esos dos. ✅Push NotificationsBroadcast Capability
¿tildo Broadcast Capabilit?1:32 p. m.Evaluating Broadcast Capability relevance para EscanDocEvaluating Broadcast Capability relevance para EscanDocNo. No tildes Broadcast Capability.
Para EscanDoc (notificaciones de vencimiento de facturas) necesitas la capability básica de Push Notifications, sin Broadcast.
Continúa. 👇¿o sea que de estos 3 Capabilities
App Services
Capability Requests, lo unico que tengo que tildar es - Push Notifications —
- App Groups?1:34 p. m.Confirmando que solo Push Notifications y App Groups requieren tildarConfirmando que solo Push Notifications y App Groups requieren tildarExacto. De todo lo que ves en esa sección, tilda solo:

✅ Push Notifications
✅ App Groups

Esos dos. Nada más.
Avísame cuando hayas tildado ambos. 👇listo1:34 p. m.Aguardando confirmación para proseguir al siguiente pasoAguardando confirmación para proseguir al siguiente pasoPerfecto. Ahora busca un botón "Continue" o "Register" en la pantalla (usualmente en la parte inferior derecha).
Clickealo para registrar el App ID.
Avísame cuando hayas clickeado. 👇Confirm your App ID
BackRegister
Platform
iOS, iPadOS, macOS, tvOS, watchOS, visionOS
App ID PrefixU39UK4J4WR (Team ID)
DescriptionEscanDoc
Bundle ID
com.passalia.escandoc (explicit)1:36 p. m.Thinking about verifying App ID credentials and bundle identifier detailsThinking about verifying App ID credentials and bundle identifier detailsPerfecto. Todo está correcto. Ahora clickea el botón "Register" (parte inferior derecha) para confirmar y registrar el App ID.
Avísame cuando hayas clickeado. 👇listo1:36 p. m.Verified successful registration and mapped next implementation stepsVerified successful registration and mapped next implementation stepsExcelente. El Bundle ID com.passalia.escandoc está ahora registrado en Apple Developer Portal.
Deberías ver una pantalla de confirmación diciendo algo como "App ID registered successfully" o similar.
¿La ves? 👀si
dentifiers
App IDs
NameIdentifier
Agenda cultural de Cordoba Argentina
com.quehacemos.cba
EscanDoc
com.passalia.escandoc1:37 p. m.Verified app identifiers and advanced to next implementation phaseVerified app identifiers and advanced to next implementation phasePerfecto. ✅ PASO 1 completado.
Ves en la lista:

com.quehacemos.cba (tu app existente)
com.passalia.escandoc (EscanDoc, recién registrado)


Ahora pasamos al PASO 2: Crear la app en App Store Connect.
Ve a appstoreconnect.apple.com e inicia sesión.
Una vez dentro, busca "My Apps" en el menú.
Avísame cuando estés ahí. 👀Nueva app
Plataformas
?
iOSmacOStvOSvisionOS
Nombre
?
30
Idioma principal
?
ElegirAlemánÁrabeBengalíCanarésCatalánChecoChino (simplificado)Chino (tradicional)CoreanoCroataDanésEslovacoEslovenoEspañol (España)Español (México)FinésFrancés (Canadá)Francés (Francia)GriegoGuyaratíHebreoHindiHolandésHúngaroIndonesioInglés (Australia)Inglés (Canadá)Inglés (EE. UU.)Inglés (Reino Unido)ItalianoJaponésMalayalamMalayoMaratíNoruegoOriyaPanyabíPolacoPortugués (Brasil)Portugués (Portugal)RumanoRusoSuecoTailandésTamilTeluguTurcoUcranianoUrduVietnamita
ID de pack
?
ElegirEscanDoc - com.passalia.escandocQuehaCeMos Sign in with Apple - com.quehacemos.cba.signin
Registra un nuevo ID de pack en Certificados, identificadores y perfiles.
SKU
?
Acceso de usuarios
?
Acceso limitadoAcceso ilimitadoMostrar más1:38 p. m.Delineated app creation steps for iOS platform configurationDelineated app creation steps for iOS platform configurationBien. Estás en la pantalla de crear una nueva app en App Store Connect.
Sigue esto punto a punto:
Punto 2.1: Plataformas
Selecciona iOS (la opción está en la sección Plataformas).
Avísame cuando lo hayas seleccionado. ✅adelante1:39 p. m.Thinking about interpreting a single Spanish word with minimal contextThinking about interpreting a single Spanish word with minimal contextPunto 2.2: Nombre
En el campo Nombre, ingresa:
EscanDoc
Avísame cuando lo hayas ingresado. ✍️adelante1:39 p. m.Progressed workflow after confirming previous step completionProgressed workflow after confirming previous step completionPunto 2.3: Idioma principal
En el dropdown Idioma principal, selecciona Español (España) (o Español (México) si preferís, pero generalmente Spain es estándar).
Avísame cuando lo hayas seleccionado. 🌍listo
tambien listo idpac  escandoc1:41 p. m.Validó confirmaciones y delineó próximos pasos operacionalesValidó confirmaciones y delineó próximos pasos operacionalesPerfecto. El ID de pack está bien: com.passalia.escandoc (es el que registramos).
Ahora falta el SKU.
Punto 2.4: SKU
En el campo SKU, ingresa:
com.passalia.escandoc.2026
Avísame cuando lo hayas ingresado. ✍️¿al sku lo inventamos nosotros?1:42 p. m.Aclaró que los desarrolladores inventan el SKU únicoAclaró que los desarrolladores inventan el SKU únicoSí. El SKU lo inventamos nosotros. Es un identificador interno único que Apple usa para tu app.
No es visible para usuarios, y no puede cambiar después de que registres la app.
Típicamente es el Bundle ID + algo único. La sugerencia com.passalia.escandoc.2026 funciona, pero podés usar:

escandoc
escandoc-2026
Lo que prefieras, mientras sea único en tu cuenta

¿Usamos com.passalia.escandoc.2026 o preferís otro? 🤔Yo iría con escandoc a secas — limpio, único dentro de tu cuenta, sin fecha que envejece1:43 p. m.Pensando en recomendaciones de diseño limpio y minimalista sin elementos temporalesPensando en recomendaciones de diseño limpio y minimalista sin elementos temporalesPerfecto. Sensato. Usamos escandoc.
Punto 2.4: SKU
En el campo SKU, ingresa:
escandoc
Avísame cuando lo hayas ingresado. ✍️listo1:43 p. m.Thinking about interpreting a minimal affirmation or readiness signalThinking about interpreting a minimal affirmation or readiness signalPunto 2.5: Acceso de usuarios
En la sección Acceso de usuarios, selecciona Acceso ilimitado (es lo estándar para una app pública).
Avísame cuando lo hayas seleccionado. 👇listo , ya esta creada1:45 p. m.Confirmó creación de app y planificó siguiente paso configurativoConfirmó creación de app y planificó siguiente paso configurativoExcelente. ✅ PASO 2 completado.
EscanDoc está ahora registrada en App Store Connect con:

Nombre: EscanDoc
Bundle ID: com.passalia.escandoc
SKU: escandoc
Idioma: Español (España)


¿Ves la página de detalles de la app en App Store Connect (donde podés editar info, pricing, etc.)?
Avísame cuando la veas. 👀si , EscanDocDistributionAnalyticsTestFlightXcode Cloud
eswta todo| necesito algo mas por ahora?1:45 p. m.Verificando tareas completadas y evaluando necesidades restantesVerificando tareas completadas y evaluando necesidades restantesPor ahora no.
Hemos completado lo que necesitabas de App Store Connect:

✅ Bundle ID registrado
✅ App creada


El siguiente paso es configurar el codemagic.yaml con el Bundle ID hardcodeado y los certificados/provisioning profiles.
¿Vamos directo a eso, o hay algo más que necesites en App Store Connect antes? 🤔

Riesgos específicos de iOS:
1. flutter_doc_scanner — el scanner nativo usa APIs de iOS que pueden comportarse diferente. Hay que probar el flujo completo de escaneo.
2. Permisos — cámara, galería, archivos. Si falta algún NSCameraUsageDescription u otro key en Info.plist, la app crashea en runtime sin aviso.
3. ML Kit — nunca se probó en iOS real. El OCR y clasificador TFLite pueden tener diferencias de comportamiento.
4. SQLite / paths — los paths de archivos en iOS son diferentes a Android. Si hay algún path hardcodeado puede fallar.
5. UI — el sistema de navegación y algunos widgets se ven diferente en iOS.

