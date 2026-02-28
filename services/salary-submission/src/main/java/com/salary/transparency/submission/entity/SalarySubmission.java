package com.salary.transparency.submission.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "salary_submissions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalarySubmission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company", nullable = false, length = 100)
    private String company;

    @Column(name = "job_title", nullable = false, length = 100)
    private String jobTitle;

    @Column(name = "location", length = 100)
    private String location;

    @Column(name = "country", length = 50)
    private String country;

    @Column(name = "city", length = 50)
    private String city;

    @Column(name = "years_of_experience")
    private Integer yearsOfExperience;

    @Enumerated(EnumType.STRING)
    @Column(name = "experience_level", length = 20)
    private ExperienceLevel experienceLevel;

    @Column(name = "base_salary", nullable = false, precision = 12, scale = 2)
    private BigDecimal baseSalary;

    @Column(name = "bonus", precision = 12, scale = 2)
    @Builder.Default
    private BigDecimal bonus = BigDecimal.ZERO;

    @Column(name = "stock_options", precision = 12, scale = 2)
    @Builder.Default
    private BigDecimal stockOptions = BigDecimal.ZERO;

    @Column(name = "other_compensation", precision = 12, scale = 2)
    @Builder.Default
    private BigDecimal otherCompensation = BigDecimal.ZERO;

    // Generated column in DB
    @Column(name = "total_compensation", insertable = false, updatable = false)
    private BigDecimal totalCompensation;

    @Column(name = "currency", length = 10)
    @Builder.Default
    private String currency = "USD";

    @Column(name = "employment_type", length = 20)
    @Builder.Default
    private String employmentType = "Full-time";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    @Builder.Default
    private SalaryStatus status = SalaryStatus.PENDING;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", insertable = false)
    private LocalDateTime updatedAt;

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;
}