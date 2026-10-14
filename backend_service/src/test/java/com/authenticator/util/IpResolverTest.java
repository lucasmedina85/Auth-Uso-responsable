package com.authenticator.util;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class IpResolverTest {

    @Test
    public void resolveClientIp_NoTrustedProxy_UsesRemoteAddr() {
        IpResolver resolver = new IpResolver("");
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("203.0.113.195");
        request.addHeader("X-Forwarded-For", "198.51.100.10");

        // Should ignore X-Forwarded-For because remoteAddr is not trusted
        String ip = resolver.resolveClientIp(request);
        assertEquals("203.0.113.195", ip);
    }

    @Test
    public void resolveClientIp_WithTrustedProxy_UsesXForwardedFor() {
        IpResolver resolver = new IpResolver("10.0.0.1, 192.168.1.1");
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.1"); // Trusted proxy
        request.addHeader("X-Forwarded-For", "203.0.113.50, 10.0.0.1");

        String ip = resolver.resolveClientIp(request);
        assertEquals("203.0.113.50", ip);
    }

    @Test
    public void resolveClientIp_Loopback_CleansTo127001() {
        IpResolver resolver = new IpResolver("");
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("0:0:0:0:0:0:0:1");

        String ip = resolver.resolveClientIp(request);
        assertEquals("127.0.0.1", ip);
    }

    @Test
    public void maskIp_MasksLastOctets() {
        assertEquals("198.51.***.***", IpResolver.maskIp("198.51.100.25"));
        assertEquals("127.0.***.***", IpResolver.maskIp("127.0.0.1"));
        assertEquals("unknown", IpResolver.maskIp(null));
    }
}
