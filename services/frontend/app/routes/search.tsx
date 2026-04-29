import { useState, useEffect } from "react";
import { useSearchParams, Link } from "react-router";
import { Button } from "~/components/ui/Button";
import { Input } from "~/components/ui/Input";
import { Badge } from "~/components/ui/Badge";
import { Spinner } from "~/components/ui/Spinner";
import { Alert } from "~/components/ui/Alert";
import { api } from "~/lib/api";
import type { SalaryRecord } from "~/types";

export function meta() {
  return [{ title: "Search | Salary Portal" }];
}

const EXP_OPTIONS = ["", "ENTRY", "JUNIOR", "MID", "SENIOR", "LEAD"];
const CURRENCY_OPTIONS = ["", "USD", "LKR", "EUR", "GBP", "AUD", "INR"];

interface SearchResponse {
  data: {
    results: SalaryRecord[];
    pagination: { total: number; page: number; limit: number; totalPages: number };
  };
}

function ResultCard({ record }: { record: SalaryRecord }) {
  const comp = Number(record.totalCompensation ?? record.baseSalary);
  return (
    <div className="bg-slate-900 rounded-xl border border-slate-800 px-5 py-4 hover:border-slate-700 transition-colors">
      <div className="flex items-start justify-between mb-3">
        <div>
          <p className="font-semibold text-white">{record.jobTitle}</p>
          <p className="text-sm text-slate-400 mt-0.5">
            {record.anonymize ? "Anonymous" : record.company}
            {record.country ? ` · ${record.country}` : ""}
          </p>
        </div>
        <div className="text-right">
          <p className="font-bold text-indigo-400">
            {record.currency} {comp > 0 ? comp.toLocaleString() : "—"}
          </p>
          <p className="text-xs text-slate-500 mt-0.5">total comp</p>
        </div>
      </div>
      <div className="flex flex-wrap gap-2 mb-3">
        {record.experienceLevel && (
          <Badge variant="indigo">{record.experienceLevel}</Badge>
        )}
        {record.yearsOfExperience !== undefined && record.yearsOfExperience !== null && (
          <Badge variant="gray">{record.yearsOfExperience} yrs exp</Badge>
        )}
        {record.employmentType && (
          <Badge variant="gray">{record.employmentType}</Badge>
        )}
      </div>
      <div className="flex items-center justify-between">
        <span className="text-xs text-slate-600">
          {record.createdAt ? new Date(record.createdAt).toLocaleDateString() : ""}
        </span>
        <Link
          to={`/salary/${record.id}`}
          className="text-xs text-indigo-400 hover:text-indigo-300 font-medium"
        >
          View & Vote →
        </Link>
      </div>
    </div>
  );
}

