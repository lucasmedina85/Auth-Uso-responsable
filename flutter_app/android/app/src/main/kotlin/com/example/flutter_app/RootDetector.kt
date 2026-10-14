package com.example.flutter_app

import android.content.Context
import android.os.Build
import java.io.File

/**
 * Detector de Root / Jailbreak (CU-0033).
 * Inspecciona binarios de superusuario, paths del sistema, tags de compilación y permisos.
 */
class RootDetector(private val context: Context) {

    data class DetectionResult(
        val isRooted: Boolean,
        val reasons: List<String>
    )

    fun checkRoot(): DetectionResult {
        val reasons = mutableListOf<String>()

        // 1. Verificación de binarios conocidos de superusuario
        val suPaths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su",
            "/sbin/magisk",
            "/system/xbin/daemonsu"
        )

        for (path in suPaths) {
            try {
                if (File(path).exists()) {
                    reasons.add("ROOT_BINARY_FOUND: $path")
                }
            } catch (_: Exception) {
                // Ignorar excepciones de permisos
            }
        }

        // 2. Verificación de test-keys en Build.TAGS
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            reasons.add("TEST_KEYS_FOUND: $buildTags")
        }

        // 3. Verificación de comandos su en el PATH
        if (canExecuteSu()) {
            reasons.add("SU_EXECUTION_POSSIBLE")
        }

        val isRooted = reasons.isNotEmpty()
        return DetectionResult(
            isRooted = isRooted,
            reasons = reasons
        )
    }

    private fun canExecuteSu(): Boolean {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val exitCode = process.waitFor()
            exitCode == 0
        } catch (_: Exception) {
            false
        } finally {
            process?.destroy()
        }
    }
}
