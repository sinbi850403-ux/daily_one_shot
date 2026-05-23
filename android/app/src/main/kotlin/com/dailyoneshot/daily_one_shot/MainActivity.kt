package com.dailyoneshot.daily_one_shot

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val importChannel = "com.dailyoneshot/file_import"
    private val shareChannel = "com.dailyoneshot/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Import channel ────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            importChannel
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSharedFilePath") {
                result.success(resolveIncomingUri())
            } else {
                result.notImplemented()
            }
        }

        // ── Share channel ─────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    val mime = call.argument<String>("mimeType") ?: "*/*"
                    shareFile(path, text, mime)
                    result.success(null)
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(intent, "공유"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun shareFile(path: String, text: String, mimeType: String) {
        try {
            val file = File(path)
            val uri: Uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                if (text.isNotBlank()) putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "공유"))
        } catch (e: Exception) {
            // FileProvider not configured or other error — show toast
            e.printStackTrace()
        }
    }

    private fun resolveIncomingUri(): String? {
        val uri: Uri? = intent?.data
            ?: @Suppress("DEPRECATION") intent?.getParcelableExtra(Intent.EXTRA_STREAM)
        if (uri == null) return null
        return try {
            val tmpFile = File(cacheDir, "import_backup.zip")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(tmpFile).use { output -> input.copyTo(output) }
            }
            tmpFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
