package com.authenticator.security;

import io.jsonwebtoken.Jwts;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.math.BigInteger;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class RsaKeyManager {

    private static final Logger log = LoggerFactory.getLogger(RsaKeyManager.class);

    private final Environment environment;

    @Value("${app.oauth.rsa.key-id:sip-rsa-key-v1}")
    private String primaryKeyId;

    @Value("${app.oauth.rsa.private-key:}")
    private String configuredPrivateKeyPem;

    @Value("${app.oauth.rsa.public-key:}")
    private String configuredPublicKeyPem;

    public static class RsaKeyEntry {
        private final String kid;
        private final RSAPrivateKey privateKey;
        private final RSAPublicKey publicKey;

        public RsaKeyEntry(String kid, RSAPrivateKey privateKey, RSAPublicKey publicKey) {
            this.kid = kid;
            this.privateKey = privateKey;
            this.publicKey = publicKey;
        }

        public String getKid() { return kid; }
        public RSAPrivateKey getPrivateKey() { return privateKey; }
        public RSAPublicKey getPublicKey() { return publicKey; }
    }

    private final Map<String, RsaKeyEntry> keyStore = new ConcurrentHashMap<>();

    public RsaKeyManager(Environment environment) {
        this.environment = environment;
    }

    @PostConstruct
    public void init() {
        boolean isProd = Arrays.asList(environment.getActiveProfiles()).contains("prod");

        if (configuredPrivateKeyPem != null && !configuredPrivateKeyPem.isBlank() &&
            configuredPublicKeyPem != null && !configuredPublicKeyPem.isBlank()) {
            try {
                RSAPrivateKey privKey = parsePrivateKey(configuredPrivateKeyPem);
                RSAPublicKey pubKey = parsePublicKey(configuredPublicKeyPem);
                registerKey(primaryKeyId, privKey, pubKey);
                log.info("Clave RSA para OAuth cargada exitosamente desde configuración con kid='{}'", primaryKeyId);
                return;
            } catch (Exception e) {
                if (isProd) {
                    throw new IllegalStateException("Error al parsear claves RSA en entorno productivo", e);
                }
                log.warn("Fallo al parsear claves RSA configuradas, generando claves de prueba en memoria: {}", e.getMessage());
            }
        }

        if (isProd) {
            throw new IllegalStateException("Clave RSA (OAUTH_RSA_PRIVATE_KEY y OAUTH_RSA_PUBLIC_KEY) es obligatoria en entorno productivo.");
        }

        // Generar dinámicamente en memoria para desarrollo / testing
        try {
            KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
            kpg.initialize(2048);
            KeyPair kp = kpg.generateKeyPair();
            registerKey(primaryKeyId, (RSAPrivateKey) kp.getPrivate(), (RSAPublicKey) kp.getPublic());

            log.warn("****************************************************************************************");
            log.warn("⚠️  [ADVERTENCIA DE SEGURIDAD]: Clave RSA para OAuth generada dinámicamente en memoria (kid='{}').", primaryKeyId);
            log.warn("⚠️  Este modo es EXCLUSIVO para entornos de DESARROLLO/TESTING. NO USAR EN PRODUCCIÓN.");
            log.warn("****************************************************************************************");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("No se pudo instanciar KeyPairGenerator para RSA", e);
        }
    }

    public void registerKey(String kid, RSAPrivateKey privateKey, RSAPublicKey publicKey) {
        keyStore.put(kid, new RsaKeyEntry(kid, privateKey, publicKey));
    }

    public String getPrimaryKeyId() {
        return primaryKeyId;
    }

    public RsaKeyEntry getPrimaryEntry() {
        RsaKeyEntry entry = keyStore.get(primaryKeyId);
        if (entry == null) {
            throw new IllegalStateException("No hay clave RSA activa registrada para kid='" + primaryKeyId + "'");
        }
        return entry;
    }

    public RSAPublicKey getPublicKey(String kid) {
        RsaKeyEntry entry = keyStore.get(kid);
        return entry != null ? entry.getPublicKey() : null;
    }

    public String signToken(String subject, String audience, String issuer, String jti, Map<String, Object> extraClaims, long expirationMs) {
        RsaKeyEntry entry = getPrimaryEntry();
        Date now = new Date();
        Date exp = new Date(now.getTime() + expirationMs);

        return Jwts.builder()
                .header()
                    .keyId(entry.getKid())
                    .type("JWT")
                    .and()
                .issuer(issuer)
                .subject(subject)
                .audience().add(audience).and()
                .id(jti)
                .issuedAt(now)
                .expiration(exp)
                .claims(extraClaims)
                .signWith(entry.getPrivateKey(), Jwts.SIG.RS256)
                .compact();
    }

    public io.jsonwebtoken.Claims validateAndParseToken(String token) {
        RsaKeyEntry entry = getPrimaryEntry();
        return Jwts.parser()
                .verifyWith(entry.getPublicKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public Map<String, Object> getJwks() {
        List<Map<String, Object>> keyList = new ArrayList<>();
        for (RsaKeyEntry entry : keyStore.values()) {
            RSAPublicKey pub = entry.getPublicKey();
            String n = base64UrlEncodeUnsignedBigInt(pub.getModulus());
            String e = base64UrlEncodeUnsignedBigInt(pub.getPublicExponent());

            Map<String, Object> keyMap = new LinkedHashMap<>();
            keyMap.put("kty", "RSA");
            keyMap.put("use", "sig");
            keyMap.put("alg", "RS256");
            keyMap.put("kid", entry.getKid());
            keyMap.put("n", n);
            keyMap.put("e", e);
            keyList.add(keyMap);
        }
        return Map.of("keys", keyList);
    }

    private String base64UrlEncodeUnsignedBigInt(BigInteger bigInt) {
        byte[] bytes = bigInt.toByteArray();
        int offset = 0;
        int len = bytes.length;
        if (bytes.length > 1 && bytes[0] == 0) {
            offset = 1;
            len--;
        }
        byte[] unsigned = new byte[len];
        System.arraycopy(bytes, offset, unsigned, 0, len);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(unsigned);
    }

    private RSAPrivateKey parsePrivateKey(String pem) throws Exception {
        String clean = pem.replace("-----BEGIN PRIVATE KEY-----", "")
                          .replace("-----END PRIVATE KEY-----", "")
                          .replaceAll("\\s+", "");
        byte[] encoded = Base64.getDecoder().decode(clean);
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(encoded);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return (RSAPrivateKey) kf.generatePrivate(keySpec);
    }

    private RSAPublicKey parsePublicKey(String pem) throws Exception {
        String clean = pem.replace("-----BEGIN PUBLIC KEY-----", "")
                          .replace("-----END PUBLIC KEY-----", "")
                          .replaceAll("\\s+", "");
        byte[] encoded = Base64.getDecoder().decode(clean);
        X509EncodedKeySpec keySpec = new X509EncodedKeySpec(encoded);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return (RSAPublicKey) kf.generatePublic(keySpec);
    }
}
