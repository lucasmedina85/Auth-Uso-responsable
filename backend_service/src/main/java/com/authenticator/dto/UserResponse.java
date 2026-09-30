package com.authenticator.dto;

import com.authenticator.domain.UserStatus;
import lombok.Data;

@Data
public class UserResponse {
    private String id;
    private String email;
    private UserStatus status;
}
