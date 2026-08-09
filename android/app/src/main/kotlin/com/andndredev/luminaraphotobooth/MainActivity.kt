package com.andndredev.luminaraphotobooth

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    // Satu-satunya alasan kelas ini tidak lagi kosong: memasang APK butuh
    // Intent dengan content:// URI, dan tidak ada API Dart yang bisa
    // membuatnya. file:// sudah dilarang sejak Android 7 — melemparkannya ke
    // aplikasi lain melempar FileUriExposedException.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "luminara/update")
            .setMethodCallHandler { call, result ->
                if (call.method != "install") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("no_path", "Jalur berkas kosong", null)
                    return@setMethodCallHandler
                }

                try {
                    val uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.updates",
                        File(path)
                    )
                    startActivity(
                        Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                            )
                        }
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("install_failed", e.message, null)
                }
            }
    }
}
