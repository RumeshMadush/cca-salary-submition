import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router";
import { Spinner } from "~/components/ui/Spinner";
import { Alert } from "~/components/ui/Alert";
import { Button } from "~/components/ui/Button";
import { Badge } from "~/components/ui/Badge";
import { api } from "~/lib/api";
import { isAuthenticated } from "~/lib/auth";
import type { SalaryRecord } from "~/types";

export function meta() {
  return [{ title: "Admin Review | Salary Portal" }];
}

type ActionState = { id: number; action: "APPROVED" | "REJECTED" } | null;

export default function Admin() {
  const navigate = useNavigate();
  const [records, setRecords] = useState<SalaryRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [acting, setActing] = useState<ActionState>(null);
  const [toast, setToast] = useState("");

  useEffect(() => {
    if (!isAuthenticated()) {
      navigate("/login");
    }
  }, [navigate]);

  const load = useCallback(() => {
    setLoading(true);
    api
      .get<SalaryRecord[]>("/api/submissions?status=PENDING")
      .then((data) => setRecords(Array.isArray(data) ? data : []))
      .catch((err) => setError(err.message ?? "Failed to load submissions"))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function updateStatus(id: number, status: "APPROVED" | "REJECTED") {
    setActing({ id, action: status });
    try {
      await api.patch(`/api/submissions/${id}/status`, { status });
      setToast(`Submission #${id} ${status.toLowerCase()}.`);
      setRecords((prev) => prev.filter((r) => r.id !== id));
      setTimeout(() => setToast(""), 3000);
    } catch (err: any) {
      setError(err.message ?? "Action failed");
    } finally {
      setActing(null);
    }
  }

  const pending = records.filter(
    (r) => r.status === "PENDING" || r.status === "pending"
  );

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Admin Review</h1>
          <p className="text-slate-500 text-sm mt-0.5">
            Approve or reject pending salary submissions
          </p>
        </div>
        <Button variant="secondary" size="sm" onClick={load} disabled={loading}>
          Refresh
        </Button>
      </div>

      {toast && (
        <div className="bg-emerald-950 border border-emerald-800 text-emerald-400 text-sm px-4 py-3 rounded-xl">
          {toast}
        </div>
      )}

      {error && <Alert message={error} />}

      <div className="bg-slate-900 rounded-2xl border border-slate-800">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800">
          <h2 className="text-base font-semibold text-white">
            Pending Submissions
          </h2>
          {!loading && (
            <Badge variant="yellow">{pending.length} pending</Badge>
          )}
        </div>

        <div className="px-6 py-4">
          {loading ? (
            <div className="flex justify-center py-12">
              <Spinner size="lg" />
            </div>
          ) : pending.length === 0 ? (
            <p className="text-slate-500 text-sm text-center py-12">
              No pending submissions — all caught up!
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-800">
                    {["ID", "Company", "Role", "Country", "Level", "Salary", "Submitted", "Actions"].map(
                      (h) => (
                        <th
                          key={h}
                          className="pb-3 pr-4 text-left text-xs font-medium text-slate-500 uppercase tracking-wide"
                        >
                          {h}
                        </th>
                      )
                    )}
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/50">
                  {pending.map((r) => (
                    <tr key={r.id} className="hover:bg-slate-800/30 transition-colors">
                      <td className="py-3.5 pr-4 text-slate-500 text-xs">#{r.id}</td>
                      <td className="py-3.5 pr-4 font-medium text-slate-200">
                        {r.anonymize ? (
                          <span className="text-slate-500 italic">Anonymous</span>
                        ) : (
                          r.company
                        )}
                      </td>
                      <td className="py-3.5 pr-4 text-slate-400">{r.jobTitle}</td>
                      <td className="py-3.5 pr-4 text-slate-500">{r.country ?? "—"}</td>
                      <td className="py-3.5 pr-4">
                        {r.experienceLevel ? (
                          <Badge variant="indigo">{r.experienceLevel}</Badge>
                        ) : (
                          <span className="text-slate-600">—</span>
                        )}
                      </td>
                      <td className="py-3.5 pr-4 font-semibold text-slate-200">
                        <span className="text-slate-500 text-xs mr-1">{r.currency}</span>
                        {(r.totalCompensation ?? r.baseSalary).toLocaleString()}
                      </td>
                      <td className="py-3.5 pr-4 text-slate-500 text-xs">
                        {r.createdAt
                          ? new Date(r.createdAt).toLocaleDateString()
                          : "—"}
                      </td>
                      <td className="py-3.5 pr-4">
                        <div className="flex gap-2">
                          <Button
                            size="sm"
                            variant="primary"
                            loading={
                              acting?.id === r.id && acting.action === "APPROVED"
                            }
                            disabled={acting?.id === r.id}
                            onClick={() => updateStatus(r.id, "APPROVED")}
                          >
                            Approve
                          </Button>
                          <Button
                            size="sm"
                            variant="danger"
                            loading={
                              acting?.id === r.id && acting.action === "REJECTED"
                            }
                            disabled={acting?.id === r.id}
                            onClick={() => updateStatus(r.id, "REJECTED")}
                          >
                            Reject
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
