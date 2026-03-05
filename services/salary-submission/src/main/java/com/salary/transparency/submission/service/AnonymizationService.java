package com.salary.transparency.submission.service;

import com.salary.transparency.submission.entity.SalarySubmission;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Service
@Slf4j
public class AnonymizationService {

    /**
     * Apply anonymization rules to a salary submission entity.
     * This method modifies the entity to protect sensitive information.
     */
    public void anonymize(SalarySubmission submission) {

        log.info("Applying anonymization to salary submission ID: {}", submission.getId());

        // Sanitize text fields
        submission.setCompany(sanitizeText(submission.getCompany()));
        submission.setJobTitle(sanitizeText(submission.getJobTitle()));
        submission.setCity(sanitizeText(submission.getCity()));

        // Remove detailed location completely (keep only city + country)
        submission.setLocation(null);

        // Normalize country to uppercase
        if (submission.getCountry() != null) {
            submission.setCountry(submission.getCountry().toUpperCase().trim());
        }

        // Round salary-related values (privacy protection)
        submission.setBaseSalary(roundDown(submission.getBaseSalary(), 10000));
        submission.setBonus(roundDown(submission.getBonus(), 10000));
        submission.setStockOptions(roundDown(submission.getStockOptions(), 10000));
        submission.setOtherCompensation(roundDown(submission.getOtherCompensation(), 10000));

        // Generalize experience into buckets
        submission.setYearsOfExperience(generalizeExperience(submission.getYearsOfExperience()));

        log.info("Anonymization applied successfully for submission ID: {}", submission.getId());
    }

    /**
     * Sanitize free-text fields to remove possible personal identifiers.
     */
    private String sanitizeText(String input) {
        if (input == null) {
            return null;
        }

        String sanitized = input;

        // Remove emails
        sanitized = sanitized.replaceAll("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-z]{2,}", "");

        // Remove phone numbers
        sanitized = sanitized.replaceAll("\\+?\\d{7,15}", "");

        // Remove URLs
        sanitized = sanitized.replaceAll("https?://\\S+\\s?", "");

        // Remove standalone numbers (street numbers etc.)
        sanitized = sanitized.replaceAll("\\b\\d+\\b", "");

        // Trim extra whitespace
        sanitized = sanitized.trim().replaceAll("\\s{2,}", " ");

        return sanitized;
    }

    /**
     * Round salary down to nearest specified value to prevent fingerprinting.
     */
    private BigDecimal roundDown(BigDecimal value, int nearest) {
        if (value == null || value.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }

        BigDecimal nearestBd = BigDecimal.valueOf(nearest);

        return value.divide(nearestBd, 0, RoundingMode.DOWN)
                .multiply(nearestBd);
    }

    /**
     * Generalize years of experience into broader buckets.
     * <p>
     * 0–1  -> 1
     * 2–3  -> 3
     * 4–6  -> 5
     * 7–10 -> 8
     * 11+  -> 12
     */
    private Integer generalizeExperience(Integer years) {
        if (years == null) {
            return null;
        }

        if (years <= 1) {
            return 1;
        } else if (years <= 3) {
            return 3;
        } else if (years <= 6) {
            return 5;
        } else if (years <= 10) {
            return 8;
        } else {
            return 12;
        }
    }
}