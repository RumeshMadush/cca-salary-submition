package com.salary.transparency.submission.entity;

public enum ExperienceLevel {
    ENTRY,    // 0-1 years
    JUNIOR,   // 2-3 years
    MID,      // 4-6 years
    SENIOR,   // 7-10 years
    LEAD;     // 11+ years

    /**
     * Convert years of experience to experience level
     */
    public static ExperienceLevel fromYears(Integer years) {
        if (years == null) {
            return null;
        }
        
        if (years <= 1) {
            return ENTRY;
        } else if (years <= 3) {
            return JUNIOR;
        } else if (years <= 6) {
            return MID;
        } else if (years <= 10) {
            return SENIOR;
        } else {
            return LEAD;
        }
    }
}
