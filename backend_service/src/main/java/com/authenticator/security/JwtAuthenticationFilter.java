package com.authenticator.security;

import com.authenticator.domain.TrustedDevice;
import com.authenticator.domain.TrustedDeviceStatus;
import com.authenticator.repository.RevokedTokenRepository;
import com.authenticator.repository.TrustedDeviceRepository;
import com.authenticator.service.DeviceService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Optional;
import java.util.UUID;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final RevocationStore revocationStore;
    private final RevokedTokenRepository revokedTokenRepository;
    private final TrustedDeviceRepository trustedDeviceRepository;
    private final DeviceService deviceService;

    public JwtAuthenticationFilter(JwtUtil jwtUtil,
                                   RevocationStore revocationStore,
                                   RevokedTokenRepository revokedTokenRepository,
                                   TrustedDeviceRepository trustedDeviceRepository,
                                   DeviceService deviceService) {
        this.jwtUtil = jwtUtil;
        this.revocationStore = revocationStore;
        this.revokedTokenRepository = revokedTokenRepository;
        this.trustedDeviceRepository = trustedDeviceRepository;
        this.deviceService = deviceService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        try {
            String jwt = parseJwt(request);
            if (jwt != null) {
                var claims = jwtUtil.validateTokenAndGetClaims(jwt);
                String jti = claims.getId();
                
                boolean isRevoked = false;
                try {
                    isRevoked = revocationStore.isRevoked(jti);
                } catch (Exception e) {
                    // Modo degradado: fallo en store externo, fallback a base de datos
                    isRevoked = revokedTokenRepository.existsById(jti);
                }

                if (isRevoked) {
                    response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Token revoked");
                    return;
                }
                String userId = claims.getSubject();

                // CU-0035 / CU-0040: Verificación de revocación efectiva de dispositivo por request.
                // Costo y rendimiento:
                // - Se ejecuta solo si la cabecera 'X-Device-Id' está presente (retrocompatibilidad garantizada).
                // - Utiliza TrustedDeviceRepository.findByUserIdAndDeviceHash respaldado por el índice único
                //   compuesto 'uq_trusted_device_user_hash' (user_id, device_hash), resultando en una búsqueda O(1)
                //   de latencia despreciable (<1ms).
                String deviceIdHeader = request.getHeader("X-Device-Id");
                if (StringUtils.hasText(deviceIdHeader)) {
                    try {
                        UUID uId = UUID.fromString(userId);
                        String deviceHash = deviceService.computeDeviceHash(deviceIdHeader);
                        Optional<TrustedDevice> deviceOpt = trustedDeviceRepository.findByUserIdAndDeviceHash(uId, deviceHash);
                        if (deviceOpt.isPresent() && deviceOpt.get().getStatus() == TrustedDeviceStatus.REVOKED) {
                            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                            response.setContentType("application/json;charset=UTF-8");
                            response.getWriter().write("{\"error\":\"DEVICE_REVOKED\",\"message\":\"Dispositivo revocado\"}");
                            return;
                        }
                    } catch (IllegalArgumentException e) {
                        // userId no es un UUID válido (ej. tokens técnicos/servicios) o deviceId inválido;
                        // se ignora la verificación de dispositivo para no interrumpir flujos no asociados a usuarios móviles.
                    }
                }

                String role = claims.get("role", String.class);
                java.util.List<org.springframework.security.core.authority.SimpleGrantedAuthority> authorities = new java.util.ArrayList<>();
                if (role != null && !role.trim().isEmpty()) {
                    authorities.add(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_" + role.trim().toUpperCase()));
                } else {
                    authorities.add(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_USER"));
                }

                UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                        userId, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        } catch (Exception e) {
            // Cannot set authentication
        }

        filterChain.doFilter(request, response);
    }

    private String parseJwt(HttpServletRequest request) {
        String headerAuth = request.getHeader("Authorization");
        if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
            return headerAuth.substring(7);
        }
        return null;
    }
}
