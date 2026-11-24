package com.example.website_webview_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.website_webview_app/permissions"
    private val PERMISSION_REQUEST_CODE = 1001
    private val FOLDER_PICKER_REQUEST_CODE = 1002

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingFolderPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAllPermissions" -> {
                    requestAllAppPermissions(result)
                }
                "checkPermissions" -> {
                    result.success(areAllPermissionsGranted())
                }
                "getDefaultStoragePath" -> {
                    val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                    if (!downloadDir.exists()) {
                        downloadDir.mkdirs()
                    }
                    result.success(downloadDir.absolutePath)
                }
                "pickFolder" -> {
                    openFolderPicker(result)
                }
                "appendToFile" -> {
                    val filePath = call.argument<String>("path")
                    val content = call.argument<String>("content")
                    if (filePath != null && content != null) {
                        try {
                            val file = File(filePath)
                            file.parentFile?.mkdirs()
                            FileOutputStream(file, true).use { output ->
                                output.write(content.toByteArray(Charsets.UTF_8))
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WRITE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Path or content is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openFolderPicker(result: MethodChannel.Result) {
        if (pendingFolderPickerResult != null) {
            result.error("BUSY", "Another picker request is active", null)
            return
        }
        pendingFolderPickerResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
            startActivityForResult(intent, FOLDER_PICKER_REQUEST_CODE)
        } catch (e: Exception) {
            pendingFolderPickerResult = null
            result.error("PICKER_ERROR", e.message, null)
        }
    }

    private fun getRequiredPermissions(): Array<String> {
        val permissions = mutableListOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
            permissions.add(Manifest.permission.READ_MEDIA_VIDEO)
            permissions.add(Manifest.permission.READ_MEDIA_AUDIO)
        } else {
            permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }

        return permissions.toTypedArray()
    }

    private fun areAllPermissionsGranted(): Boolean {
        for (perm in getRequiredPermissions()) {
            if (ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

    private fun requestAllAppPermissions(result: MethodChannel.Result) {
        val missingPermissions = mutableListOf<String>()
        for (perm in getRequiredPermissions()) {
            if (ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED) {
                missingPermissions.add(perm)
            }
        }

        if (missingPermissions.isEmpty()) {
            result.success(true)
        } else {
            pendingPermissionResult = result
            ActivityCompat.requestPermissions(
                this,
                missingPermissions.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            pendingPermissionResult?.success(areAllPermissionsGranted())
            pendingPermissionResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FOLDER_PICKER_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri: Uri? = data.data
                if (uri != null) {
                    try {
                        contentResolver.takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )
                    } catch (_: Exception) {}

                    // Convert tree URI to human-friendly display path or standard path
                    val path = uri.path ?: uri.toString()
                    val decoded = Uri.decode(path)
                    val resolvedPath = if (decoded.contains(":")) {
                        val parts = decoded.split(":")
                        val relative = parts.last()
                        "/storage/emulated/0/$relative"
                    } else {
                        decoded
                    }
                    pendingFolderPickerResult?.success(resolvedPath)
                } else {
                    pendingFolderPickerResult?.success(null)
                }
            } else {
                pendingFolderPickerResult?.success(null)
            }
            pendingFolderPickerResult = null
        }
    }
}
