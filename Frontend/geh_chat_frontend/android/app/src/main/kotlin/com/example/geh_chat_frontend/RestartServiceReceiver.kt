package com.example.geh_chat_frontend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class RestartServiceReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("RestartServiceReceiver", "Received intent: ${intent.action}")
        Log.d("RestartServiceReceiver", "Background functionality disabled - service will not restart")
        
        // Background functionality removed - app closes completely when killed
        // No service restart, no auto-launch
    }
}
