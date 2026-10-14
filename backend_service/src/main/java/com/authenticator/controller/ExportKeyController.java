package com.authenticator.controller;

import com.authenticator.security.ExportSigningKeyManager;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Publica exclusivamente las claves públicas RSA dedicadas a la verificación de exportaciones forenses.
 * Estrictamente separado de /.well-known/jwks.json (que publica tokens de clientes OAuth).
 */
@RestController
public class ExportKeyController {

    private final ExportSigningKeyManager exportSigningKeyManager;

    public ExportKeyController(ExportSigningKeyManager exportSigningKeyManager) {
        this.exportSigningKeyManager = exportSigningKeyManager;
    }

    @GetMapping(value = "/.well-known/export-keys.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> getExportKeys() {
        return ResponseEntity.ok(exportSigningKeyManager.getExportJwks());
    }
}
