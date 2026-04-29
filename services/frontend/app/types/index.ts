export interface User {
  id: string;
  username: string;
  email: string;
}

export interface SalaryRecord {
  id: number;
  company: string;
  jobTitle: string;
  location?: string;
  country?: string;
  city?: string;
  yearsOfExperience?: number;
  experienceLevel?: string;
  baseSalary: number;
  bonus?: number;
  stockOptions?: number;
  otherCompensation?: number;
  totalCompensation?: number;
  currency: string;
  employmentType?: string;
  anonymize?: boolean;
  status: string;
  createdAt?: string;
  updatedAt?: string;
  approvedAt?: string;
}

export interface SalaryStats {
  sampleSize: number;
  minSalary: number;
  maxSalary: number;
  averageSalary: number;
  medianSalary: number;
  percentile25: number;
  percentile75: number;
  percentile90: number;
  currency?: string;
  filters?: Record<string, string>;
}

export interface ApiError {
  message: string;
  status: number;
}
