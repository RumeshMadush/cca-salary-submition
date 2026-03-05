package com.salary.transparency.submission.repository;

import com.salary.transparency.submission.entity.SalarySubmission;
import com.salary.transparency.submission.entity.SalaryStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SalarySubmissionRepository extends JpaRepository<SalarySubmission, Long> {

    // Find all pending submissions
    List<SalarySubmission> findByStatus(SalaryStatus status);

    // Find submissions by company
    List<SalarySubmission> findByCompany(String company);

    // Find submissions by country
    List<SalarySubmission> findByCountry(String country);

    // Count submissions by status
    long countByStatus(SalaryStatus status);
}
