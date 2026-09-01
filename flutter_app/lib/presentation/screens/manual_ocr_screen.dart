import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Flutter implementation of CU-0042: Formulario Visual de Procesamiento Manual de OCR Fallido.
class ManualOcrScreenFlutter extends StatefulWidget {
  final Function(String dni, String tramit) onSubmit;
  final VoidCallback onCancel;

  const ManualOcrScreenFlutter({
    super.key,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<ManualOcrScreenFlutter> createState() => _ManualOcrScreenFlutterState();
}

class _ManualOcrScreenFlutterState extends State<ManualOcrScreenFlutter> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _tramitController = TextEditingController();

  @override
  void dispose() {
    _dniController.dispose();
    _tramitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutralLightGray,
      appBar: AppBar(
        title: Text(
          'Ingreso Manual de DNI',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.edit_document,
                  size: 60,
                  color: AppColors.industrialBlue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Formulario Manual por OCR Fallido',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepGraphite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si la cámara no pudo leer el código PDF417 o el número de trámite debido a desgaste o reflejos, ingrese sus datos a continuación (CU-0042).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: AppColors.deepGraphite,
                  ),
                ),
                const SizedBox(height: 28),

                // Card Container (8px radius, elevation)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // DNI Field
                        TextFormField(
                          controller: _dniController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 8,
                          decoration: const InputDecoration(
                            labelText: 'Número de DNI (7u 8 dígitos)',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 7 || value.length > 8) {
                              return 'Ingrese entre 7 y 8 dígitos válidos.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Tramit Field
                        TextFormField(
                          controller: _tramitController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 11,
                          decoration: const InputDecoration(
                            labelText: 'Número de Trámite (11 dígitos)',
                            prefixIcon: Icon(Icons.tag_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.length != 11) {
                              return 'El número de trámite consta de 11 dígitos.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button (Industrial Blue #0288D1)
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSubmit(
                          _dniController.text.trim(),
                          _tramitController.text.trim(),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    label: Text(
                      'VALIDAR DATOS MANUALES',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'CANCELAR Y REINTENTAR CAPTURA',
                    style: GoogleFonts.montserrat(
                      color: AppColors.deepGraphite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
