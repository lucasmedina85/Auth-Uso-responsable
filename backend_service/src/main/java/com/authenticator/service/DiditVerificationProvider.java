package com.authenticator.service;

import com.authenticator.domain.FingerprintResult;
import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;
import com.authenticator.exception.FeatureUnsupportedException;
import com.authenticator.exception.ProviderTimeoutException;
import com.authenticator.exception.ProviderUnavailableException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service("diditProvider")
public class DiditVerificationProvider implements IdentityVerificationProvider {

    @Value("${app.didit.api-key}")
    private String apiKey;

    @Value("${app.didit.workflow-id}")
    private String workflowId;

    private final RestTemplate restTemplate = new RestTemplate();
    private final VerificationSessionService sessionService;

    public DiditVerificationProvider(VerificationSessionService sessionService) {
        this.sessionService = sessionService;
    }

    @Override
    public VerificationSessionResponse startVerification(String userId) {
        String url = "https://verification.didit.me/v3/session/";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Authorization", "Bearer " + apiKey); // TODO: Verificá si aplica Bearer o x-api-key en los docs de Didit

        Map<String, Object> body = new HashMap<>();
        body.put("workflow_id", workflowId);
        body.put("vendor_data", userId);
        body.put("callback", "https://tu-ngrok-url.ngrok.io/api/v1/verification/webhook"); // TODO: Mover a config

        HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, request, Map.class);
            Map<String, Object> responseBody = response.getBody();
            if (responseBody != null) {
                String sessionId = (String) responseBody.get("session_id");
                String sessionUrl = (String) responseBody.get("url");
                return new VerificationSessionResponse(sessionId, sessionUrl);
            }
            throw new ProviderUnavailableException("Respuesta vacía de Didit");
        } catch (HttpServerErrorException e) {
            throw new ProviderUnavailableException("Didit 5xx Error: " + e.getMessage());
        } catch (HttpClientErrorException e) {
            throw new RuntimeException("Error en petición a Didit: " + e.getMessage());
        } catch (Exception e) {
            throw new ProviderTimeoutException("Timeout o error de red con Didit: " + e.getMessage());
        }
    }

    @Override
    public VerificationResult verifyIdentity(String dni, String tramite, String gender, byte[] selfie, String firstName) {
        // CU-0009 Modo Directo
        String url = "https://verification.didit.me/v3/database-validation/";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("Authorization", "Bearer " + apiKey); // TODO: Verificar auth method

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("issuing_state", "ARG");
        body.add("services", "arg_renaper");
        body.add("document_number", dni);
        body.add("gender", gender);
        if (firstName != null) body.add("first_name", firstName);
        
        // TODO: Agregar el archivo multipart de la selfie de manera correcta con ByteArrayResource

        HttpEntity<MultiValueMap<String, Object>> request = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, request, Map.class);
            // TODO: Mapear respuesta real de Didit al DTO
            VerificationResult result = new VerificationResult();
            result.setMatchType("FULL_MATCH");
            return result;
        } catch (Exception e) {
             throw new ProviderTimeoutException("Error en modo directo Didit: " + e.getMessage());
        }
    }

    @Override
    public VerificationResult getResult(String sessionId) {
        return sessionService.getSessionStatus(sessionId);
    }

    @Override
    public FingerprintResult verifyFingerprint(byte[] encryptedTemplate) {
        throw new FeatureUnsupportedException("Didit no soporta cotejo dactilar (CU-0019)");
    }

    @Override
    public boolean supportsFingerprint() {
        return false;
    }

    @Override
    public boolean checkHealth() {
        return true;
    }
}
