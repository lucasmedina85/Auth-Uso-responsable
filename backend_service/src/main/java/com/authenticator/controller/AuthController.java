package com.authenticator.controller;

import com.authenticator.dto.AuthResponse;
import com.authenticator.dto.LoginRequest;
import com.authenticator.dto.RefreshRequest;
import com.authenticator.dto.RegisterRequest;
import com.authenticator.service.AuthService;
import com.authenticator.service.RateLimitingService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;
    private final RateLimitingService rateLimitingService;
    
    @Value("${app.trust-x-forwarded-for:false}")
    private boolean trustXForwardedFor;

    public AuthController(AuthService authService, RateLimitingService rateLimitingService) {
        this.authService = authService;
        this.rateLimitingService = rateLimitingService;
    }

    private String getClientIP(HttpServletRequest request) {
        if (trustXForwardedFor) {
            String xfHeader = request.getHeader("X-Forwarded-For");
            if (xfHeader != null && !xfHeader.isEmpty()) {
                return xfHeader.split(",")[0].trim();
            }
        }
        return request.getRemoteAddr();
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request) {
        authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).build();
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        String ip = getClientIP(httpRequest);
        if (!rateLimitingService.tryConsume(ip)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body("Rate limit exceeded");
        }

        try {
            AuthResponse response = authService.login(request);
            return ResponseEntity.ok(response);
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(e.getMessage());
        }
    }

    @PostMapping("/refresh")
    public ResponseEntity<?> refresh(@Valid @RequestBody RefreshRequest request) {
        try {
            AuthResponse response = authService.refresh(request);
            return ResponseEntity.ok(response);
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(e.getMessage());
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<?> logout(@RequestHeader(value = "Authorization", required = false) String authHeader,
                                    @RequestBody(required = false) RefreshRequest request) {
        String accessToken = null;
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            accessToken = authHeader.substring(7);
        }
        String refreshToken = request != null ? request.getRefreshToken() : null;
        authService.logout(accessToken, refreshToken);
        return ResponseEntity.ok().build();
    }
}
