package com.example.whiscord

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.whiscord/shortcuts"
    private var shortcutAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // インテントから起動アクションを取得
        val action = intent.getStringExtra("action")
        if (action != null) {
            shortcutAction = action
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getShortcutAction") {
                result.success(shortcutAction)
                // アクションを処理したらクリア
                shortcutAction = null
            } else {
                result.notImplemented()
            }
        }
    }
}
