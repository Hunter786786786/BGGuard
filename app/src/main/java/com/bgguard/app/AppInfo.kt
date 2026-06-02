package com.bgguard.app

import android.graphics.drawable.Drawable

data class AppInfo(
    val label: String,
    val packageName: String,
    val icon: Drawable?,
    var whitelisted: Boolean = false,
    val isSystem: Boolean = false
)
