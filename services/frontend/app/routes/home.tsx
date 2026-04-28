import { useState, useEffect } from "react";
import { Link } from "react-router";
import { Button } from "~/components/ui/Button";
import { Spinner } from "~/components/ui/Spinner";
import { Alert } from "~/components/ui/Alert";
import { StatCard } from "~/components/salary/StatCard";
import { SalaryTable } from "~/components/salary/SalaryTable";
import { api } from "~/lib/api";
import type { SalaryRecord } from "~/types";

export function meta() {
  return [{ title: "Dashboard | Salary Portal" }];
}

export default function Home() {
  const [records, setRecords] = useState<SalaryRecord[]>([]);
  const [approvedRecords, setApprovedRecords] = useState<SalaryRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const statsPromise = api
      .get<SalaryRecord[]>("/api/submissions")
      .then((data) => setRecords(Array.isArray(data) ? data : []))
      .catch((err) => setError(err.message ?? "Failed to load records"));

    const tablePromise = api
      .get<{ results: SalaryRecord[] }>("/api/search?limit=10")
      .then((data) => setApprovedRecords(data?.results ?? []))
      .catch(() => {});

    Promise.all([statsPromise, tablePromise]).finally(() => setLoading(false));
  }, []);

  const total = records.length;
  const approved = records.filter(
    (r) => r.status === "APPROVED" || r.status === "approved"
  ).length;
  const pending = records.filter(
    (r) => r.status === "PENDING" || r.status === "pending"
  ).length;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Dashboard</h1>
          <p className="text-slate-500 text-sm mt-0.5">Salary transparency data</p>
        </div>
        <Link to="/submit">
          <Button size="md">
            <svg
              className="w-4 h-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2}
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
            </svg>
            Submit Salary
          </Button>
        </Link>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard label="Total Submissions" value={loading ? "—" : total} />
        <StatCard
          label="Approved"
          value={loading ? "—" : approved}
          valueClassName="text-emerald-400"
        />
        <StatCard
          label="Pending Review"
          value={loading ? "—" : pending}
          valueClassName="text-amber-400"
        />
      </div>

      <div className="bg-slate-900 rounded-2xl border border-slate-800">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800">
          <h2 className="text-base font-semibold text-white">Recent Approved Submissions</h2>
          {!loading && (
            <span className="text-xs text-slate-500">{approvedRecords.length} shown</span>
          )}
        </div>
        <div className="px-6 py-4">
          {loading ? (
            <div className="flex justify-center py-12">
              <Spinner size="lg" />
            </div>
          ) : error ? (
            <Alert message={error} />
          ) : (
            <SalaryTable records={approvedRecords} />
          )}
        </div>
      </div>
    </div>
  );
}
