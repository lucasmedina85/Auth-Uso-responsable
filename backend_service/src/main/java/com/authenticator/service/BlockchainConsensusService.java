package com.authenticator.service;

import com.authenticator.domain.BlockchainNetworkStatus;
import com.authenticator.exception.BlockchainTimeoutException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Instant;

/**
 * Servicio de Consulta de Consenso de Red (CU-0031, 5 SP).
 *
 * Verifica activamente que el nodo Blockchain conectado mantenga sincronización y quórum de pares
 * antes de despachar transacciones de auditoría forense (CU-0030).
 */
@Service
public class BlockchainConsensusService {

    private static final Logger logger = LoggerFactory.getLogger(BlockchainConsensusService.class);

    private final BlockchainProvider blockchainProvider;

    public BlockchainConsensusService(@Autowired(required = false) BlockchainProvider blockchainProvider) {
        this.blockchainProvider = blockchainProvider;
    }

    /**
     * Consulta el estado de consenso actual de la red, manejando errores y timeouts.
     */
    public BlockchainNetworkStatus checkConsensus() {
        if (blockchainProvider == null) {
            logger.warn("No hay proveedor de Blockchain configurado");
            return BlockchainNetworkStatus.builder()
                    .status("NO_PROVIDER")
                    .consensusReached(false)
                    .network("unknown")
                    .checkedAt(Instant.now())
                    .message("No hay un BlockchainProvider activo en el contexto")
                    .build();
        }

        try {
            BlockchainNetworkStatus status = blockchainProvider.getNetworkStatus();
            if (status.isConsensusReached()) {
                logger.debug("Consenso verificado exitosamente: {}", status.getStatus());
            } else {
                logger.warn("Alerta de consenso de red no alcanzado: {} - {}", status.getStatus(), status.getMessage());
            }
            return status;
        } catch (BlockchainTimeoutException e) {
            logger.error("Timeout consultando estado de consenso de la Blockchain: {}", e.getMessage());
            return BlockchainNetworkStatus.builder()
                    .status("TIMEOUT")
                    .consensusReached(false)
                    .checkedAt(Instant.now())
                    .message("Timeout al consultar el consenso del nodo: " + e.getMessage())
                    .build();
        } catch (Exception e) {
            logger.error("Error al consultar el consenso de la Blockchain: {}", e.getMessage());
            return BlockchainNetworkStatus.builder()
                    .status("RPC_ERROR")
                    .consensusReached(false)
                    .checkedAt(Instant.now())
                    .message("Error de comunicación RPC con la red: " + e.getMessage())
                    .build();
        }
    }

    /**
     * Determina rápidamente si el nodo mantiene consenso con la red.
     */
    public boolean isConsensusHealthy() {
        return checkConsensus().isConsensusReached();
    }
}
