package com.authenticator.controller;

import com.authenticator.service.ForensicAuditService;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Endpoint protegido para la Exportación Forense Certificada (CU-0048).
 * Accesible únicamente por roles ROLE_ADMIN y ROLE_AUDITOR.
 */
@RestController
@RequestMapping("/admin/forensics")
public class ForensicController {

    private final ForensicAuditService forensicAuditService;

    public ForensicController(ForensicAuditService forensicAuditService) {
        this.forensicAuditService = forensicAuditService;
    }

    @GetMapping(value = "/export", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> exportForensicReport() {
        Map<String, Object> report = forensicAuditService.generateForensicExport();
        return ResponseEntity.ok(report);
    }
}
