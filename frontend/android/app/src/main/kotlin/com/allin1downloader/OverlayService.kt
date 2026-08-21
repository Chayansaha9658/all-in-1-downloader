package com.allin1downloader.all_in_1_downloader

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import io.flutter.plugin.common.MethodChannel

/**
 * Draws a small always-on-top circular bubble using WindowManager, outside
 * of the Flutter view hierarchy. Tapping it notifies Dart via MethodChannel
 * so the app can come to the foreground and fill in the detected link.
 */
class OverlayService : Service() {

    companion object {
        const val ACTION_SHOW = "show"
        const val ACTION_HIDE = "hide"
        var methodChannel: MethodChannel? = null
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> showBubble()
            ACTION_HIDE -> removeBubble()
        }
        return START_NOT_STICKY
    }

    private fun showBubble() {
        if (bubbleView != null) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val bubble = ImageView(this)
        bubble.setImageResource(android.R.drawable.stat_sys_download)
        bubble.setBackgroundColor(0xFF7F5AF0.toInt())
        bubble.setPadding(24, 24, 24, 24)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 300

        var initialX = 0
        var initialY = 0
        var touchX = 0f
        var touchY = 0f
        var isDrag = false

        bubble.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    isDrag = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (Math.abs(dx) > 12 || Math.abs(dy) > 12) isDrag = true
                    params.x = initialX + dx
                    params.y = initialY + dy
                    windowManager?.updateViewLayout(bubble, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDrag) {
                        methodChannel?.invokeMethod("bubbleTapped", null)
                        removeBubble()
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        launchIntent?.let { startActivity(it) }
                    }
                    true
                }
                else -> false
            }
        }

        windowManager?.addView(bubble, params)
        bubbleView = bubble
    }

    private fun removeBubble() {
        bubbleView?.let {
            windowManager?.removeView(it)
            bubbleView = null
        }
        stopSelf()
    }

    override fun onDestroy() {
        removeBubble()
        super.onDestroy()
    }
}