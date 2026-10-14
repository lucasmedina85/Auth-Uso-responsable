package com.authenticator.service;

import com.authenticator.domain.BlockchainNetworkStatus;
import com.authenticator.domain.BlockchainRecord;
import com.authenticator.domain.BlockchainTxReceipt;

/**
 * Proveedor de integración con la red Blockchain (CU-0030 / CU-0031 / CU-0047).
 */
public interface BlockchainProvider {

    /**
     * Consulta el estado de salud y consenso del nodo con la red (CU-0031).
     */
    BlockchainNetworkStatus getNetworkStatus();

    /**
     * Envía un registro de auditoría on-chain inmutable (CU-0030).
     */
    BlockchainTxReceipt submitRiskAssessment(BlockchainRecord record);

    /**
     * Comprueba si el proveedor y el nodo están operativos.
     */
    boolean isHealthy();
}
