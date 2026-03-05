package com.salary.transparency.submission.controller;

import com.salary.transparency.submission.dto.HealthResponse;
import com.salary.transparency.submission.dto.SalarySubmissionRequest;
import com.salary.transparency.submission.dto.SalarySubmissionResponse;
import com.salary.transparency.submission.service.SalarySubmissionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@RestController
@RequestMapping("/api/salary-submissions")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Salary Submissions", description = "Salary submission endpoints")
public class SalarySubmissionController {

    private final SalarySubmissionService salarySubmissionService;

    @PostMapping
    @Operation(
            summary = "Create new salary submission",
            description = "Submit anonymous salary data (no authentication required)"
    )
    @ApiResponse(
            responseCode = "201",
            description = "Salary submission created successfully",
            content = @Content(schema = @Schema(implementation = SalarySubmissionResponse.class))
    )
    public ResponseEntity<SalarySubmissionResponse> createSubmission(
            @Valid @RequestBody SalarySubmissionRequest request) {

        log.info("Received salary submission request for company: {}", request.getCompany());

        SalarySubmissionResponse response = salarySubmissionService.createSubmission(request);

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/{submissionId}")
    @Operation(
            summary = "Get salary submission by ID",
            description = "Retrieve a specific salary submission (for testing/admin purposes)"
    )
    public ResponseEntity<SalarySubmissionResponse> getSubmission(
            @PathVariable Long submissionId) {

        log.info("Received request for salary submission ID: {}", submissionId);

        SalarySubmissionResponse response = salarySubmissionService.getSubmission(submissionId);

        return ResponseEntity.ok(response);
    }

    @GetMapping("/health")
    @Operation(
            summary = "Health check",
            description = "Service health check for Kubernetes probes"
    )
    public ResponseEntity<HealthResponse> healthCheck() {
        HealthResponse response = HealthResponse.builder()
                .status("healthy")
                .service("salary-submission")
                .timestamp(LocalDateTime.now())
                .build();

        return ResponseEntity.ok(response);
    }
}
