package com.identity.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * Response body for GET /auth/validate
 */
@Getter
@AllArgsConstructor
public class ValidateResponse {
    private Long userId;
}
