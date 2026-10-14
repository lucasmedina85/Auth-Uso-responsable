package com.authenticator.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class JwksControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    public void getJwks_ReturnsPublicRsaKeys_WithoutPrivateKeys() throws Exception {
        mockMvc.perform(get("/.well-known/jwks.json")
                .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.keys", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$.keys[0].kty", is("RSA")))
                .andExpect(jsonPath("$.keys[0].use", is("sig")))
                .andExpect(jsonPath("$.keys[0].alg", is("RS256")))
                .andExpect(jsonPath("$.keys[0].kid", notNullValue()))
                .andExpect(jsonPath("$.keys[0].n", notNullValue()))
                .andExpect(jsonPath("$.keys[0].e", notNullValue()))
                // Verificación estricta de seguridad: NUNCA publicar campos de clave privada
                .andExpect(jsonPath("$.keys[0].d").doesNotExist())
                .andExpect(jsonPath("$.keys[0].p").doesNotExist())
                .andExpect(jsonPath("$.keys[0].q").doesNotExist())
                .andExpect(jsonPath("$.keys[0].dp").doesNotExist())
                .andExpect(jsonPath("$.keys[0].dq").doesNotExist())
                .andExpect(jsonPath("$.keys[0].qi").doesNotExist());
    }
}
