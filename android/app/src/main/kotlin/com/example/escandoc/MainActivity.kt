package com.example.escandoc

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TEXT_DETECTOR_CHANNEL = "escandoc/text_detector"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registrar TextDetectorPlugin
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TEXT_DETECTOR_CHANNEL)
        TextDetectorPlugin(channel)
    }
}
