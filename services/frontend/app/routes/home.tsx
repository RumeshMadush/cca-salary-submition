import { useState, useEffect, useMemo } from "react";
import { Link, useNavigate } from "react-router";
import { Button } from "~/components/ui/Button";
import { Input } from "~/components/ui/Input";
import { Spinner } from "~/components/ui/Spinner";
import { Alert } from "~/components/ui/Alert";
import { Badge } from "~/components/ui/Badge";
import { api } from "~/lib/api";
import type { SalaryRecord } from "~/types";

export function meta() {
  return [{ title: "Dashboard | Salary Portal" }];
}

function SalaryCard({ record }: { record: SalaryRecord }) {
  const comp = Number(record.totalCompensation ?? record.baseSalary);
  return (
    <div className="border-b border-slate-800/60 last:border-0 py-5 px-6 hover:bg-slate-800/20 transition-colors">
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-x-6 gap-y-3 text-sm">
        <div>
          <span className="text-slate-500 block text-xs mb-0.5">Total Compensation</span>
          <span className="font-semibold text-white">
            {record.currency}{" "}
            {comp > 0 ? comp.toLocaleString() : "—"}
          </span>
        </div>
        {record.yearsOfExperience !== undefined && record.yearsOfExperience !== null && (
          <div>
            <span className="text-slate-500 block text-xs mb-0.5">Work Experience</span>
            <span className="text-slate-200">{record.yearsOfExperience} year/s</span>
          </div>
        )}
        {record.experienceLevel && (
          <div>
            <span className="text-slate-500 block text-xs mb-0.5">Level</span>
            <Badge variant="indigo">{record.experienceLevel}</Badge>
          </div>
        )}
        {record.country && (
          <div>
            <span className="text-slate-500 block text-xs mb-0.5">Country</span>
            <span className="text-slate-200">{record.country}</span>
          </div>
        )}
        {record.anonymize ? (
          <div>
            <span className="text-slate-500 block text-xs mb-0.5">Company</span>
            <span className="text-slate-500 italic">Anonymous</span>
          </div>
        ) : record.company ? (
          <div>
            <span className="text-slate-500 block text-xs mb-0.5">Company</span>
            <span className="text-slate-200">{record.company}</span>
          </div>
        ) : null}
        {record.employmentType && (
          <div>
            <span className="text-slate-500 block text-xs mb-0.5">Employment</span>
            <span className="text-slate-200">{record.employmentType}</span>
          </div>
        )}
        {record.bonus !== undefined && Number(record.bonus) > 0 && (
          <div>
            <span className="text-slate-500 block text-xs mb-0.5">Bonus</span>
            <span className="text-slate-200">
              {record.currency} {Number(record.bonus).toLocaleString()}
            </span>
          </div>
        )}
      </div>
      <div className="mt-3 flex items-center justify-between">
        <span className="text-xs text-slate-600">
          {record.createdAt ? new Date(record.createdAt).toLocaleDateString() : ""}
        </span>
        <Link
          to={`/salary/${record.id}`}
          className="text-xs text-indigo-400 hover:text-indigo-300 font-medium"
        >
          View details →
        </Link>
      </div>
    </div>
  );
}

function GroupAccordion({
  title,
  records,
  defaultOpen,
}: {
  title: string;
  records: SalaryRecord[];
  defaultOpen: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="bg-slate-900 rounded-2xl border border-slate-800 overflow-hidden">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between px-6 py-4 hover:bg-slate-800/40 transition-colors"
      >
        <div className="flex items-center gap-3">
          <span className="font-semibold text-white">{title}</span>
          <Badge variant="gray">{records.length} record/s</Badge>
        </div>
        <svg
          className={`w-4 h-4 text-slate-400 transition-transform ${open ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {open && (
        <div className="border-t border-slate-800">
          {records.map((r) => (
            <SalaryCard key={r.id} record={r} />
          ))}
        </div>
      )}
    </div>
  );
}

export default function Home() {
  const navigate = useNavigate();
  const [records, setRecords] = useState<SalaryRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [country, setCountry] = useState("");

  useEffect(() => {
    api
      .get<{ data: { results: SalaryRecord[] } }>("/api/search?limit=200")
      .then((res) => setRecords(res?.data?.results ?? []))
      .catch((err) => setError(err.message ?? "Failed to load data"))
      .finally(() => setLoading(false));
  }, []);

  const grouped = useMemo(() => {
    const filtered = records.filter((r) => {
      const matchTitle = search
        ? r.jobTitle?.toLowerCase().includes(search.toLowerCase()) ||
          r.company?.toLowerCase().includes(search.toLowerCase())
        : true;
      const matchCountry = country
        ? r.country?.toLowerCase().includes(country.toLowerCase())
        : true;
      return matchTitle && matchCountry;
    });

    const map = new Map<string, SalaryRecord[]>();
    for (const r of filtered) {
      const key = r.jobTitle ?? "Unknown";
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(r);
    }
    return Array.from(map.entries()).sort((a, b) => b[1].length - a[1].length);
  }, [records, search, country]);

  const countries = useMemo(
    () => [...new Set(records.map((r) => r.country).filter(Boolean))].sort(),
    [records]
  );

  function handleSearch(e: React.FormEvent) {
    e.preventDefault();
    navigate(`/search?q=${encodeURIComponent(search)}${country ? `&country=${encodeURIComponent(country)}` : ""}`);
  }

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Tech Salary Transparency</h1>
          <p className="text-slate-500 text-sm mt-0.5">
            Community-driven salary data — Sri Lanka & beyond
          </p>
        </div>
        <Link to="/submit">
          <Button size="md">+ Submit Salary</Button>
        </Link>
      </div>

      {/* Search bar */}
      <form
        onSubmit={handleSearch}
        className="bg-slate-900 rounded-2xl border border-slate-800 px-6 py-5"
      >
        <div className="flex flex-col sm:flex-row gap-3">
          <div className="flex-1">
            <Input
              placeholder="Search by role or company…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="sm:w-48">
            <select
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2.5 text-sm text-slate-100 outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">All countries</option>
              {countries.map((c) => (
                <option key={c} value={c!}>
                  {c}
                </option>
              ))}
            </select>
          </div>
          <Button type="submit" size="md">
            Search
          </Button>
        </div>
      </form>

      {/* Content */}
      {loading ? (
        <div className="flex justify-center py-20">
          <Spinner size="lg" />
        </div>
      ) : error ? (
        <Alert message={error} />
      ) : grouped.length === 0 ? (
        <div className="text-center py-20 text-slate-500">No results found.</div>
      ) : (
        <div className="flex flex-col gap-4">
          <p className="text-xs text-slate-500">
            Salaries grouped by designation — {records.length} approved record/s
          </p>
          {grouped.map(([title, items], i) => (
            <GroupAccordion
              key={title}
              title={title}
              records={items}
              defaultOpen={i === 0}
            />
          ))}
        </div>
      )}
    </div>
  );
}
