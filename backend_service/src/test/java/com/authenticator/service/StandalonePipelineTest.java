package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.exception.BusinessDeclinedException;
import com.authenticator.exception.ProviderUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class StandalonePipelineTest {

    private IdentityVerificationProvider mockProvider;
    private RiskEngineService riskEngineService;
    private IdentityVerificationService service;

    @BeforeEach
    void setUp() {
        mockProvider = mock(IdentityVerificationProvider.class);
        riskEngineService = mock(RiskEngineService.class);
        service = new IdentityVerificationService(mockProvider, riskEngineService);
    }

    private DocumentResult getValidDoc() {
        DocumentResult doc = new DocumentResult();
        doc.setStatus("Approved");
        doc.setDateOfBirth("1990-01-01");
        doc.setExpirationDate("2030-01-01");
        doc.setFirstName("Juan");
        doc.setLastName("Perez");
        doc.setDocumentNumber("11111111");
        return doc;
    }

    @Test
    void testHappyPath() {
        when(mockProvider.verifyDocument(any(), any(), any())).thenReturn(getValidDoc());
        when(mockProvider.checkLiveness(any(), any())).thenReturn(new LivenessResult("Approved", 98));
        when(mockProvider.matchFaces(any(), any(), any())).thenReturn(new FaceMatchResult("Approved", 95));
        when(mockProvider.validateRegistry(anyString(), anyString(), anyString(), anyString(), anyString(), anyString(), anyString()))
                .thenReturn(new RegistryResult("Approved", true));
        when(riskEngineService.evaluateRisk(any())).thenReturn("AUTORIZAR");

        VerificationResult res = service.executeStandalonePipeline(new byte[0], new byte[0], new byte[0], "vendor1");

        assertEquals("APPROVED", res.getMatchType());
        assertTrue(res.getIsLatestDocument());
        assertEquals(95, res.getFaceMatchScore());
        assertEquals(98, res.getLivenessScore());
    }

    @Test
    void testDocumentDeclined() {
        DocumentResult rejectedDoc = new DocumentResult();
        rejectedDoc.setStatus("Declined");
        when(mockProvider.verifyDocument(any(), any(), any())).thenReturn(rejectedDoc);

        VerificationResult res = service.executeStandalonePipeline(new byte[0], null, new byte[0], "vendor1");
        assertEquals("REJECTED_DOCUMENT_INVALID", res.getMatchType());
        verify(mockProvider, never()).checkLiveness(any(), any()); // Early Exit
    }

    @Test
    void testBusinessExceptionDoesNotTripBreaker() {
        when(mockProvider.verifyDocument(any(), any(), any())).thenReturn(getValidDoc());
        when(mockProvider.checkLiveness(any(), any())).thenThrow(new BusinessDeclinedException("Declined Liveness"));

        VerificationResult res = service.executeStandalonePipeline(new byte[0], null, new byte[0], "vendor1");
        assertEquals("REJECTED_BY_PROVIDER", res.getMatchType());
        verify(mockProvider, never()).matchFaces(any(), any(), any()); // Early Exit
    }

    @Test
    void testProviderUnavailableThrows5xxForBreaker() {
        when(mockProvider.verifyDocument(any(), any(), any())).thenReturn(getValidDoc());
        when(mockProvider.checkLiveness(any(), any())).thenThrow(new ProviderUnavailableException("500 Error"));

        assertThrows(ProviderUnavailableException.class, () -> {
            service.executeStandalonePipeline(new byte[0], null, new byte[0], "vendor1");
        });
    }

    @Test
    void testUnknownDocumentState() {
        when(mockProvider.verifyDocument(any(), any(), any())).thenReturn(getValidDoc());
        when(mockProvider.checkLiveness(any(), any())).thenReturn(new LivenessResult("Approved", 98));
        when(mockProvider.matchFaces(any(), any(), any())).thenReturn(new FaceMatchResult("Approved", 95));
        
        RegistryResult regRes = new RegistryResult("Approved", null); // UNKNOWN
        when(mockProvider.validateRegistry(anyString(), anyString(), anyString(), anyString(), anyString(), anyString(), anyString()))
                .thenReturn(regRes);
                
        when(riskEngineService.evaluateRisk(any())).thenReturn("AUTORIZAR");

        VerificationResult res = service.executeStandalonePipeline(new byte[0], null, new byte[0], "vendor1");

        assertEquals("APPROVED", res.getMatchType());
        assertNull(res.getIsLatestDocument()); // Verificamos que respete el null
    }

    @Test
    void testUnderage() {
        DocumentResult underageDoc = getValidDoc();
        underageDoc.setDateOfBirth("2015-01-01");
        when(mockProvider.verifyDocument(any(), any(), any())).thenReturn(underageDoc);

        VerificationResult res = service.executeStandalonePipeline(new byte[0], null, new byte[0], "vendor1");
        assertEquals("REJECTED_UNDERAGE", res.getMatchType());
        verify(mockProvider, never()).checkLiveness(any(), any());
    }
    @Test
    void testProviderTimeoutThrowsExceptionForBreaker() {
        when(mockProvider.verifyDocument(any(), any(), any())).thenReturn(getValidDoc());
        when(mockProvider.checkLiveness(any(), any())).thenThrow(new com.authenticator.exception.ProviderTimeoutException("Timeout"));

        assertThrows(com.authenticator.exception.ProviderTimeoutException.class, () -> {
            service.executeStandalonePipeline(new byte[0], null, new byte[0], "vendor1");
        });
    }
}
