import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from '@tanstack/react-router';
import { ArrowRight, Eye, EyeOff, LockKeyhole, Moon, Sun, ShieldCheck, CheckCircle2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Brand } from './brand';
import { useSession } from './session';
import { supabase } from '@/integrations/supabase/client';
export type AuthMode = 'login' | 'signup' | 'forgot' | 'reset';
const copy = {
  login: ['Welcome back', 'Sign in to your education workspace.'],
  signup: ['Create your account', 'Your institution’s next chapter starts here.'],
  forgot: ['Forgot your password?', 'We’ll send a secure reset link to your email.'],
  reset: ['Set a new password', 'Choose a strong password for your account.'],
};
export function AuthScreen({ mode = 'login' }: { mode?: AuthMode }) {
  const { user, loading, dark, toggleTheme } = useSession();
  const navigate = useNavigate();
  const [email, setEmail] = useState(''); const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState(''); const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false); const [error, setError] = useState(''); const [message, setMessage] = useState('');
  async function submit(event: FormEvent) {
    event.preventDefault(); setError(''); setMessage('');
    if (mode === 'reset' && password !== confirm) { setError('The passwords do not match.'); return; }
    setBusy(true);
    try {
      if (mode === 'login') {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        await navigate({ to: '/app/dashboard' });
      } else if (mode === 'signup') {
        const { data, error } = await supabase.auth.signUp({ email, password, options: { emailRedirectTo: window.location.origin } });
        if (error) throw error;
        if (data.session) await navigate({ to: '/app/dashboard' });
        else setMessage('Check your email to confirm your account before signing in.');
      } else if (mode === 'forgot') {
        const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/reset-password` });
        if (error) throw error;
        setMessage('If an account exists for this email, a password reset link has been sent.');
      } else {
        const hashRecovery = new URLSearchParams(window.location.hash.slice(1)).get('type') === 'recovery';
        const { data } = await supabase.auth.getUser();
        if (!data.user || (!hashRecovery && sessionStorage.getItem('logical-erp:recovery') !== 'true')) throw new Error('Open a valid password reset link from your email first.');
        const { error } = await supabase.auth.updateUser({ password });
        if (error) throw error;
        sessionStorage.removeItem('logical-erp:recovery');
        setMessage('Your password has been updated.');
      }
    } catch (err) { setError(err instanceof Error ? err.message : 'Unable to complete this request. Please try again.'); }
    finally { setBusy(false); }
  }
  return <div className="min-h-screen bg-background flex flex-col">
    <header className="h-24 flex items-center justify-between px-6 md:px-12 border-b border-border bg-card"><Brand /><Button variant="ghost" size="icon" title={dark ? 'Switch to light mode' : 'Switch to dark mode'} aria-label="Toggle theme" onClick={toggleTheme}>{dark ? <Sun /> : <Moon />}</Button></header>
    <main className="flex-1 w-full max-w-5xl mx-auto px-6 py-14 md:py-24 grid md:grid-cols-[1fr_420px] gap-16 items-center">
      <section className="hidden md:block"><div className="inline-flex items-center gap-2 text-xs uppercase tracking-widest text-muted-foreground mb-6"><span className="w-6 h-px bg-primary" /> Education, connected</div><h1 className="text-4xl font-semibold leading-tight text-foreground">Logical<br />Education ERP<span className="text-primary">.</span></h1><p className="mt-6 text-muted-foreground leading-7 max-w-sm">One workspace for your organizations, branches and people.</p><div className="mt-12 flex items-center gap-3 text-sm text-muted-foreground"><ShieldCheck className="size-5 text-primary" /> A secure workspace for every institution</div></section>
      <section className="w-full"><div className="size-11 bg-accent text-primary rounded-lg flex items-center justify-center mb-6"><LockKeyhole className="size-5" /></div><h2 className="text-2xl font-semibold">{copy[mode][0]}</h2><p className="text-sm text-muted-foreground mt-2 mb-8">{copy[mode][1]}</p>
        {!loading && user && mode === 'login' ? <div className="space-y-4"><p className="text-sm text-muted-foreground break-all">Signed in as {user.email}</p><Button asChild className="w-full"><Link to="/app/dashboard">Open workspace <ArrowRight /></Link></Button></div> : <form onSubmit={submit} className="space-y-5">
          {mode !== 'reset' && <div className="space-y-2"><Label htmlFor="email">Email address</Label><Input id="email" type="email" placeholder="you@institution.com" autoComplete="email" required value={email} onChange={e => setEmail(e.target.value)} className="h-11" /></div>}
          {mode !== 'forgot' && <div className="space-y-2"><div className="flex items-center justify-between"><Label htmlFor="password">{mode === 'reset' ? 'New password' : 'Password'}</Label>{mode === 'login' && <Link to="/forgot-password" className="text-xs text-primary hover:underline">Forgot password?</Link>}</div><div className="relative"><Input id="password" type={show ? 'text' : 'password'} minLength={mode === 'login' ? undefined : 8} required autoComplete={mode === 'login' ? 'current-password' : 'new-password'} value={password} onChange={e => setPassword(e.target.value)} className="h-11 pr-12" /><Button type="button" variant="ghost" size="icon" className="absolute right-1 top-1" aria-label={show ? 'Hide password' : 'Show password'} onClick={() => setShow(!show)}>{show ? <EyeOff /> : <Eye />}</Button></div>{mode !== 'login' && <p className="text-xs text-muted-foreground">At least 8 characters.</p>}</div>}
          {mode === 'reset' && <div className="space-y-2"><Label htmlFor="confirm">Confirm password</Label><Input id="confirm" type="password" minLength={8} required value={confirm} onChange={e => setConfirm(e.target.value)} /></div>}
          {error && <p role="alert" className="text-sm text-destructive">{error}</p>}{message && <p role="status" className="text-sm text-foreground flex gap-2"><CheckCircle2 className="size-5 shrink-0 text-primary" />{message}</p>}
          <Button className="w-full h-11" disabled={busy}>{busy ? 'Please wait…' : mode === 'login' ? 'Sign in' : mode === 'signup' ? 'Create account' : mode === 'forgot' ? 'Send reset link' : 'Update password'}<ArrowRight /></Button>
        </form>}
        <div className="mt-6 text-sm text-center text-muted-foreground">{mode === 'login' ? <>New to Logical Education ERP? <Link to="/signup" className="text-foreground font-medium hover:underline">Create account</Link></> : <Link to="/auth" className="text-foreground hover:underline">Back to sign in</Link>}</div>
      </section>
    </main><footer className="px-6 py-6 text-center text-xs text-muted-foreground border-t border-border">Powered by Logical Tech Zone · Pakistan</footer>
  </div>;
}
