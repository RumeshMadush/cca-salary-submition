package com.identity.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * Response body for POST /auth/login
 */
@Getter
@AllArgsConstructor
public class AuthServiceLoginResponse {
    private String token;
    private Long userId;
    private String username;
}

