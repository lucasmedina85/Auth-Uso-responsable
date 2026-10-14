package com.authenticator.service;

import com.authenticator.domain.BlockchainNetworkStatus;
import com.authenticator.domain.BlockchainRecord;
import com.authenticator.domain.BlockchainTxReceipt;
import com.authenticator.exception.BlockchainException;
import com.authenticator.exception.BlockchainTimeoutException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Proveedor simulado de Blockchain para desarrollo, pruebas y entornos locales (CU-0030 / CU-0031).
 *
 * Permite simular:
 * 1. Nodo desincronizado / desfasado (localBlock vs peerBlock excediendo drift permitido).
 * 2. Pares insuficientes (peerCount < minPeers).
 * 3. Timeout en la consulta RPC.
 * 4. Falla en el envío de transacciones (submit failure).
 */
@Service
@ConditionalOnProperty(name = "app.blockchain.provider", havingValue = "mock", matchIfMissing = true)
public class MockBlockchainProvider implements BlockchainProvider {

    private static final Logger logger = LoggerFactory.getLogger(MockBlockchainProvider.class);

    @Value("${app.blockchain.network:mock}")
    private String network = "mock";

    @Value("${app.blockchain.consensus.min-peers:3}")
    private int minPeers = 3;

    @Value("${app.blockchain.consensus.max-block-drift:3}")
    private int maxBlockDrift = 3;

    @Value("${app.blockchain.consensus.timeout-ms:5000}")
    private long timeoutMs = 5000;

    private final AtomicLong blockCounter = new AtomicLong(1_250_000L);

    // Banderas de simulación para pruebas
    private volatile boolean simulateOutOfSync = false;
    private volatile long simulatedLocalBlock = 1_250_000L;
    private volatile long simulatedHighestPeerBlock = 1_250_000L;

    private volatile boolean simulateLowPeers = false;
    private volatile int simulatedPeerCount = 8;

    private volatile boolean simulateSyncing = false;
    private volatile boolean simulateTimeout = false;
    private volatile boolean simulateRpcError = false;
    private volatile boolean simulateSubmitFailure = false;

    @jakarta.annotation.PostConstruct
    public void logMockProviderWarning() {
        logger.warn("****************************************************************************************");
        logger.warn("⚠️  [ADVERTENCIA DE SEGURIDAD]: Proveedor Blockchain ACTIVO es 'MOCK' (red: {})", network);
        logger.warn("⚠️  Las transacciones de auditoría forense NO se registran en una red descentralizada real.");
        logger.warn("⚠️  Este modo es EXCLUSIVO para entornos de DESARROLLO/TESTING. NO USAR EN PRODUCCIÓN.");
        logger.warn("****************************************************************************************");
    }

    @Override
    public BlockchainNetworkStatus getNetworkStatus() {
        if (simulateTimeout) {
            logger.warn("Simulando TIMEOUT en consulta de consenso RPC");
            throw new BlockchainTimeoutException("Timeout esperando respuesta de consenso del nodo blockchain (" + timeoutMs + "ms)");
        }

        if (simulateRpcError) {
            logger.warn("Simulando ERROR RPC en consulta de consenso");
            throw new BlockchainException("Fallo en conexión RPC al nodo blockchain: Connection refused");
        }

        long localHeight = simulateOutOfSync ? simulatedLocalBlock : blockCounter.get();
        long peerHeight = simulateOutOfSync ? simulatedHighestPeerBlock : blockCounter.get();
        int peers = simulateLowPeers ? simulatedPeerCount : 8;
        boolean syncing = simulateSyncing;

        long drift = Math.abs(peerHeight - localHeight);

        String statusStr;
        boolean consensusReached;
        String message;

        if (syncing) {
            statusStr = "SYNCING";
            consensusReached = false;
            message = "Nodo sincronizando bloques con la red (en progreso)";
        } else if (peers < minPeers) {
            statusStr = "INSUFFICIENT_PEERS";
            consensusReached = false;
            message = String.format("Pares insuficientes: %d conectados (mínimo requerido: %d)", peers, minPeers);
        } else if (drift > maxBlockDrift) {
            statusStr = "DESYNCHRONIZED";
            consensusReached = false;
            message = String.format("Desfase de bloques excesivo: local=%d, pares=%d (drift=%d > máx %d)", localHeight, peerHeight, drift, maxBlockDrift);
        } else {
            statusStr = "CONSENSUS_HEALTHY";
            consensusReached = true;
            message = String.format("Consenso saludable en red %s. Altura: %d, Pares: %d", network, localHeight, peers);
        }

        return BlockchainNetworkStatus.builder()
                .status(statusStr)
                .consensusReached(consensusReached)
                .localBlockHeight(localHeight)
                .highestPeerBlockHeight(peerHeight)
                .peerCount(peers)
                .syncing(syncing)
                .network(network)
                .checkedAt(Instant.now())
                .message(message)
                .build();
    }

    @Override
    public BlockchainTxReceipt submitRiskAssessment(BlockchainRecord record) {
        if (simulateSubmitFailure) {
            logger.warn("Simulando fallo en submitRiskAssessment a Blockchain");
            throw new BlockchainException("Fallo al enviar transacción on-chain: RPC execution reverted o timeout de red");
        }

        long block = blockCounter.incrementAndGet();
        String hashInput = record.getSessionHash() + ":" + record.getDecision() + ":" + record.getScore() + ":" + block;
        String txHash = "0x" + sha256Hex(hashInput);

        logger.info("Transacción on-chain registrada exitosamente. Hash: {}, Decisión: {}, Score: {}, Red: {}",
                txHash, record.getDecision(), record.getScore(), network);

        return BlockchainTxReceipt.builder()
                .transactionHash(txHash)
                .blockNumber(block)
                .timestamp(Instant.now())
                .success(true)
                .network(network)
                .build();
    }

    @Override
    public boolean isHealthy() {
        try {
            return getNetworkStatus().isConsensusReached();
        } catch (Exception e) {
            return false;
        }
    }

    // --- Métodos de configuración para pruebas unitarias ---

    public void setSimulateOutOfSync(boolean outOfSync, long localBlock, long highestPeerBlock) {
        this.simulateOutOfSync = outOfSync;
        this.simulatedLocalBlock = localBlock;
        this.simulatedHighestPeerBlock = highestPeerBlock;
    }

    public void setSimulateLowPeers(boolean lowPeers, int peers) {
        this.simulateLowPeers = lowPeers;
        this.simulatedPeerCount = peers;
    }

    public void setSimulateSyncing(boolean syncing) {
        this.simulateSyncing = syncing;
    }

    public void setSimulateTimeout(boolean timeout) {
        this.simulateTimeout = timeout;
    }

    public void setSimulateRpcError(boolean rpcError) {
        this.simulateRpcError = rpcError;
    }

    public void setSimulateSubmitFailure(boolean failure) {
        this.simulateSubmitFailure = failure;
    }

    public void resetToDefaults() {
        this.simulateOutOfSync = false;
        this.simulatedLocalBlock = 1_250_000L;
        this.simulatedHighestPeerBlock = 1_250_000L;
        this.simulateLowPeers = false;
        this.simulatedPeerCount = 8;
        this.simulateSyncing = false;
        this.simulateTimeout = false;
        this.simulateRpcError = false;
        this.simulateSubmitFailure = false;
    }

    private String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not supported", e);
        }
    }
}
