package com.authenticator.service;

import com.authenticator.domain.BlockchainNetworkStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class BlockchainConsensusServiceTest {

    private MockBlockchainProvider mockProvider;
    private BlockchainConsensusService consensusService;

    @BeforeEach
    public void setUp() {
        mockProvider = new MockBlockchainProvider();
        mockProvider.resetToDefaults();
        consensusService = new BlockchainConsensusService(mockProvider);
    }

    @Test
    public void checkConsensus_HealthyNetwork_ReachesConsensus() {
        BlockchainNetworkStatus status = consensusService.checkConsensus();

        assertNotNull(status);
        assertTrue(status.isConsensusReached());
        assertEquals("CONSENSUS_HEALTHY", status.getStatus());
        assertTrue(consensusService.isConsensusHealthy());
    }

    @Test
    public void checkConsensus_OutOfSync_ReturnsDesynchronized() {
        // Simular que el par está en 1_250_050 y el nodo local en 1_250_000 (drift de 50 bloques > maxDrift 3)
        mockProvider.setSimulateOutOfSync(true, 1_250_000L, 1_250_050L);

        BlockchainNetworkStatus status = consensusService.checkConsensus();

        assertNotNull(status);
        assertFalse(status.isConsensusReached());
        assertEquals("DESYNCHRONIZED", status.getStatus());
        assertTrue(status.getMessage().contains("Desfase de bloques"));
        assertFalse(consensusService.isConsensusHealthy());
    }

    @Test
    public void checkConsensus_LowPeers_ReturnsInsufficientPeers() {
        // Simular 1 solo par (minPeers = 3)
        mockProvider.setSimulateLowPeers(true, 1);

        BlockchainNetworkStatus status = consensusService.checkConsensus();

        assertNotNull(status);
        assertFalse(status.isConsensusReached());
        assertEquals("INSUFFICIENT_PEERS", status.getStatus());
        assertTrue(status.getMessage().contains("Pares insuficientes"));
        assertFalse(consensusService.isConsensusHealthy());
    }

    @Test
    public void checkConsensus_SyncingNode_ReturnsSyncing() {
        mockProvider.setSimulateSyncing(true);

        BlockchainNetworkStatus status = consensusService.checkConsensus();

        assertNotNull(status);
        assertFalse(status.isConsensusReached());
        assertEquals("SYNCING", status.getStatus());
        assertFalse(consensusService.isConsensusHealthy());
    }

    @Test
    public void checkConsensus_Timeout_ReturnsTimeoutStatus() {
        mockProvider.setSimulateTimeout(true);

        BlockchainNetworkStatus status = consensusService.checkConsensus();

        assertNotNull(status);
        assertFalse(status.isConsensusReached());
        assertEquals("TIMEOUT", status.getStatus());
        assertTrue(status.getMessage().contains("Timeout"));
        assertFalse(consensusService.isConsensusHealthy());
    }

    @Test
    public void checkConsensus_RpcError_ReturnsRpcErrorStatus() {
        mockProvider.setSimulateRpcError(true);

        BlockchainNetworkStatus status = consensusService.checkConsensus();

        assertNotNull(status);
        assertFalse(status.isConsensusReached());
        assertEquals("RPC_ERROR", status.getStatus());
        assertTrue(status.getMessage().contains("RPC"));
        assertFalse(consensusService.isConsensusHealthy());
    }

    @Test
    public void checkConsensus_NoProviderConfigured_ReturnsNoProvider() {
        BlockchainConsensusService serviceWithoutProvider = new BlockchainConsensusService(null);

        BlockchainNetworkStatus status = serviceWithoutProvider.checkConsensus();

        assertNotNull(status);
        assertFalse(status.isConsensusReached());
        assertEquals("NO_PROVIDER", status.getStatus());
        assertFalse(serviceWithoutProvider.isConsensusHealthy());
    }
}
