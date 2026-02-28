package com.identity.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * Response body for POST /auth/signup
 */
@Getter
@AllArgsConstructor
public class SignupResponse {
    private Long userId;
    private String username;
    private String message;
}
