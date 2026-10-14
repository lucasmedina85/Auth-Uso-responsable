package com.example.flutter_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import java.io.File
import java.util.Locale

class EmulatorDetector(private val context: Context) {

    data class DetectionResult(
        val isEmulator: Boolean,
        val score: Double,
        val reasons: List<String>
    )

    fun checkEmulator(): DetectionResult {
        val reasons = mutableListOf<String>()
        var score = 0.0

        // 1. Check Build Properties
        val buildReasons = checkBuildProperties()
        if (buildReasons.isNotEmpty()) {
            reasons.addAll(buildReasons)
            score += 0.5
        }

        // 2. Check Emulator Specific Files
        val fileReasons = checkEmulatorFiles()
        if (fileReasons.isNotEmpty()) {
            reasons.addAll(fileReasons)
            score += 0.4
        }

        // 3. Check System Properties
        val propReasons = checkSystemProperties()
        if (propReasons.isNotEmpty()) {
            reasons.addAll(propReasons)
            score += 0.3
        }

        // 4. Check Sensors
        val sensorReasons = checkSensors()
        if (sensorReasons.isNotEmpty()) {
            reasons.addAll(sensorReasons)
            score += 0.2
        }

        val normalizedScore = score.coerceAtMost(1.0)
        // If score exceeds 0.4 or high-confidence reasons detected, mark as emulator
        val isEmulator = normalizedScore >= 0.4 || reasons.any { 
            it.contains("QEMU_PIPE") || it.contains("NOX") || it.contains("BLUESTACKS") || it.contains("GENYMOTION") 
        }

        return DetectionResult(
            isEmulator = isEmulator,
            score = normalizedScore,
            reasons = reasons
        )
    }

    private fun checkBuildProperties(): List<String> {
        val reasons = mutableListOf<String>()
        val fingerprint = Build.FINGERPRINT.lowercase(Locale.ROOT)
        val model = Build.MODEL.lowercase(Locale.ROOT)
        val manufacturer = Build.MANUFACTURER.lowercase(Locale.ROOT)
        val hardware = Build.HARDWARE.lowercase(Locale.ROOT)
        val product = Build.PRODUCT.lowercase(Locale.ROOT)
        val board = Build.BOARD.lowercase(Locale.ROOT)
        val brand = Build.BRAND.lowercase(Locale.ROOT)
        val device = Build.DEVICE.lowercase(Locale.ROOT)

        if (fingerprint.startsWith("generic") || fingerprint.startsWith("unknown") ||
            fingerprint.contains("google_sdk") || fingerprint.contains("emulator") ||
            fingerprint.contains("android sdk built for x86") || fingerprint.contains("vbox86p")) {
            reasons.add("BUILD_FINGERPRINT: $fingerprint")
        }

        if (model.contains("google_sdk") || model.contains("emulator") ||
            model.contains("android sdk built for x86") || model.contains("sdk_gphone") ||
            model.contains("vbox86p") || model.contains("nox") || model.contains("bluestacks") ||
            model.contains("droid4x") || model.contains("tiantianvm")) {
            reasons.add("BUILD_MODEL: $model")
        }

        if (manufacturer.contains("genymotion") || manufacturer.contains("bignox") ||
            manufacturer.contains("nox") || manufacturer.contains("bluestacks") ||
            (manufacturer.contains("google") && model.startsWith("sdk_"))) {
            reasons.add("BUILD_MANUFACTURER: $manufacturer")
        }

        if (hardware.contains("goldfish") || hardware.contains("ranchu") ||
            hardware.contains("vbox86") || hardware.contains("nox") || hardware.contains("ttvm_x86")) {
            reasons.add("BUILD_HARDWARE: $hardware")
        }

        if (product.contains("sdk") || product.contains("google_sdk") ||
            product.contains("sdk_gphone") || product.contains("vbox86p") ||
            product.contains("nox") || product.contains("bluestacks")) {
            reasons.add("BUILD_PRODUCT: $product")
        }

        if (board.contains("goldfish") || board.contains("ranchu")) {
            reasons.add("BUILD_BOARD: $board")
        }

        if (brand.startsWith("generic") && device.startsWith("generic")) {
            reasons.add("BUILD_GENERIC_BRAND_AND_DEVICE")
        }

        return reasons
    }

    private fun checkEmulatorFiles(): List<String> {
        val reasons = mutableListOf<String>()
        val knownFiles = listOf(
            "/dev/socket/qemud",
            "/dev/qemu_pipe",
            "/system/lib/libc_malloc_debug_qemu.so",
            "/sys/qemu_trace",
            "/system/bin/nox-prop",
            "/system/bin/nox",
            "/data/data/com.bluestacks.home",
            "/data/data/com.bignox.app",
            "/dev/vboxguest",
            "/dev/vboxuser",
            "/system/etc/init.nox.rc"
        )

        for (filePath in knownFiles) {
            try {
                val file = File(filePath)
                if (file.exists()) {
                    reasons.add("EMULATOR_FILE_FOUND: $filePath")
                }
            } catch (_: Exception) {
                // Ignore file system permissions
            }
        }
        return reasons
    }

    private fun checkSystemProperties(): List<String> {
        val reasons = mutableListOf<String>()
        val propertiesToCheck = listOf(
            "ro.kernel.qemu",
            "ro.hardware",
            "qemu.hw.mainkeys",
            "ro.bootloader",
            "init.svc.qemud"
        )

        try {
            val systemPropertiesClass = Class.forName("android.os.SystemProperties")
            val getMethod = systemPropertiesClass.getMethod("get", String::class.java)

            for (prop in propertiesToCheck) {
                val value = getMethod.invoke(null, prop) as? String
                if (!value.isNullOrEmpty()) {
                    if (prop == "ro.kernel.qemu" && value == "1") {
                        reasons.add("PROP_QEMU: $prop=$value")
                    } else if (prop == "ro.hardware" && (value.contains("goldfish") || value.contains("ranchu"))) {
                        reasons.add("PROP_HARDWARE_EMULATOR: $prop=$value")
                    } else if (prop == "init.svc.qemud") {
                        reasons.add("PROP_QEMUD_SERVICE: $prop=$value")
                    }
                }
            }
        } catch (_: Exception) {
            // Reflection or property permission restricted
        }
        return reasons
    }

    private fun checkSensors(): List<String> {
        val reasons = mutableListOf<String>()
        try {
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            if (sensorManager != null) {
                val allSensors = sensorManager.getSensorList(Sensor.TYPE_ALL)
                if (allSensors.isEmpty()) {
                    reasons.add("NO_SENSORS_AVAILABLE")
                }
                val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                if (accelerometer == null) {
                    reasons.add("NO_ACCELEROMETER_SENSOR")
                }
            }
        } catch (_: Exception) {
            // Ignore sensor manager errors
        }
        return reasons
    }
}
