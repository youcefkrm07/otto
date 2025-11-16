package com.browser.flut

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.browser.flut/pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPictureInPicture" -> {
                    enterPictureInPictureMode(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun enterPictureInPictureMode(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val aspectRatio = Rational(16, 9)
            val pipParams = PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
                .build()
            try {
                enterPictureInPictureMode(pipParams)
                result.success(true)
            } catch (e: IllegalStateException) {
                result.error("PIP_ERROR", "Cannot enter PIP mode: ${e.message}", null)
            }
        } else {
            result.error("PIP_ERROR", "Picture-in-Picture requires Android 8.0 or higher", null)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Optionally enter PiP when user presses home button
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // This will be handled by Flutter side when needed
        }
    }
}
