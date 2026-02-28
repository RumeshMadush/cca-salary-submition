package com.identity.controller;

import com.identity.dto.*;
import com.identity.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * POST /auth/signup 
     *
     * Body: { "username": "adeesha", "email": "adeesha@test.com", "password": "Test123" }
     * Optional: "firstName", "lastName"
     */
    @PostMapping("/signup")
    public ResponseEntity<SignupResponse> signup(@Valid @RequestBody SignupRequest request) {
        SignupResponse response = authService.signup(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * POST /auth/login 
     *
     * Body: { "usernameOrEmail": "adeesha@test.com", "password": "Test123" }
     */
    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        AuthServiceLoginResponse response = authService.login(request);
        LoginResponse loginResponse = new LoginResponse(response.getUserId(),response.getUsername());
        return ResponseEntity.ok()
                .header("Authorization", "Bearer " + response.getToken())
                .body(loginResponse);
    }

    /**
     * GET /auth/validate 
     */
    @GetMapping("/validate")
    public ResponseEntity<ValidateResponse> validate(
            @RequestHeader(value = "Authorization", required = false) String authHeader) {

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String token = authHeader.substring(7);
        Long userId = authService.validateToken(token);

        return ResponseEntity.ok(new ValidateResponse(userId));
    }
}
