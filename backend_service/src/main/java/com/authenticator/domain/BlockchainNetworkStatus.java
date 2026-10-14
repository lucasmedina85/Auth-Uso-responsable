package com.authenticator.domain;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Estado de consenso de red de la Blockchain (CU-0031).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BlockchainNetworkStatus {
    private String status;              // CONSENSUS_HEALTHY, DESYNCHRONIZED, INSUFFICIENT_PEERS, SYNCING, TIMEOUT, RPC_ERROR
    private boolean consensusReached;    // True si el nodo está sincronizado y cumple quórum de pares
    private long localBlockHeight;       // Altura de bloque local
    private long highestPeerBlockHeight; // Altura de bloque reportada por los pares
    private int peerCount;              // Cantidad de pares conectados
    private boolean syncing;            // True si el nodo está sincronizándose
    private String network;              // Identificador de la red (mock, polygon-amoy, besu-private)
    private Instant checkedAt;          // Fecha y hora de la comprobación
    private String message;              // Detalle explicativo para monitoreo y auditoría
}
