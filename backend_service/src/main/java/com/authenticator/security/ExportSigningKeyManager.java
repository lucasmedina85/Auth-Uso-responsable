package com.authenticator.security;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class ExportSigningKeyManager {

    private static final Logger log = LoggerFactory.getLogger(ExportSigningKeyManager.class);

    private final Environment environment;

    @Value("${app.export.rsa.key-id:sip-export-sig-v1}")
    private String primaryKeyId;

    @Value("${app.export.rsa.private-key:${EXPORT_RSA_PRIVATE_KEY:}}")
    private String configuredPrivateKeyPem;

    @Value("${app.export.rsa.public-key:${EXPORT_RSA_PUBLIC_KEY:}}")
    private String configuredPublicKeyPem;

    public static class ExportRsaKeyEntry {
        private final String kid;
        private final RSAPrivateKey privateKey;
        private final RSAPublicKey publicKey;

        public ExportRsaKeyEntry(String kid, RSAPrivateKey privateKey, RSAPublicKey publicKey) {
            this.kid = kid;
            this.privateKey = privateKey;
            this.publicKey = publicKey;
        }

        public String getKid() { return kid; }
        public RSAPrivateKey getPrivateKey() { return privateKey; }
        public RSAPublicKey getPublicKey() { return publicKey; }
    }

    private final Map<String, ExportRsaKeyEntry> keyStore = new ConcurrentHashMap<>();

    public ExportSigningKeyManager(Environment environment) {
        this.environment = environment;
    }

    @PostConstruct
    public void init() {
        boolean isProd = environment != null && Arrays.asList(environment.getActiveProfiles()).contains("prod");

        if (configuredPrivateKeyPem != null && !configuredPrivateKeyPem.isBlank() &&
            configuredPublicKeyPem != null && !configuredPublicKeyPem.isBlank()) {
            try {
                RSAPrivateKey privKey = parsePrivateKey(configuredPrivateKeyPem);
                RSAPublicKey pubKey = parsePublicKey(configuredPublicKeyPem);
                registerKey(primaryKeyId, privKey, pubKey);
                log.info("Clave RSA dedicada para exportaciones cargada exitosamente con kid='{}'", primaryKeyId);
                return;
            } catch (Exception e) {
                if (isProd) {
                    throw new IllegalStateException("Error al parsear claves RSA de exportación en entorno productivo", e);
                }
                log.warn("Fallo al parsear claves RSA de exportación, generando en memoria: {}", e.getMessage());
            }
        }

        if (isProd) {
            throw new IllegalStateException("Clave RSA para exportaciones (EXPORT_RSA_PRIVATE_KEY y EXPORT_RSA_PUBLIC_KEY) es obligatoria en entorno productivo.");
        }

        // Generación dinámica en memoria para dev/test
        try {
            KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
            kpg.initialize(2048);
            KeyPair kp = kpg.generateKeyPair();
            registerKey(primaryKeyId, (RSAPrivateKey) kp.getPrivate(), (RSAPublicKey) kp.getPublic());
            log.info("Clave RSA efímera dedicada para exportaciones generada con kid='{}' (aislada de JWKS).", primaryKeyId);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("No se pudo instanciar KeyPairGenerator para RSA", e);
        }
    }

    public void registerKey(String kid, RSAPrivateKey privateKey, RSAPublicKey publicKey) {
        keyStore.put(kid, new ExportRsaKeyEntry(kid, privateKey, publicKey));
    }

    public String getPrimaryKeyId() {
        return primaryKeyId;
    }

    public ExportRsaKeyEntry getPrimaryEntry() {
        ExportRsaKeyEntry entry = keyStore.get(primaryKeyId);
        if (entry == null) {
            throw new IllegalStateException("No se encontró la clave RSA de exportación primaria: " + primaryKeyId);
        }
        return entry;
    }

    public String sign(String payload) {
        try {
            ExportRsaKeyEntry entry = getPrimaryEntry();
            Signature signature = Signature.getInstance("SHA256withRSA");
            signature.initSign(entry.getPrivateKey());
            signature.update(payload.getBytes(StandardCharsets.UTF_8));
            byte[] signatureBytes = signature.sign();
            return Base64.getEncoder().encodeToString(signatureBytes);
        } catch (Exception e) {
            throw new RuntimeException("Error al firmar exportación con clave RSA dedicada", e);
        }
    }

    public boolean verify(String payload, String signatureBase64, String kid) {
        try {
            ExportRsaKeyEntry entry = keyStore.get(kid);
            if (entry == null) {
                log.warn("Clave pública de exportación no encontrada para kid='{}'", kid);
                return false;
            }
            Signature signature = Signature.getInstance("SHA256withRSA");
            signature.initVerify(entry.getPublicKey());
            signature.update(payload.getBytes(StandardCharsets.UTF_8));
            byte[] signatureBytes = Base64.getDecoder().decode(signatureBase64);
            return signature.verify(signatureBytes);
        } catch (Exception e) {
            log.error("Error al verificar firma de exportación: {}", e.getMessage());
            return false;
        }
    }

    public Map<String, Object> getExportJwks() {
        List<Map<String, Object>> keysList = new ArrayList<>();
        for (ExportRsaKeyEntry entry : keyStore.values()) {
            RSAPublicKey pubKey = entry.getPublicKey();
            Map<String, Object> jwk = new LinkedHashMap<>();
            jwk.put("kty", "RSA");
            jwk.put("kid", entry.getKid());
            jwk.put("use", "sig");
            jwk.put("alg", "RS256");
            jwk.put("n", Base64.getUrlEncoder().withoutPadding().encodeToString(pubKey.getModulus().toByteArray()));
            jwk.put("e", Base64.getUrlEncoder().withoutPadding().encodeToString(pubKey.getPublicExponent().toByteArray()));
            keysList.add(jwk);
        }
        return Map.of("keys", keysList);
    }

    private RSAPrivateKey parsePrivateKey(String pem) throws Exception {
        String clean = pem.replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s+", "");
        byte[] encoded = Base64.getDecoder().decode(clean);
        PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(encoded);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return (RSAPrivateKey) kf.generatePrivate(spec);
    }

    private RSAPublicKey parsePublicKey(String pem) throws Exception {
        String clean = pem.replace("-----BEGIN PUBLIC KEY-----", "")
                .replace("-----END PUBLIC KEY-----", "")
                .replaceAll("\\s+", "");
        byte[] encoded = Base64.getDecoder().decode(clean);
        X509EncodedKeySpec spec = new X509EncodedKeySpec(encoded);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return (RSAPublicKey) kf.generatePublic(spec);
    }
}
