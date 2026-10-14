package com.authenticator.service;

import com.authenticator.domain.BlacklistedDni;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.TokenExchangeRequest;
import com.authenticator.repository.BlacklistedDniRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class OAuthHardRulesTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BlacklistedDniRepository blacklistedDniRepository;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;
    private String userToken;
    private final String dniHash = "hard-rule-dni-hash-xyz";
    private final PasswordEncoder passwordEncoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();

    @BeforeEach
    public void setUp() {
        blacklistedDniRepository.deleteAll();

        testUser = userRepository.findByEmail("oauth_hardrules_user@sip.gob.ar")
                .orElseGet(() -> {
                    User u = new User();
                    u.setEmail("oauth_hardrules_user@sip.gob.ar");
                    u.setPasswordHash(passwordEncoder.encode("Password10Chars!"));
                    u.setStatus(UserStatus.LOCALLY_VERIFIED);
                    u.setDniHash(dniHash);
                    u.setVerifiedAt(LocalDateTime.now());
                    return userRepository.save(u);
                });

        testUser.setStatus(UserStatus.LOCALLY_VERIFIED);
        testUser.setDniHash(dniHash);
        testUser.setLockedUntil(null);
        userRepository.save(testUser);

        userToken = jwtUtil.generateAccessToken(testUser.getId().toString(), "USER");
    }

    @AfterEach
    public void tearDown() {
        blacklistedDniRepository.deleteAll();
    }

    private TokenExchangeRequest createExchangeRequest() {
        TokenExchangeRequest req = new TokenExchangeRequest();
        req.setClientId("sandbox-client");
        req.setRedirectUri("https://sandbox.tercero.com/callback");
        req.setState("state123");
        req.setNonce("nonce123");
        req.setCodeChallenge("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
        req.setCodeChallengeMethod("S256");
        req.setScope("openid age_verification");
        req.setConsentGiven(true);
        return req;
    }

    @Test
    public void processTokenExchange_WhenDniBlacklisted_Returns403Forbidden() throws Exception {
        BlacklistedDni blacklisted = new BlacklistedDni();
        blacklisted.setDniHash(dniHash);
        blacklisted.setReason("ALERTA_FRAUDE_IDENTIDAD");
        blacklisted.setCreatedAt(LocalDateTime.now());
        blacklistedDniRepository.save(blacklisted);

        TokenExchangeRequest req = createExchangeRequest();

        mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    @Test
    public void processTokenExchange_WhenUserLockedOut_Returns403Forbidden() throws Exception {
        testUser.setLockedUntil(LocalDateTime.now().plusHours(2));
        userRepository.save(testUser);

        TokenExchangeRequest req = createExchangeRequest();

        mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }
}
