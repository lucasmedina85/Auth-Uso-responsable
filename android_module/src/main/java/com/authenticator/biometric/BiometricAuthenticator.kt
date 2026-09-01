package com.authenticator.biometric

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * Kotlin Manager for CU-0017 (Inicialización de Lector de Huella Dactilar)
 * and CU-0018 (Captura de Huella Dactilar Local).
 *
 * Invokes native AndroidX BiometricPrompt API with system dialogs.
 */
class BiometricAuthenticator(private val activity: FragmentActivity) {

    sealed class BiometricStatus {
        object Ready : BiometricStatus()
        data class ErrorHardware(val message: String) : BiometricStatus()
        object NotEnrolled : BiometricStatus()
    }

    /**
     * Check if hardware fingerprint / biometric sensor is available on device
     */
    fun checkBiometricAvailability(): BiometricStatus {
        val biometricManager = BiometricManager.from(activity)
        return when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK)) {
            BiometricManager.BIOMETRIC_SUCCESS -> BiometricStatus.Ready
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> BiometricStatus.ErrorHardware("El dispositivo no posee sensor biométrico.")
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> BiometricStatus.ErrorHardware("Sensor biométrico no disponible temporalmente.")
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> BiometricStatus.NotEnrolled
            else -> BiometricStatus.ErrorHardware("Error al verificar estado biométrico.")
        }
    }

    /**
     * CU-0017: Invokes native BiometricPrompt dialog for fingerprint capture (CU-0018)
     */
    fun showBiometricPrompt(
        title: String = "Autenticación de Huella Dactilar",
        subtitle: String = "Authenticator | Juego Responsable",
        description: String = "Apoye su dedo registrado sobre el lector biométrico del dispositivo",
        onSuccess: (result: BiometricPrompt.AuthenticationResult) -> Unit,
        onError: (errorCode: Int, errString: CharSequence) -> Unit,
        onFailed: () -> Unit
    ) {
        val executor = ContextCompat.getMainExecutor(activity)

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                onSuccess(result)
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                onError(errorCode, errString)
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                onFailed()
            }
        }

        val biometricPrompt = BiometricPrompt(activity, executor, callback)

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setDescription(description)
            .setNegativeButtonText("Cancelar")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK)
            .build()

        biometricPrompt.authenticate(promptInfo)
    }
}
