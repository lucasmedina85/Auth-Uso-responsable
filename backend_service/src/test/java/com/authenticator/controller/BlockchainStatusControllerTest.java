package com.authenticator.controller;

import com.authenticator.security.JwtUtil;
import com.authenticator.service.MockBlockchainProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class BlockchainStatusControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private MockBlockchainProvider mockProvider;

    @Autowired
    private JwtUtil jwtUtil;

    @BeforeEach
    public void setUp() {
        mockProvider.resetToDefaults();
    }

    // --- Tests para el Endpoint Público Mínimo (GET /blockchain/status) ---

    @Test
    public void getPublicStatus_WhenHealthy_Returns200AndMinimalUpStatus() throws Exception {
        mockMvc.perform(get("/blockchain/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.localBlockHeight").doesNotExist())
                .andExpect(jsonPath("$.highestPeerBlockHeight").doesNotExist())
                .andExpect(jsonPath("$.peerCount").doesNotExist())
                .andExpect(jsonPath("$.network").doesNotExist())
                .andExpect(jsonPath("$.message").doesNotExist());
    }

    @Test
    public void getPublicStatus_WhenOutOfSync_Returns503AndMinimalDownStatus() throws Exception {
        mockProvider.setSimulateOutOfSync(true, 1000L, 1050L);

        mockMvc.perform(get("/blockchain/status"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.status").value("DOWN"))
                .andExpect(jsonPath("$.localBlockHeight").doesNotExist())
                .andExpect(jsonPath("$.message").doesNotExist());
    }

    @Test
    public void getPublicStatus_WhenLowPeers_Returns503AndMinimalDownStatus() throws Exception {
        mockProvider.setSimulateLowPeers(true, 1);

        mockMvc.perform(get("/blockchain/status"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.status").value("DOWN"))
                .andExpect(jsonPath("$.peerCount").doesNotExist());
    }

    @Test
    public void getPublicStatus_WhenTimeout_Returns503AndMinimalDownStatus() throws Exception {
        mockProvider.setSimulateTimeout(true);

        mockMvc.perform(get("/blockchain/status"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.status").value("DOWN"))
                .andExpect(jsonPath("$.message").doesNotExist());
    }

    // --- Tests para el Endpoint Administrativo Protegido (GET /admin/blockchain/status) ---

    @Test
    public void getAdminStatus_WithoutAuthentication_Returns401Unauthorized() throws Exception {
        mockMvc.perform(get("/admin/blockchain/status"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void getAdminStatus_WithRegularUserRole_Returns403Forbidden() throws Exception {
        String regularUserToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString()); // Rol default: USER

        mockMvc.perform(get("/admin/blockchain/status")
                .header("Authorization", "Bearer " + regularUserToken))
                .andExpect(status().isForbidden());
    }

    @Test
    public void getAdminStatus_WithAdminRole_WhenHealthy_Returns200AndDetailedStatus() throws Exception {
        String adminToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "ADMIN");

        mockMvc.perform(get("/admin/blockchain/status")
                .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CONSENSUS_HEALTHY"))
                .andExpect(jsonPath("$.consensusReached").value(true))
                .andExpect(jsonPath("$.localBlockHeight").isNumber())
                .andExpect(jsonPath("$.peerCount").isNumber())
                .andExpect(jsonPath("$.network").value("mock"))
                .andExpect(jsonPath("$.message").isString());
    }

    @Test
    public void getAdminStatus_WithMonitoringRole_WhenOutOfSync_Returns503AndDetailedStatus() throws Exception {
        mockProvider.setSimulateOutOfSync(true, 1000L, 1050L);
        String monitoringToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "MONITORING");

        mockMvc.perform(get("/admin/blockchain/status")
                .header("Authorization", "Bearer " + monitoringToken))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.status").value("DESYNCHRONIZED"))
                .andExpect(jsonPath("$.consensusReached").value(false))
                .andExpect(jsonPath("$.localBlockHeight").value(1000))
                .andExpect(jsonPath("$.highestPeerBlockHeight").value(1050))
                .andExpect(jsonPath("$.message").isString());
    }
}
