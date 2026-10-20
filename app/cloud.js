// Konta i synchronizacja planu przez Supabase.
// Cały plan (zadania + kategorie) to jeden wiersz w tabeli `plans`, widoczny tylko dla właściciela.
import { APP_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "./config.js";

const client = SUPABASE_URL && SUPABASE_ANON_KEY && window.supabase
  ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
  : null;

export const cloudEnabled = !!client;

const MESSAGES = [
  [/invalid login credentials/i, "Nieprawidłowy e-mail lub hasło."],
  [/email not confirmed/i, "Potwierdź najpierw adres e-mail – kliknij link w wiadomości od nas."],
  [/already registered|already been registered/i, "Konto z tym adresem już istnieje. Zaloguj się."],
  [/password should be at least/i, "Hasło musi mieć co najmniej 8 znaków."],
  [/rate limit|too many/i, "Za dużo prób. Odczekaj chwilę i spróbuj ponownie."],
  [/failed to fetch|network/i, "Brak połączenia z internetem."],
];
export function friendlyError(err) {
  const msg = err?.message || String(err || "");
  for (const [re, pl] of MESSAGES) if (re.test(msg)) return pl;
  return msg || "Coś poszło nie tak. Spróbuj ponownie.";
}

export async function currentUser() {
  if (!client) return null;
  const { data } = await client.auth.getSession();
  return data.session?.user || null;
}

export function onAuthChange(fn) {
  if (client) client.auth.onAuthStateChange((event, session) => fn(event, session?.user || null));
}

export async function signUp(email, password, name) {
  const { data, error } = await client.auth.signUp({
    email, password, options: { data: { name }, emailRedirectTo: APP_URL },
  });
  if (error) throw error;
  return { user: data.user, needsConfirmation: !data.session };
}

export async function signIn(email, password) {
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data.user;
}

export async function signOut() {
  await client?.auth.signOut();
}

export async function resetPassword(email) {
  const { error } = await client.auth.resetPasswordForEmail(email, { redirectTo: APP_URL });
  if (error) throw error;
}

export async function setNewPassword(password) {
  const { error } = await client.auth.updateUser({ password });
  if (error) throw error;
}

/** Plan z konta: `{ data, updated_at }`, `null` gdy konto nie ma jeszcze planu. Rzuca przy błędzie sieci. */
export async function pull(userId) {
  const { data, error } = await client.from("plans").select("data, updated_at").eq("user_id", userId).maybeSingle();
  if (error) throw error;
  return data;
}

/** Zapisuje plan na koncie i zwraca czas zapisu nadany przez serwer. */
export async function push(userId, plan) {
  const { data, error } = await client.from("plans")
    .upsert({ user_id: userId, data: plan }, { onConflict: "user_id" })
    .select("updated_at").single();
  if (error) throw error;
  return data.updated_at;
}

/** Usuwa plan z konta (dane na urządzeniu zostają). */
export async function deleteRemote(userId) {
  const { error } = await client.from("plans").delete().eq("user_id", userId);
  if (error) throw error;
}
