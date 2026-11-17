package com.dusk.scripturetrivia

import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Passed to main() before the first frame. A platform channel would still
    // be in flight when that frame is painted.
    override fun getDartEntrypointArgs(): List<String> {
        return listOf(Build.VERSION.SDK_INT.toString())
    }
}
