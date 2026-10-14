package com.authenticator.service;

import com.authenticator.domain.BlockchainAuditLog;
import com.authenticator.domain.OAuthAuditLog;
import com.authenticator.domain.OAuthIssuedToken;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.repository.OAuthIssuedTokenRepository;
import com.authenticator.security.ExportSigningKeyManager;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.*;

/**
 * Servicio de Exportación Forense Certificada y Cifrada (CU-0048).
 * Consolida eventos de blockchain, autorizaciones OAuth y consultas de auditoría.
 *
 * Seguridad y Privacidad:
 * - Cifrado autenticado AES-256-GCM con IV aleatorio de 12 bytes por exportación.
 * - Metadatos inyectados como AAD (Additional Authenticated Data) para evitar adulteración de cabeceras.
 * - Validación estricta al inicio de que la clave AES decodificada tenga exactamente 32 bytes (256 bits).
 * - Certificación de integridad mediante SHA-256 y firma digital RSA dedicada (RS256).
 */
@Service
public class ForensicAuditService {

    private static final Logger log = LoggerFactory.getLogger(ForensicAuditService.class);

    private final BlockchainAuditLogRepository blockchainRepo;
    private final OAuthAuditLogRepository oauthAuditRepo;
    private final OAuthIssuedTokenRepository issuedTokenRepo;
    private final ExportSigningKeyManager exportSigningKeyManager;
    private final ObjectMapper objectMapper;

    @Value("${app.forensic.aes-key:${FORENSIC_AES_KEY:MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}}")
    private String configuredAesKeyBase64;

    @Value("${app.forensic.enc-kid:sip-forensic-aes-v1}")
    private String encKid;

    private SecretKeySpec aesKey;

    public ForensicAuditService(BlockchainAuditLogRepository blockchainRepo,
                                OAuthAuditLogRepository oauthAuditRepo,
                                OAuthIssuedTokenRepository issuedTokenRepo,
                                ExportSigningKeyManager exportSigningKeyManager,
                                ObjectMapper objectMapper) {
        this.blockchainRepo = blockchainRepo;
        this.oauthAuditRepo = oauthAuditRepo;
        this.issuedTokenRepo = issuedTokenRepo;
        this.exportSigningKeyManager = exportSigningKeyManager;
        this.objectMapper = objectMapper;
    }

    @PostConstruct
    public void init() {
        if (configuredAesKeyBase64 == null || configuredAesKeyBase64.isBlank()) {
            throw new IllegalStateException("La clave AES de auditoría forense (app.forensic.aes-key / FORENSIC_AES_KEY) es obligatoria.");
        }
        byte[] decodedKey;
        try {
            decodedKey = Base64.getDecoder().decode(configuredAesKeyBase64.trim());
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("La clave AES forense debe ser una cadena Base64 válida", e);
        }
        if (decodedKey.length != 32) {
            throw new IllegalStateException("Clave AES forense inválida: debe tener exactamente 32 bytes (256 bits). Longitud actual: " + decodedKey.length);
        }
        this.aesKey = new SecretKeySpec(decodedKey, "AES");
        log.info("Clave AES-256 forense validada exitosamente con enc_kid='{}' (32 bytes).", encKid);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> generateForensicExport() {
        List<BlockchainAuditLog> blockchainLogs = blockchainRepo.findAll();
        List<OAuthAuditLog> oauthLogs = oauthAuditRepo.findAll();
        List<OAuthIssuedToken> issuedTokens = issuedTokenRepo.findAll();

        Map<String, Object> plaintextPayload = new LinkedHashMap<>();
        plaintextPayload.put("totalBlockchainRecords", blockchainLogs.size());
        plaintextPayload.put("totalOAuthAuditRecords", oauthLogs.size());
        plaintextPayload.put("totalIssuedTokens", issuedTokens.size());
        plaintextPayload.put("blockchainRecords", blockchainLogs);
        plaintextPayload.put("oauthAuditLogs", oauthLogs);
        plaintextPayload.put("issuedTokens", issuedTokens);

        String plaintextJson;
        try {
            plaintextJson = objectMapper.writeValueAsString(plaintextPayload);
        } catch (Exception e) {
            throw new RuntimeException("Error serializando datos forenses a JSON", e);
        }

        // Generar IV aleatorio de 12 bytes por exportación
        byte[] iv = new byte[12];
        new SecureRandom().nextBytes(iv);
        String ivBase64 = Base64.getEncoder().encodeToString(iv);

        String exportId = UUID.randomUUID().toString();
        String generatedAt = LocalDateTime.now().toString();

        Map<String, Object> metadata = new LinkedHashMap<>();
        metadata.put("exportId", exportId);
        metadata.put("generatedAt", generatedAt);
        metadata.put("enc_kid", encKid);
        metadata.put("algorithm", "AES-256-GCM");
        metadata.put("tagLength", 128);
        metadata.put("iv", ivBase64);

        String metadataJson;
        try {
            metadataJson = objectMapper.writeValueAsString(metadata);
        } catch (Exception e) {
            throw new RuntimeException("Error serializando metadatos forenses", e);
        }

        // Cifrado AES-256-GCM con metadatos como AAD
        String ciphertextBase64;
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, aesKey, new GCMParameterSpec(128, iv));
            cipher.updateAAD(metadataJson.getBytes(StandardCharsets.UTF_8));
            byte[] ciphertextWithTag = cipher.doFinal(plaintextJson.getBytes(StandardCharsets.UTF_8));
            ciphertextBase64 = Base64.getEncoder().encodeToString(ciphertextWithTag);
        } catch (Exception e) {
            log.error("Error cifrando reporte forense con AES-256-GCM: {}", e.getMessage());
            throw new RuntimeException("Error en cifrado AES-256-GCM de exportación forense", e);
        }

