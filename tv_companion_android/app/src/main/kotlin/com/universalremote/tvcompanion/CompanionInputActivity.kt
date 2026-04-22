package com.universalremote.tvcompanion

import android.app.Activity
import android.os.Bundle

class CompanionInputActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startService(android.content.Intent(this, CompanionInputService::class.java))
    }
}
