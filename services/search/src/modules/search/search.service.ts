import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SalarySubmission } from './entities/salary-submission.entity';
import { SearchQueryDto } from './dto/search-query.dto';

@Injectable()
export class SearchService {
  constructor(
    @InjectRepository(SalarySubmission)
    private readonly submissionRepo: Repository<SalarySubmission>,
  ) {}

  async search(query: SearchQueryDto) {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, 100);
    const offset = (page - 1) * limit;

    const qb = this.submissionRepo.createQueryBuilder('s');
    qb.where("s.status = 'APPROVED'");

    if (query.q) {
      qb.andWhere(
        `to_tsvector('english', COALESCE(s.company, '') || ' ' || COALESCE(s.job_title, '') || ' ' || COALESCE(s.country, '')) @@ plainto_tsquery('english', :q)`,
        { q: query.q },
      );
    }

    if (query.company) {
      qb.andWhere('s.anonymize = false');
      qb.andWhere('LOWER(s.company) LIKE LOWER(:company)', {
        company: `%${query.company}%`,
      });
    }

    if (query.country) {
      qb.andWhere('LOWER(s.country) = LOWER(:country)', {
        country: query.country,
      });
    }

    if (query.experienceLevel) {
      qb.andWhere('s.experience_level = :experienceLevel', {
        experienceLevel: query.experienceLevel.toUpperCase(),
      });
    }

    if (query.minSalary !== undefined) {
      qb.andWhere('s.total_compensation >= :minSalary', {
        minSalary: query.minSalary,
      });
    }

    if (query.maxSalary !== undefined) {
      qb.andWhere('s.total_compensation <= :maxSalary', {
        maxSalary: query.maxSalary,
      });
    }

    if (query.currency) {
      qb.andWhere('UPPER(s.currency) = UPPER(:currency)', {
        currency: query.currency,
      });
    }

    qb.orderBy('s.created_at', 'DESC').skip(offset).take(limit);

    const [results, total] = await qb.getManyAndCount();

    const masked = results.map((r) =>
      r.anonymize ? { ...r, company: 'Anonymous' } : r,
    );

    return {
      results: masked,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
