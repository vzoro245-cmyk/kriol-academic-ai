package com.example.kriol_academic_ai

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "kriol/storage_permissions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "takePersistableUriPermission") {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    try {
                        val uri = Uri.parse(uriString)
                        val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        contentResolver.takePersistableUriPermission(uri, takeFlags)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SAF_ERROR", "Falha ao persistir permissão: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI nula", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
