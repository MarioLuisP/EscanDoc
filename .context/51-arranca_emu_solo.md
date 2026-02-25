Como lo pusiste en pantalla independiente?                                                                                                                                                                                                                                    
● Corrí el emulator.exe directamente desde terminal — cuando lo hacés así (sin pasar por Android Studio) abre como ventana independiente automáticamente.                                                                                                                                                                                                                                                                                                             
Si lo querés siempre así, el comando completo que funcionó es:                                                                                                                                                                                     
~/AppData/Local/Android/Sdk/emulator/emulator.exe \                                                                                                                                                                              
-avd Pixel_3a_2 \
-wipe-data \
-no-snapshot-load \
-no-snapshot-save \
-gpu swiftshader_indirect

Para el día a día (sin wipe, solo arranque rápido):
~/AppData/Local/Android/Sdk/emulator/emulator.exe -avd Pixel_3a_2 -no-snapshot-load -gpu swiftshader_indirect

¿Querés que guarde esto en algún script .bat para no tener que escribirlo cada vez?
