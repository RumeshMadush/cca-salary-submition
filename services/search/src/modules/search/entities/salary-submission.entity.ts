import { Entity, Column, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'salary_submissions', schema: 'salary' })
export class SalarySubmission {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  company: string;

  @Column({ name: 'job_title' })
  jobTitle: string;

  @Column({ nullable: true })
  location: string;

  @Column({ nullable: true })
  country: string;

  @Column({ nullable: true })
  city: string;

  @Column({ name: 'years_of_experience', nullable: true })
  yearsOfExperience: number;

  @Column({ name: 'experience_level', nullable: true })
  experienceLevel: string;

  @Column({ name: 'base_salary', type: 'decimal' })
  baseSalary: number;

  @Column({ type: 'decimal', default: 0 })
  bonus: number;

  @Column({ name: 'stock_options', type: 'decimal', default: 0 })
  stockOptions: number;

  @Column({ name: 'other_compensation', type: 'decimal', default: 0 })
  otherCompensation: number;

  @Column({ name: 'total_compensation', type: 'decimal', nullable: true, insert: false, update: false })
  totalCompensation: number;

  @Column({ default: 'USD' })
  currency: string;

  @Column({ name: 'employment_type', nullable: true })
  employmentType: string;

  @Column({ default: false })
  anonymize: boolean;

  @Column({ default: 'PENDING' })
  status: string;

  @Column({ name: 'created_at', nullable: true })
  createdAt: Date;

  @Column({ name: 'approved_at', nullable: true })
  approvedAt: Date;
}
