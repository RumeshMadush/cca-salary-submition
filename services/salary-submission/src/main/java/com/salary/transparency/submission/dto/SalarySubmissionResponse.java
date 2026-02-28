package com.salary.transparency.submission.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalarySubmissionResponse {
    private Long id;
    private String company;
    private String jobTitle;
    private String location;
    private String country;
    private String city;
    private Integer yearsOfExperience;
    private String experienceLevel;
    private BigDecimal baseSalary;
    private BigDecimal bonus;
    private BigDecimal stockOptions;
    private BigDecimal otherCompensation;
    private BigDecimal totalCompensation;
    private String currency;
    private String employmentType;
    private String status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime approvedAt;
}
