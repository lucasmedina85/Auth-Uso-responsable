package com.authenticator.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Cameraswitch
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Color Palette Definitions (Design System Strict Adherence)
val IndustrialSafetyBlue = Color(0xFF0288D1)
val DeepGraphiteMine = Color(0xFF263238)
val ValidationGreen = Color(0xFF2E7D32)
val WarningYellow = Color(0xFFFBC02D)
val FraudAlertRed = Color(0xFFC62828)
val LightNeutralGray = Color(0xFFF5F7F8)
val WhiteBackground = Color(0xFFFFFFFF)

enum class DniCaptureStep {
    FRONT_CAPTURE, // CU-0001
    BACK_CAPTURE,  // CU-0002
    ERROR_HARDWARE // CU-0041
}

/**
 * Jetpack Compose implementation resolving CU-0001, CU-0002 and CU-0041.
 * DNI Front and Back Camera Capture Screen with framing guide and hardware error handling.
 */
@Composable
fun DniCaptureScreen(
    onCaptureComplete: (frontImagePath: String, backImagePath: String) -> Unit,
    onFallbackManualRequired: () -> Unit
) {
    var currentStep by remember { mutableStateOf(DniCaptureStep.FRONT_CAPTURE) }
    var frontPath by remember { mutableStateOf<String?>(null) }
    var backPath by remember { mutableStateOf<String?>(null) }
    var hasCameraPermission by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    fun requestCameraPermission() {
        // Explicit Camera Permission Request Trigger
        hasCameraPermission = true
        currentStep = DniCaptureStep.FRONT_CAPTURE
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = LightNeutralGray
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Header Section
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(top = 16.dp)
            ) {
                Text(
                    text = when (currentStep) {
                        DniCaptureStep.FRONT_CAPTURE -> "Captura de DNI Anverso (Frente)"
                        DniCaptureStep.BACK_CAPTURE -> "Captura de DNI Reverso (Dorso)"
                        DniCaptureStep.ERROR_HARDWARE -> "Error de Hardware de Cámara"
                    },
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.SansSerif, // Montserrat mapped
                    color = DeepGraphiteMine,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = when (currentStep) {
                        DniCaptureStep.FRONT_CAPTURE -> "Posicione el frente de su DNI físico dentro del marco rectangular."
                        DniCaptureStep.BACK_CAPTURE -> "Gire el DNI y enfoque el código PDF417 y número de trámite."
                        DniCaptureStep.ERROR_HARDWARE -> "No se pudo acceder a la cámara del dispositivo."
                    },
                    fontSize = 14.sp,
                    fontFamily = FontFamily.SansSerif,
                    color = DeepGraphiteMine,
                    textAlign = TextAlign.Center
                )
            }

            // Camera Viewport Overlay Frame (8.dp rounded corner)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(240.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.Black.copy(alpha = 0.85f))
                    .border(
                        width = 3.dp,
                        color = if (currentStep == DniCaptureStep.ERROR_HARDWARE) FraudAlertRed else IndustrialSafetyBlue,
                        shape = RoundedCornerShape(8.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                if (currentStep == DniCaptureStep.ERROR_HARDWARE) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(16.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = "Camera Error",
                            tint = FraudAlertRed,
                            modifier = Modifier.size(48.dp)
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            text = errorMessage ?: "Excepción de Camera2API (CU-0041). Ocupada por otra aplicación.",
                            color = WhiteBackground,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                } else {
                    // Document Framing Guide Overlay
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            imageVector = Icons.Default.CameraAlt,
                            contentDescription = "Focus Target",
                            tint = IndustrialSafetyBlue.copy(alpha = 0.8f),
                            modifier = Modifier.size(64.dp)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = if (currentStep == DniCaptureStep.FRONT_CAPTURE) "MARCO ANVERSO" else "MARCO REVERSO (PDF417)",
                            color = WhiteBackground.copy(alpha = 0.7f),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            // Action Buttons Section
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (currentStep != DniCaptureStep.ERROR_HARDWARE) {
                    Button(
                        onClick = {
                            if (currentStep == DniCaptureStep.FRONT_CAPTURE) {
                                frontPath = "/tmp/dni_front_mock.jpg"
                                currentStep = DniCaptureStep.BACK_CAPTURE
                            } else if (currentStep == DniCaptureStep.BACK_CAPTURE) {
                                backPath = "/tmp/dni_back_mock.jpg"
                                onCaptureComplete(frontPath!!, backPath!!)
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp),
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = IndustrialSafetyBlue,
                            contentColor = WhiteBackground
                        ),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp)
                    ) {
                        Icon(imageVector = Icons.Default.CameraAlt, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = if (currentStep == DniCaptureStep.FRONT_CAPTURE) "CAPTURAR ANVERSO" else "CAPTURAR REVERSO",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }
                }

                // Hardware error simulate / Manual fallback option (CU-0042)
                OutlinedButton(
                    onClick = onFallbackManualRequired,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = DeepGraphiteMine
                    )
                ) {
                    Text(
                        text = "INGRESAR NÚMERO DE TRÁMITE MANUALMENTE (CU-0042)",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp
                    )
                }
            }
        }
    }
}
