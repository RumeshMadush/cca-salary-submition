import { useState, useEffect } from "react";
import { useParams, Link } from "react-router";
import { Button } from "~/components/ui/Button";
import { Spinner } from "~/components/ui/Spinner";
import { Alert } from "~/components/ui/Alert";
import { Badge } from "~/components/ui/Badge";
import { SalaryDetailCard } from "~/components/salary/SalaryDetailCard";
import { api } from "~/lib/api";
import { isAuthenticated } from "~/lib/auth";
import type { SalaryRecord } from "~/types";

export function meta() {
  return [{ title: "Salary Detail | Salary Portal" }];
}

interface VoteCounts {
  upvoteCount?: number;
  downvoteCount?: number;
  netScore?: number;
  upvotes?: number;
  downvotes?: number;
}

export default function SalaryDetail() {
  const { id } = useParams();
  const [record, setRecord] = useState<SalaryRecord | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [votes, setVotes] = useState<VoteCounts | null>(null);
  const [voting, setVoting] = useState<"upvote" | "downvote" | null>(null);
  const [voteError, setVoteError] = useState("");
  const [voteSuccess, setVoteSuccess] = useState("");

  const authed = isAuthenticated();

  useEffect(() => {
    api
      .get<SalaryRecord>(`/api/submissions/${id}`)
      .then(setRecord)
      .catch((err) => setError(err.message ?? "Failed to load record"))
      .finally(() => setLoading(false));

    api
      .get<VoteCounts>(`/api/votes/${id}/counts`)
      .then(setVotes)
      .catch(() => {});
  }, [id]);

  async function castVote(voteType: "upvote" | "downvote") {
    if (!authed) return;
    setVoting(voteType);
    setVoteError("");
    setVoteSuccess("");
    try {
      await api.post("/api/votes", { submission_id: Number(id), vote_type: voteType });
      setVoteSuccess(`Your ${voteType} was recorded!`);
      const updated = await api.get<VoteCounts>(`/api/votes/${id}/counts`);
      setVotes(updated);
    } catch (err: any) {
      setVoteError(err.message ?? "Vote failed");
    } finally {
      setVoting(null);
    }
  }

  const upvotes = votes?.upvoteCount ?? votes?.upvotes ?? 0;
  const downvotes = votes?.downvoteCount ?? votes?.downvotes ?? 0;
  const net = votes?.netScore ?? (upvotes - downvotes);

  return (
    <div className="max-w-lg flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <Link to="/">
          <Button variant="secondary" size="sm">← Back</Button>
        </Link>
        <h1 className="text-2xl font-bold text-white">Salary Detail</h1>
      </div>

      {loading ? (
        <div className="flex justify-center py-16">
          <Spinner size="lg" />
        </div>
      ) : error ? (
        <Alert message={error} />
      ) : record ? (
        <>
          <SalaryDetailCard record={record} />

          {/* Voting panel */}
          <div className="bg-slate-900 rounded-2xl border border-slate-800 px-6 py-5">
            <h2 className="text-sm font-semibold text-white mb-4">Community Trust</h2>

            {/* Vote counts */}
            <div className="flex items-center gap-6 mb-5">
              <div className="flex items-center gap-2">
                <span className="text-emerald-400 font-bold text-lg">{upvotes}</span>
                <span className="text-slate-500 text-sm">upvotes</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-rose-400 font-bold text-lg">{downvotes}</span>
                <span className="text-slate-500 text-sm">downvotes</span>
              </div>
              <div className="ml-auto">
                <Badge variant={net >= 3 ? "green" : net > 0 ? "indigo" : "gray"}>
                  net {net >= 0 ? "+" : ""}{net}
                </Badge>
              </div>
            </div>

            {/* Threshold indicator */}
            <div className="mb-5">
              <div className="flex items-center justify-between text-xs text-slate-500 mb-1.5">
                <span>Approval threshold</span>
                <span>{Math.min(net, 3)}/3 net upvotes</span>
              </div>
              <div className="h-1.5 bg-slate-800 rounded-full overflow-hidden">
                <div
                  className="h-full bg-indigo-500 rounded-full transition-all"
                  style={{ width: `${Math.min((Math.max(net, 0) / 3) * 100, 100)}%` }}
                />
              </div>
            </div>

            {voteSuccess && (
              <div className="mb-4 text-emerald-400 text-sm bg-emerald-950/40 border border-emerald-800 rounded-lg px-4 py-2.5">
                {voteSuccess}
              </div>
            )}
            {voteError && <Alert message={voteError} />}

            {authed ? (
              <div className="flex gap-3">
                <Button
                  variant="primary"
                  size="md"
                  loading={voting === "upvote"}
                  disabled={voting !== null}
                  onClick={() => castVote("upvote")}
                >
                  👍 Upvote
                </Button>
                <Button
                  variant="danger"
                  size="md"
                  loading={voting === "downvote"}
                  disabled={voting !== null}
                  onClick={() => castVote("downvote")}
                >
                  👎 Downvote
                </Button>
              </div>
            ) : (
              <div className="flex items-center gap-3">
                <Link to="/login">
                  <Button variant="secondary" size="sm">Login to vote</Button>
                </Link>
                <span className="text-xs text-slate-500">
                  Login required to upvote or downvote
                </span>
              </div>
            )}
          </div>
        </>
      ) : null}
    </div>
  );
}
