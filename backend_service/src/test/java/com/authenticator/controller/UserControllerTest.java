package com.authenticator.controller;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;
import org.springframework.security.test.context.support.WithMockUser;
import org.junit.jupiter.api.BeforeEach;
import com.authenticator.security.JwtUtil;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.repository.RefreshTokenRepository;
import com.authenticator.repository.UserRepository;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
public class UserControllerTest {

    @Autowired
    private JwtUtil jwtUtil;
    
    @Autowired
    private MockMvc mockMvc;

    @Test
    public void getMe_NoToken_Returns401() throws Exception {
        mockMvc.perform(get("/users/me"))
                .andExpect(status().isUnauthorized());
    }
}