export default function Search() {
  const [searchParams, setSearchParams] = useSearchParams();

  const [q, setQ] = useState(searchParams.get("q") ?? "");
  const [country, setCountry] = useState(searchParams.get("country") ?? "");
  const [experienceLevel, setExperienceLevel] = useState(searchParams.get("experienceLevel") ?? "");
  const [currency, setCurrency] = useState(searchParams.get("currency") ?? "");
  const [minSalary, setMinSalary] = useState(searchParams.get("minSalary") ?? "");
  const [maxSalary, setMaxSalary] = useState(searchParams.get("maxSalary") ?? "");
  const [page, setPage] = useState(1);

  const [results, setResults] = useState<SalaryRecord[]>([]);
  const [pagination, setPagination] = useState({ total: 0, totalPages: 0 });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  function buildQuery(pg = page) {
    const p = new URLSearchParams();
    if (q) p.set("q", q);
    if (country) p.set("country", country);
    if (experienceLevel) p.set("experienceLevel", experienceLevel);
    if (currency) p.set("currency", currency);
    if (minSalary) p.set("minSalary", minSalary);
    if (maxSalary) p.set("maxSalary", maxSalary);
    p.set("page", String(pg));
    p.set("limit", "20");
    return p.toString();
  }

  function doSearch(pg = 1) {
    setLoading(true);
    setError("");
    setPage(pg);
    const qs = buildQuery(pg);
    setSearchParams(Object.fromEntries(new URLSearchParams(qs)));
    api
      .get<SearchResponse>(`/api/search?${qs}`)
      .then((res) => {
        setResults(res?.data?.results ?? []);
        setPagination({
          total: res?.data?.pagination?.total ?? 0,
          totalPages: res?.data?.pagination?.totalPages ?? 0,
        });
      })
      .catch((err) => setError(err.message ?? "Search failed"))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    doSearch(1);
  }, []);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    doSearch(1);
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Search Salaries</h1>
        <p className="text-slate-500 text-sm mt-0.5">Filter approved salary records</p>
      </div>

      {/* Filters */}
      <form
        onSubmit={handleSubmit}
        className="bg-slate-900 rounded-2xl border border-slate-800 px-6 py-5"
      >
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
          <Input
            label="Keyword"
            placeholder="Role, technology…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          <Input
            label="Country"
            placeholder="e.g. Sri Lanka"
            value={country}
            onChange={(e) => setCountry(e.target.value)}
          />
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Experience Level
            </label>
            <select
              value={experienceLevel}
              onChange={(e) => setExperienceLevel(e.target.value)}
              className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2.5 text-sm text-slate-100 outline-none focus:ring-2 focus:ring-indigo-500"
            >
              {EXP_OPTIONS.map((o) => (
                <option key={o} value={o}>
                  {o || "All levels"}
                </option>
              ))}
            </select>
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Currency
            </label>
            <select
              value={currency}
              onChange={(e) => setCurrency(e.target.value)}
              className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2.5 text-sm text-slate-100 outline-none focus:ring-2 focus:ring-indigo-500"
            >
              {CURRENCY_OPTIONS.map((o) => (
                <option key={o} value={o}>
                  {o || "All currencies"}
                </option>
              ))}
            </select>
          </div>
          <Input
            label="Min Salary"
            type="number"
            placeholder="e.g. 50000"
            value={minSalary}
            onChange={(e) => setMinSalary(e.target.value)}
          />
          <Input
            label="Max Salary"
            type="number"
            placeholder="e.g. 200000"
            value={maxSalary}
            onChange={(e) => setMaxSalary(e.target.value)}
          />
        </div>
        <div className="flex gap-3">
          <Button type="submit" loading={loading}>
            Search
          </Button>
          <Button
            type="button"
            variant="secondary"
            onClick={() => {
              setQ(""); setCountry(""); setExperienceLevel("");
              setCurrency(""); setMinSalary(""); setMaxSalary("");
            }}
          >
            Clear
          </Button>
        </div>
      </form>

      {/* Results */}
      {loading ? (
        <div className="flex justify-center py-16">
          <Spinner size="lg" />
        </div>
      ) : error ? (
        <Alert message={error} />
      ) : (
        <>
          {results.length > 0 && (
            <p className="text-xs text-slate-500">{pagination.total} result/s found</p>
          )}
          <div className="flex flex-col gap-3">
            {results.length === 0 ? (
              <p className="text-center text-slate-500 py-16">No results. Try adjusting your filters.</p>
            ) : (
              results.map((r) => <ResultCard key={r.id} record={r} />)
            )}
          </div>
          {pagination.totalPages > 1 && (
            <div className="flex items-center justify-center gap-3">
              <Button
                variant="secondary"
                size="sm"
                disabled={page <= 1}
                onClick={() => doSearch(page - 1)}
              >
                ← Prev
              </Button>
              <span className="text-sm text-slate-400">
                Page {page} of {pagination.totalPages}
              </span>
              <Button
                variant="secondary"
                size="sm"
                disabled={page >= pagination.totalPages}
                onClick={() => doSearch(page + 1)}
              >
                Next →
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
