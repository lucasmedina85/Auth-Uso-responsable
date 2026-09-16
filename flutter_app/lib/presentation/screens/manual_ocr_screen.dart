import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/ocr_processor.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';

/// Flutter implementation of CU-0042: Formulario Visual de Procesamiento Manual de OCR Fallido.
class ManualOcrScreenFlutter extends StatefulWidget {
  final Function(String dni, String tramit, String imagePath) onSubmit;
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
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _addressController = TextEditingController();
  
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final _ocrProcessor = OcrProcessor();
  bool _isProcessingOcr = false;

  @override
  void dispose() {
    _dniController.dispose();
    _tramitController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _addressController.dispose();
    _ocrProcessor.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _isProcessingOcr = true;
        });
        
        // Autocompletar form procesando la imagen
        final data = await _ocrProcessor.processBackImage(image.path);
        
        if (mounted) {
          setState(() {
            _isProcessingOcr = false;
            if (data != null) {
              _dniController.text = data.documentNumber;
              _nameController.text = data.firstName;
              _surnameController.text = data.lastName;
              _genderController.text = data.gender;
              _dobController.text = DateFormat('dd/MM/yyyy').format(data.birthDate);
              if (data.tramitNumber != null) {
                _tramitController.text = data.tramitNumber!;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Datos extraídos de la imagen exitosamente.')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No se detectó un formato válido en la imagen. Por favor, complete manualmente.')),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si la cámara no pudo leer el código PDF417 o el número de trámite debido a desgaste o reflejos, ingrese sus datos a continuación (CU-0042).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 28),

                // Card Container (8px radius, elevation)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // DNI Field
                        TextFormField(
                          controller: _dniController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 8,
                          decoration: const InputDecoration(
                            labelText: 'Número de DNI (7 u 8 dígitos)',
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
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombres',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _surnameController,
                          decoration: const InputDecoration(
                            labelText: 'Apellidos',
                            prefixIcon: Icon(Icons.people_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _dobController,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de Nacimiento (DD/MM/YYYY)',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _genderController,
                          maxLength: 1,
                          decoration: const InputDecoration(
                            labelText: 'Sexo (M/F/X)',
                            prefixIcon: Icon(Icons.wc),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Domicilio / Lugar de Nacimiento',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Image Upload Field
                        Text(
                          'Evidencia Física (Obligatorio)',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Cámara'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.image),
                                label: const Text('Galería'),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.validationGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Imagen seleccionada: \${_selectedImage!.name}',
                                    style: const TextStyle(color: AppColors.validationGreen, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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
                        if (_selectedImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Debe adjuntar la foto del DNI obligatoriamente.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        widget.onSubmit(
                          _dniController.text.trim(),
                          _tramitController.text.trim(),
                          _selectedImage!.path,
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
                      color: Theme.of(context).textTheme.bodyLarge?.color,
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
