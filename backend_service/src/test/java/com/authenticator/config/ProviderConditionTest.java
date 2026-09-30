package com.authenticator.config;

import com.authenticator.service.DiditVerificationProvider;
import com.authenticator.service.IdentityVerificationProvider;
import com.authenticator.service.MockVerificationProvider;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import com.authenticator.AuthenticatorApplication;

import static org.assertj.core.api.Assertions.assertThat;

public class ProviderConditionTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(AuthenticatorApplication.class, MockVerificationProvider.class, DiditVerificationProvider.class);

    @Test
    public void testMockProviderLoadedByDefault() {
        contextRunner.withPropertyValues("spring.profiles.active=dev", "app.jwt.secret=dGhpcy1pcy1hLWR1bW15LXNlY3JldC1rZXktZm9yLWRldmVsb3BtZW50LW9ubHktdGhhdC1tdXN0LWJlLXJlcGxhY2VkLWF0LWxlYXN0LTI1Ni1iaXRz").run(context -> {
            assertThat(context).hasSingleBean(IdentityVerificationProvider.class);
            assertThat(context).getBean(IdentityVerificationProvider.class)
                    .isInstanceOf(MockVerificationProvider.class);
        });
    }

    @Test
    public void testDiditProviderLoadedWhenPropertyIsDidit() {
        contextRunner.withPropertyValues("spring.profiles.active=dev", "app.identity-provider=didit", "app.jwt.secret=dGhpcy1pcy1hLWR1bW15LXNlY3JldC1rZXktZm9yLWRldmVsb3BtZW50LW9ubHktdGhhdC1tdXN0LWJlLXJlcGxhY2VkLWF0LWxlYXN0LTI1Ni1iaXRz").run(context -> {
            assertThat(context).hasSingleBean(IdentityVerificationProvider.class);
            assertThat(context).getBean(IdentityVerificationProvider.class)
                    .isInstanceOf(DiditVerificationProvider.class);
        });
    }
}
