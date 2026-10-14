package com.authenticator.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

/**
 * Configuración de procesamiento asíncrono y tareas programadas.
 *
 * Configura un pool dedicado para el despacho de transacciones de auditoría en Blockchain.
 * La política de rechazo descarta la ejecución inmediata sin bloquear jamás el hilo de la petición HTTP.
 */
@Configuration
@EnableAsync
@EnableScheduling
public class AsyncConfig {

    private static final Logger logger = LoggerFactory.getLogger(AsyncConfig.class);

    @Bean(name = "blockchainTaskExecutor")
    public Executor blockchainTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(500);
        executor.setThreadNamePrefix("BlockchainAsync-");
        
        // CU-0030 Ajuste 2: Se descarta la tarea inmediata si el pool está saturado.
        // NUNCA se utiliza CallerRunsPolicy para evitar retener el hilo de la request HTTP.
        executor.setRejectedExecutionHandler((runnable, exec) -> {
            logger.warn("Cola de tareas Blockchain saturada. Despacho inmediato descartado; el registro permanece en estado PENDING y el scheduler lo procesará.");
        });
        
        executor.initialize();
        return executor;
    }
}
