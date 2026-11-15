package com.dusk.saintstrivia.saints_trivia_flutter

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "saints_trivia/splash")
            .setMethodCallHandler { call, result ->
                if (call.method == "sdkInt") {
                    result.success(Build.VERSION.SDK_INT)
                } else {
                    result.notImplemented()
                }
            }
    }
}
