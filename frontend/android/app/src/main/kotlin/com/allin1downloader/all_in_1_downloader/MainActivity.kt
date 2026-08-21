package com.allin1downloader.all_in_1_downloader

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "all_in_1_downloader/overlay"
    private var channel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val runCommandPermission = "com.termux.permission.RUN_COMMAND"
    private val runCommandRequestCode = 4821

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        OverlayService.methodChannel = channel

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(granted)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "showBubble" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    if (hasPermission) {
                        val intent = Intent(this, OverlayService::class.java)
                        intent.action = OverlayService.ACTION_SHOW
                        startService(intent)
                    }
                    result.success(null)
                }
                "hideBubble" -> {
                    val intent = Intent(this, OverlayService::class.java)
                    intent.action = OverlayService.ACTION_HIDE
                    startService(intent)
                    result.success(null)
                }
                "isTermuxInstalled" -> {
                    val installed = try {
                        packageManager.getPackageInfo("com.termux", 0)
                        true
                    } catch (e: PackageManager.NameNotFoundException) {
                        false
                    }
                    result.success(installed)
                }
                "openTermux" -> {
                    val launchIntent = packageManager.getLaunchIntentForPackage("com.termux")
                    if (launchIntent != null) {
                        startActivity(launchIntent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "hasRunCommandPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        runCommandPermission
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestRunCommandPermission" -> {
                    val alreadyGranted = ContextCompat.checkSelfPermission(
                        this,
                        runCommandPermission
                    ) == PackageManager.PERMISSION_GRANTED
                    if (alreadyGranted) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(runCommandPermission),
                            runCommandRequestCode
                        )
                    }
                }
                "runTermuxCommand" -> {
                    try {
                        val command = call.argument<String>("command")
                        if (command.isNullOrBlank()) {
                            result.error("BAD_ARGS", "No command provided", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent()
                        intent.setClassName("com.termux", "com.termux.app.RunCommandService")
                        intent.action = "com.termux.RUN_COMMAND"
                        intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
                        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", command))
                        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TERMUX_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == runCommandRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onDestroy() {
        OverlayService.methodChannel = null
        super.onDestroy()
    }
}