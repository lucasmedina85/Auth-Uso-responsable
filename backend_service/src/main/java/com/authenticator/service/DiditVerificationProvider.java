package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.exception.BusinessDeclinedException;
import com.authenticator.exception.FeatureUnsupportedException;
import com.authenticator.exception.ProviderTimeoutException;
import com.authenticator.exception.ProviderUnavailableException;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service("diditProvider")
@ConditionalOnProperty(name = "app.identity-provider", havingValue = "didit")
public class DiditVerificationProvider implements IdentityVerificationProvider {

    @Value("${app.didit.api-key:}")
    private String apiKey;

    @Value("${DIDIT_SAVE_REQUESTS:false}")
    private boolean saveApiRequest;

    private final RestTemplate restTemplate = new RestTemplate();
    private final VerificationSessionService sessionService;

    public DiditVerificationProvider(VerificationSessionService sessionService) {
        this.sessionService = sessionService;
    }

    private HttpHeaders createHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.set("x-api-key", apiKey);
        return headers;
    }

    private void handleException(Exception e) {
        if (e instanceof HttpClientErrorException.TooManyRequests) {
            throw (HttpClientErrorException) e; // Dejar pasar para que actúe @Retry
        }
        if (e instanceof HttpClientErrorException) {
            // 4xx errors usually mean bad input or unauthorized, not a 5xx circuit trip
            throw new BusinessDeclinedException("Client error from Didit: " + e.getMessage());
        }
        if (e instanceof HttpServerErrorException) {
            throw new ProviderUnavailableException("Didit 5xx Error: " + e.getMessage());
        }
        throw new ProviderTimeoutException("Network/Timeout error: " + e.getMessage());
    }

    @Override
    @Retry(name = "diditProvider")
    @CircuitBreaker(name = "diditProvider")
    public DocumentResult verifyDocument(byte[] frontImage, byte[] backImage, String vendorData) {
        String url = "https://verification.didit.me/v3/id-verification/";
        HttpHeaders headers = createHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("front_image", new ByteArrayResource(frontImage) {
            @Override public String getFilename() { return "front.jpg"; }
        });
        if (backImage != null) {
            body.add("back_image", new ByteArrayResource(backImage) {
                @Override public String getFilename() { return "back.jpg"; }
            });
        }
        body.add("save_api_request", String.valueOf(saveApiRequest));
        body.add("vendor_data", vendorData);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, new HttpEntity<>(body, headers), Map.class);
            Map<String, Object> resBody = response.getBody();
            if (resBody == null) throw new ProviderUnavailableException("Empty response");

            String status = (String) resBody.get("status");
            if ("Declined".equalsIgnoreCase(status)) throw new BusinessDeclinedException("Document rejected by provider");

            DocumentResult result = new DocumentResult();
            result.setStatus(status);
            // Map extracting data from response according to Didit schema
            result.setDocumentNumber((String) resBody.get("document_number"));
            result.setFirstName((String) resBody.get("first_name"));
            result.setLastName((String) resBody.get("last_name"));
            result.setDateOfBirth((String) resBody.get("date_of_birth"));
            result.setExpirationDate((String) resBody.get("expiration_date"));
            return result;
        } catch (Exception e) {
            handleException(e);
            return null; // Unreachable
        }
    }

    @Override
    @Retry(name = "diditProvider")
    @CircuitBreaker(name = "diditProvider")
    public LivenessResult checkLiveness(byte[] userImage, String vendorData) {
        String url = "https://verification.didit.me/v3/passive-liveness/";
        HttpHeaders headers = createHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("user_image", new ByteArrayResource(userImage) {
            @Override public String getFilename() { return "selfie.jpg"; }
        });
        body.add("save_api_request", String.valueOf(saveApiRequest));
        body.add("vendor_data", vendorData);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, new HttpEntity<>(body, headers), Map.class);
            Map<String, Object> resBody = response.getBody();
            if (resBody == null) throw new ProviderUnavailableException("Empty response");

            String status = (String) resBody.get("status");
            if ("Declined".equalsIgnoreCase(status)) throw new BusinessDeclinedException("Liveness rejected by provider");

            LivenessResult result = new LivenessResult();
            result.setStatus(status);
            if (resBody.containsKey("score")) {
                result.setScore(((Number) resBody.get("score")).intValue());
            } else {
                result.setScore(100); // Default to pass if not provided
            }
            return result;
        } catch (Exception e) {
            handleException(e);
            return null;
        }
    }

    @Override
    @Retry(name = "diditProvider")
    @CircuitBreaker(name = "diditProvider")
    public FaceMatchResult matchFaces(byte[] userImage, byte[] refImage, String vendorData) {
        String url = "https://verification.didit.me/v3/face-match/";
        HttpHeaders headers = createHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("user_image", new ByteArrayResource(userImage) {
            @Override public String getFilename() { return "selfie.jpg"; }
        });
        body.add("reference_image", new ByteArrayResource(refImage) {
            @Override public String getFilename() { return "ref.jpg"; }
        });
        body.add("save_api_request", String.valueOf(saveApiRequest));
        body.add("vendor_data", vendorData);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, new HttpEntity<>(body, headers), Map.class);
            Map<String, Object> resBody = response.getBody();
            if (resBody == null) throw new ProviderUnavailableException("Empty response");

            String status = (String) resBody.get("status");
            if ("Declined".equalsIgnoreCase(status)) throw new BusinessDeclinedException("Face Match rejected by provider");

            FaceMatchResult result = new FaceMatchResult();
            result.setStatus(status);
            if (resBody.containsKey("score")) {
                result.setScore(((Number) resBody.get("score")).intValue());
            } else {
                result.setScore(100);
            }
            return result;
        } catch (Exception e) {
            handleException(e);
            return null;
        }
    }

    @Override
    @Retry(name = "diditProvider")
    @CircuitBreaker(name = "diditProvider")
    public RegistryResult validateRegistry(String issuingState, String validationType, String firstName, String lastName, String dob, String personalNumber, String vendorData) {
        String url = "https://verification.didit.me/v3/database-validation/";
        HttpHeaders headers = createHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        Map<String, Object> body = new HashMap<>();
        body.put("issuing_state", issuingState);
        body.put("services", validationType);
        body.put("first_name", firstName);
        body.put("last_name", lastName);
        body.put("date_of_birth", dob);
        body.put("document_number", personalNumber);
        body.put("save_api_request", saveApiRequest);
        body.put("vendor_data", vendorData);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, new HttpEntity<>(body, headers), Map.class);
            Map<String, Object> resBody = response.getBody();
            if (resBody == null) throw new ProviderUnavailableException("Empty response");

            String status = (String) resBody.get("status");
            if ("Declined".equalsIgnoreCase(status)) throw new BusinessDeclinedException("Registry validation rejected by provider");

            RegistryResult result = new RegistryResult();
            result.setStatus(status);
            
            // Didit RENAPER validation response might not explicitly give "latest document" boolean.
            // If the validation succeeds, we assume it's valid, but whether it's the *latest* copy is unknown unless explicitly stated.
            // We set it to UNKNOWN (null) unless we parse a specific "latest_copy: true" flag.
            result.setIsLatestDocument(null); 
            
            return result;
        } catch (Exception e) {
            handleException(e);
            return null;
        }
    }

    // --- Legacy / Unused in Standalone ---
    @Override
    public VerificationSessionResponse startVerification(String userId) {
        return null;
    }

    @Override
    public VerificationResult getResult(String sessionId) {
        return null;
    }

    @Override
    public VerificationResult verifyIdentity(String dni, String tramite, String gender, byte[] selfie, String firstName) {
        return null;
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
