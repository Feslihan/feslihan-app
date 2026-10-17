"use client";

import { useCallback, useEffect, useState } from "react";
import {
  SignedIn,
  SignedOut,
  SignInButton,
  UserButton,
  useAuth,
} from "@clerk/nextjs";

const API = process.env.NEXT_PUBLIC_API_URL ?? "https://feslihan-app.vercel.app";

interface UserQuota {
  clerk_id: string;
  email: string | null;
  name: string | null;
  plan: string;
  effective_plan: string;
  unlimited_until: string | null;
  scans_used: number;
  scan_limit: number | null;
  scans_remaining: number | null;
  meal_plans_used: number;
  meal_plan_limit: number | null;
  meal_plans_remaining: number | null;
  recipe_count: number;
  last_active_at: string | null;
  last_sign_in_at: string | null;
  created_at: string;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("tr-TR", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

/** "bugün" / "3 gün önce" / "5 Eki" — compact last-activity label. */
function formatRelative(iso: string | null): string {
  if (!iso) return "—";
  const then = new Date(iso).getTime();
  const days = Math.floor((Date.now() - then) / 86_400_000);
  if (days <= 0) return "bugün";
  if (days === 1) return "dün";
  if (days < 7) return `${days} gün önce`;
  if (days < 30) return `${Math.floor(days / 7)} hafta önce`;
  return formatDate(iso);
}

function QuotaCell({ used, limit }: { used: number; limit: number | null }) {
  if (limit === null) return <span className="quota muted">sınırsız</span>;
  const exhausted = used >= limit;
  return (
    <span className="quota">
      <span className={exhausted ? "exhausted" : undefined}>{used}</span>
      <span className="muted"> / {limit}</span>
    </span>
  );
}

function Dashboard() {
  const { getToken, userId } = useAuth();
  const [rows, setRows] = useState<UserQuota[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [forbidden, setForbidden] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null); // clerk_id or "__all__"

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const token = await getToken();
      const res = await fetch(`${API}/admin/users/quota`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.status === 403) {
        setForbidden(true);
        return;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setRows(await res.json());
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, [getToken]);

  useEffect(() => {
    void load();
  }, [load]);

  async function grant(target: string | null, days: number) {
    const key = target ?? "__all__";
    const label = target
      ? `${target} kullanıcısına ${days} gün sınırsız verilecek. Emin misin?`
      : `TÜM kullanıcılara ${days} gün sınırsız verilecek. Emin misin?`;
    if (!window.confirm(label)) return;

    setBusy(key);
    setError(null);
    try {
      const token = await getToken();
      const url = target
        ? `${API}/admin/users/${encodeURIComponent(target)}/unlimited`
        : `${API}/admin/grant-unlimited-all`;
      const res = await fetch(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ days }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(null);
    }
  }

  if (forbidden) {
    return (
      <div className="notice error">
        Bu hesabın admin yetkisi yok. Backend&apos;in <code>ADMIN_CLERK_IDS</code>{" "}
        ortam değişkenine şu id&apos;yi ekleyip yeniden deploy etmen gerekiyor:{" "}
        <code>{userId}</code>
      </div>
    );
  }

  return (
    <>
      <div className="actions">
        <button onClick={() => void load()} disabled={loading}>
          {loading ? "Yükleniyor…" : "Yenile"}
        </button>
        <button
          className="primary"
          onClick={() => void grant(null, 30)}
          disabled={busy !== null}
        >
          {busy === "__all__" ? "Veriliyor…" : "Herkese 30 gün sınırsız ver"}
        </button>
        {rows && <span className="muted">{rows.length} kullanıcı</span>}
      </div>

      {error && <div className="notice error">Hata: {error}</div>}

      {rows && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Kullanıcı</th>
                <th>Plan</th>
                <th>Tarif</th>
                <th>Tarama</th>
                <th>Haftalık Plan</th>
                <th>Son Aktiflik</th>
                <th>Kayıt</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((u) => (
                <tr key={u.clerk_id}>
                  <td className="user-cell">
                    <div className="name">{u.name || "—"}</div>
                    <div className="email">{u.email || u.clerk_id}</div>
                  </td>
                  <td>
                    <span className={`badge ${u.effective_plan}`}>
                      {u.effective_plan}
                    </span>
                    {u.unlimited_until && (
                      <span className="badge trial">
                        deneme → {formatDate(u.unlimited_until)}
                      </span>
                    )}
                  </td>
                  <td className="recipe-count">{u.recipe_count}</td>
                  <td>
                    <QuotaCell used={u.scans_used} limit={u.scan_limit} />
                  </td>
                  <td>
                    <QuotaCell
                      used={u.meal_plans_used}
                      limit={u.meal_plan_limit}
                    />
                  </td>
                  <td className="muted" title={u.last_active_at ?? ""}>
                    {formatRelative(u.last_active_at)}
                  </td>
                  <td className="muted">{formatDate(u.created_at)}</td>
                  <td>
                    <button
                      className="small"
                      onClick={() => void grant(u.clerk_id, 30)}
                      disabled={busy !== null}
                    >
                      {busy === u.clerk_id ? "…" : "+30 gün sınırsız"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

export default function Home() {
  return (
    <div className="page">
      <div className="topbar">
        <div className="wordmark">
          <span className="leaf">❧</span>
          <span>Feslihan</span>
          <span className="admin">Admin</span>
        </div>
        <SignedIn>
          <UserButton />
        </SignedIn>
      </div>

      <SignedOut>
        <div className="center">
          <div className="wordmark" style={{ fontSize: 28 }}>
            <span className="leaf">❧</span>
            <span>Feslihan</span>
            <span className="admin">Admin</span>
          </div>
          <p className="subtitle">Devam etmek için giriş yap.</p>
          <SignInButton mode="modal">
            <button className="primary">Giriş Yap</button>
          </SignInButton>
        </div>
      </SignedOut>

      <SignedIn>
        <h1>Kullanıcı Hakları</h1>
        <p className="subtitle">
          Bu ayki tarama ve haftalık plan kullanımı. Hazır tarif kaydetmek her
          zaman ücretsizdir; sayaçlar yalnızca yeni AI işini ölçer.
        </p>
        <Dashboard />
      </SignedIn>
    </div>
  );
}
