package com.authenticator.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Jetpack Compose UI implementation of CU-0042: Procesamiento Manual de OCR Fallido.
 * Rendered when OCR reader fails repeatedly due to card plastic wear/tear.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OcrManualFallbackScreen(
    onSubmitManualData: (dniNumber: String, tramitNumber: String) -> Unit,
    onCancel: () -> Unit
) {
    var dniInput by remember { mutableStateOf("") }
    var tramitInput by remember { mutableStateOf("") }
    var isDniValid by remember { mutableStateOf(true) }
    var isTramitValid by remember { mutableStateOf(true) }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = LightNeutralGray
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header Info
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Default.Badge,
                    contentDescription = "Manual DNI Entry",
                    tint = IndustrialSafetyBlue,
                    modifier = Modifier.size(56.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Ingreso Manual de Número de Trámite",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.SansSerif,
                    color = DeepGraphiteMine,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Debido al desgaste del plástico o baja iluminación, ingrese manualmente los datos de su DNI para continuar la validación (CU-0042).",
                    fontSize = 13.sp,
                    fontFamily = FontFamily.SansSerif,
                    color = DeepGraphiteMine,
                    textAlign = TextAlign.Center
                )
            }

            // Input Form Card (8.dp rounded corners, elevation 2.dp)
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(8.dp),
                colors = CardDefaults.cardColors(containerColor = WhiteBackground),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // DNI Number Input
                    OutlinedTextField(
                        value = dniInput,
                        onValueChange = { input ->
                            if (input.length <= 8 && input.all { it.isDigit() }) {
                                dniInput = input
                                isDniValid = input.length in 7..8
                            }
                        },
                        label = { Text("Número de DNI (7 u 8 dígitos)") },
                        isError = !isDniValid,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(8.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = IndustrialSafetyBlue,
                            unfocusedBorderColor = Color(0xFFCFD8DC),
                            errorBorderColor = FraudAlertRed
                        )
                    )
                    if (!isDniValid) {
                        Text(
                            text = "El DNI debe contener entre 7 y 8 dígitos numéricos.",
                            color = FraudAlertRed,
                            fontSize = 11.sp
                        )
                    }

                    // Number of Tramit Input (11 digits format)
                    OutlinedTextField(
                        value = tramitInput,
                        onValueChange = { input ->
                            if (input.length <= 11 && input.all { it.isDigit() }) {
                                tramitInput = input
                                isTramitValid = input.length == 11
                            }
                        },
                        label = { Text("Número de Trámite (11 dígitos del frente/dorso)") },
                        isError = !isTramitValid,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(8.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = IndustrialSafetyBlue,
                            unfocusedBorderColor = Color(0xFFCFD8DC),
                            errorBorderColor = FraudAlertRed
                        )
                    )
                    if (!isTramitValid) {
                        Text(
                            text = "El número de trámite consta de exactamente 11 dígitos.",
                            color = FraudAlertRed,
                            fontSize = 11.sp
                        )
                    }
                }
            }

            // Bottom Buttons
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = {
                        if (dniInput.length in 7..8 && tramitInput.length == 11) {
                            onSubmitManualData(dniInput, tramitInput)
                        } else {
                            isDniValid = dniInput.length in 7..8
                            isTramitValid = tramitInput.length == 11
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
                    Icon(imageVector = Icons.Default.CheckCircle, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "CONFIRMAR DATOS MANUALES",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }

                TextButton(
                    onClick = onCancel,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "CANCELAR Y REINTENTAR CÁMARA",
                        color = DeepGraphiteMine,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 13.sp
                    )
                }
            }
        }
    }
}