        // Firma digital RSA dedicada sobre metadatos concatenados con ciphertext
        String dataToSign = metadataJson + "." + ciphertextBase64;
        String integrityHash = computeSha256Hex(dataToSign);
        String signature = exportSigningKeyManager.sign(dataToSign);

        Map<String, Object> finalExport = new LinkedHashMap<>();
        finalExport.put("exportId", exportId);
        finalExport.put("generatedAt", generatedAt);
        finalExport.put("enc_kid", encKid);
        finalExport.put("algorithm", "AES-256-GCM");
        finalExport.put("iv", ivBase64);
        finalExport.put("metadata", metadata);
        finalExport.put("ciphertext", ciphertextBase64);
        finalExport.put("integrityHashSha256", integrityHash);
        finalExport.put("signature", signature);
        finalExport.put("signingAlgorithm", "SHA256withRSA");
        finalExport.put("keyId", exportSigningKeyManager.getPrimaryKeyId());

        return finalExport;
    }

    /**
     * Descifra y verifica la integridad del bundle forense.
     * Falla si la firma RSA no coincide, si el hash de integridad difiere o si 1 byte del ciphertext o metadata fue alterado.
     */
    public String decryptAndVerify(Map<String, Object> exportBundle) throws Exception {
        Object metaObj = exportBundle.get("metadata");
        String metadataJson = objectMapper.writeValueAsString(metaObj);
        String ciphertextBase64 = (String) exportBundle.get("ciphertext");
        String signature = (String) exportBundle.get("signature");
        String keyId = (String) exportBundle.get("keyId");
        String integrityHash = (String) exportBundle.get("integrityHashSha256");

        String dataToVerify = metadataJson + "." + ciphertextBase64;

        if (!computeSha256Hex(dataToVerify).equals(integrityHash)) {
            throw new SecurityException("Hash de integridad SHA-256 no coincide con los datos del paquete");
        }

        if (!exportSigningKeyManager.verify(dataToVerify, signature, keyId)) {
            throw new SecurityException("Firma digital RSA del reporte forense inválida");
        }

        Map<?, ?> metaMap = (Map<?, ?>) metaObj;
        String ivBase64 = (String) metaMap.get("iv");
        byte[] iv = Base64.getDecoder().decode(ivBase64);
        byte[] ciphertext = Base64.getDecoder().decode(ciphertextBase64);

        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, aesKey, new GCMParameterSpec(128, iv));
        cipher.updateAAD(metadataJson.getBytes(StandardCharsets.UTF_8));
        byte[] decryptedBytes = cipher.doFinal(ciphertext);
        return new String(decryptedBytes, StandardCharsets.UTF_8);
    }

    private String computeSha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Error calculando hash SHA-256", e);
        }
    }
}
