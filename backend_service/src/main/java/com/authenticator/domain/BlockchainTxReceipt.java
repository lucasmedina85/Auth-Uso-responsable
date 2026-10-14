package com.authenticator.domain;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BlockchainTxReceipt {
    private String transactionHash;
    private long blockNumber;
    private Instant timestamp;
    private boolean success;
    private String network;
}
