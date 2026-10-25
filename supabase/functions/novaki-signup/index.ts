// Creates a customer account already confirmed (no confirmation email: Supabase's built-in mailer is rate-limited).
// POST { email, password, full_name, phone? }
import { createClient } from "jsr:@supabase/supabase-js@2";

const H = { "Content-Type": "application/json" };
const out = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: H });

Deno.serve(async (req) => {
  if (req.method !== "POST") return out(405, { error: "method_not_allowed" });
  // deno-lint-ignore no-explicit-any
  let body: any;
  try { body = await req.json(); } catch { return out(400, { error: "invalid_json" }); }
  const email = String(body.email ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  const fullName = String(body.full_name ?? "").trim();
  const phone = body.phone ? String(body.phone).trim() : undefined;
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) return out(400, { error: "invalid_email" });
  if (password.length < 8 || password.length > 72) return out(400, { error: "invalid_password" });
  if (fullName.length < 2 || fullName.length > 100) return out(400, { error: "invalid_name" });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
    user_metadata: { full_name: fullName, ...(phone ? { phone } : {}) },
  });
  if (error) {
    const m = `${error.code ?? ""} ${error.message ?? ""}`.toLowerCase();
    if (m.includes("exists") || m.includes("already") || m.includes("registered")) return out(409, { error: "ALREADY_REGISTERED" });
    if (m.includes("weak_password")) return out(400, { error: "invalid_password" });
    return out(400, { error: "FAILED" });
  }
  return out(200, { ok: true });
});
