package com.authenticator.security;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertThrows;

public class JwtUtilTest {

    @Test
    public void testShortSecretThrowsException() {
        assertThrows(IllegalArgumentException.class, () -> new JwtUtil("short", 900000));
    }

    @Test
    public void testEmptySecretThrowsException() {
        assertThrows(IllegalArgumentException.class, () -> new JwtUtil("", 900000));
    }

    @Test
    public void testValidSecretSucceeds() {
        new JwtUtil("this-is-a-valid-secret-that-is-at-least-32-bytes-long-for-hs256!", 900000);
    }
}
