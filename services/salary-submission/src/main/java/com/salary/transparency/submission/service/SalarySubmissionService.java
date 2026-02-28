package com.salary.transparency.submission.service;

import com.salary.transparency.submission.dto.SalarySubmissionRequest;
import com.salary.transparency.submission.dto.SalarySubmissionResponse;
import com.salary.transparency.submission.entity.ExperienceLevel;
import com.salary.transparency.submission.entity.SalarySubmission;
import com.salary.transparency.submission.exception.SalarySubmissionNotFoundException;
import com.salary.transparency.submission.repository.SalarySubmissionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
@Slf4j
public class SalarySubmissionService {

    private final SalarySubmissionRepository salarySubmissionRepository;
    private final AnonymizationService anonymizationService;

    /**
     * Create a new salary submission
     */
    @Transactional
    public SalarySubmissionResponse createSubmission(SalarySubmissionRequest request) {
        log.info("Creating new salary submission for company: {}", request.getCompany());

        // Normalize data
        if (request.getCountry() != null) {
            request.setCountry(request.getCountry().toUpperCase());
        }

        // Create entity
        SalarySubmission submission = SalarySubmission.builder()
                .company(request.getCompany())
                .jobTitle(request.getJobTitle())
                .location(request.getLocation())
                .country(request.getCountry())
                .city(request.getCity())
                .yearsOfExperience(request.getYearsOfExperience())
                .experienceLevel(ExperienceLevel.fromYears(request.getYearsOfExperience()))
                .baseSalary(request.getBaseSalary())
                .bonus(request.getBonus() != null ? request.getBonus() : BigDecimal.ZERO)
                .stockOptions(request.getStockOptions() != null ? request.getStockOptions() : BigDecimal.ZERO)
                .otherCompensation(request.getOtherCompensation() != null ? request.getOtherCompensation() : BigDecimal.ZERO)
                .currency(request.getCurrency() != null ? request.getCurrency() : "USD")
                .employmentType(request.getEmploymentType() != null ? request.getEmploymentType() : "Full-time")
                .build();

        // Always apply anonymization for privacy protection
        anonymizationService.anonymize(submission);

        // Save to database
        SalarySubmission savedSubmission = salarySubmissionRepository.save(submission);

        log.info("Salary submission created with ID: {}", savedSubmission.getId());

        return mapToResponse(savedSubmission);
    }

    /**
     * Get salary submission by ID
     */
    @Transactional(readOnly = true)
    public SalarySubmissionResponse getSubmission(Long submissionId) {
        log.info("Fetching salary submission with ID: {}", submissionId);

        SalarySubmission submission = salarySubmissionRepository.findById(submissionId)
                .orElseThrow(() -> new SalarySubmissionNotFoundException(
                        "Salary submission not found with ID: " + submissionId));

        return mapToResponse(submission);
    }

    /**
     * Map entity to response DTO
     */
    private SalarySubmissionResponse mapToResponse(SalarySubmission submission) {
        return SalarySubmissionResponse.builder()
                .id(submission.getId())
                .company(submission.getCompany())
                .jobTitle(submission.getJobTitle())
                .location(submission.getLocation())
                .country(submission.getCountry())
                .city(submission.getCity())
                .yearsOfExperience(submission.getYearsOfExperience())
                .experienceLevel(submission.getExperienceLevel() != null ? submission.getExperienceLevel().name() : null)
                .baseSalary(submission.getBaseSalary())
                .bonus(submission.getBonus())
                .stockOptions(submission.getStockOptions())
                .otherCompensation(submission.getOtherCompensation())
                .totalCompensation(submission.getTotalCompensation())
                .currency(submission.getCurrency())
                .employmentType(submission.getEmploymentType())
                .status(submission.getStatus() != null ? submission.getStatus().name() : "PENDING")
                .createdAt(submission.getCreatedAt())
                .updatedAt(submission.getUpdatedAt())
                .approvedAt(submission.getApprovedAt())
                .build();
    }
}