package com.salary.transparency.submission;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@OpenAPIDefinition(
        info = @Info(
                title = "Salary Submission Service API",
                version = "1.0.0",
                description = "Microservice for anonymous salary data submissions"
        )
)
public class SalarySubmissionServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(SalarySubmissionServiceApplication.class, args);
    }
}