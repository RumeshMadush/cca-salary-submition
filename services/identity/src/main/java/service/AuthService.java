package com.identity.service;

import com.identity.dto.*;
import com.identity.model.User;
import com.identity.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;

/**
 * Business logic for signup, login, and token validation.
 */
@Service
public class AuthService {

    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final BCryptPasswordEncoder passwordEncoder;

    public AuthService(UserRepository userRepository, JwtService jwtService) {
        this.userRepository = userRepository;
        this.jwtService = jwtService;
        this.passwordEncoder = new BCryptPasswordEncoder();  
    }

    /**
     * Register a new user.
     */
    public SignupResponse signup(SignupRequest request) {

        // Check for duplicate email
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Email is already registered");
        }

        // Check for duplicate username
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Username is already taken");
        }

        User user = new User();
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());

        // Hash password with BCrypt 
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));

        user.setFirstName(request.getFirstName());
        user.setLastName(request.getLastName());
        user.setIsActive(true);

        User saved = userRepository.save(user);

        return new SignupResponse(saved.getId(), saved.getUsername(), "Signup successful");
    }

    /**
     * Authenticate a user and return a JWT.
     * Also updates the last_login timestamp.
     */
    public AuthServiceLoginResponse login(LoginRequest request) {

        // Find by email or username
        User user = userRepository.findByEmailOrUsername(request.getUsernameOrEmail())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.UNAUTHORIZED, "Invalid username, email, or password"));

        // Check account is active
        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED, "Account is deactivated");
        }

        // Compare raw password against BCrypt hash 
        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED, "Invalid username, email, or password");
        }

        // Update last_login timestamp 
        user.setLastLogin(LocalDateTime.now());
        userRepository.save(user);

        // Generate JWT 
        String token = jwtService.generateToken(user.getId());

        return new AuthServiceLoginResponse(token, user.getId(), user.getUsername());
    }

    /**
     * Validate a JWT token and return the userId it contains.
     */
    public Long validateToken(String token) {
        try {
            return jwtService.extractUserId(token);
        } catch (Exception e) {
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED, "Invalid or expired token");
        }
    }
}
