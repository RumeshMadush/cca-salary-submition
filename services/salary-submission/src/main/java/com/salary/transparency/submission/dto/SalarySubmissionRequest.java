package com.salary.transparency.submission.dto;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalarySubmissionRequest {

    @NotBlank(message = "Company name is required")
    @Size(min = 1, max = 100, message = "Company name must be between 1 and 100 characters")
    private String company;

    @NotBlank(message = "Job title is required")
    @Size(min = 1, max = 100, message = "Job title must be between 1 and 100 characters")
    private String jobTitle;

    @Size(max = 100, message = "Location must be less than 100 characters")
    private String location;

    @NotBlank(message = "Country is required")
    @Size(min = 2, max = 50, message = "Country must be between 2 and 50 characters")
    private String country;

    @Size(max = 50, message = "City must be less than 50 characters")
    private String city;

    @Min(value = 0, message = "Years of experience must be 0 or greater")
    private Integer yearsOfExperience;

    @NotNull(message = "Base salary is required")
    @DecimalMin(value = "0.01", message = "Base salary must be greater than 0")
    @Digits(integer = 10, fraction = 2, message = "Base salary must be a valid amount")
    private BigDecimal baseSalary;

    @DecimalMin(value = "0.00", message = "Bonus must be 0 or greater")
    @Digits(integer = 10, fraction = 2, message = "Bonus must be a valid amount")
    private BigDecimal bonus;

    @DecimalMin(value = "0.00", message = "Stock options must be 0 or greater")
    @Digits(integer = 10, fraction = 2, message = "Stock options must be a valid amount")
    private BigDecimal stockOptions;

    @DecimalMin(value = "0.00", message = "Other compensation must be 0 or greater")
    @Digits(integer = 10, fraction = 2, message = "Other compensation must be a valid amount")
    private BigDecimal otherCompensation;

    @Size(max = 10, message = "Currency must be less than 10 characters")
    private String currency = "USD";

    @Size(max = 20, message = "Employment type must be less than 20 characters")
    private String employmentType = "Full-time";
}
