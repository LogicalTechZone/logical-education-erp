import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useRouter } from '@tanstack/react-router';
import type { User } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { themeStorageKey } from '@/lib/erp/access';

const SessionContext = createContext<{ user: User | null; loading: boolean; dark: boolean; toggleTheme: () => void }>({ user: null, loading: true, dark: false, toggleTheme: () => {} });
export const useSession = () => useContext(SessionContext);
export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [dark, setDark] = useState(false);
  const router = useRouter();
  const queryClient = useQueryClient();
  useEffect(() => {
    let alive = true;
    async function refresh() {
      const { data } = await supabase.auth.getUser();
      if (alive) { setUser(data.user); setLoading(false); }
    }
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (!['SIGNED_IN', 'SIGNED_OUT', 'USER_UPDATED', 'PASSWORD_RECOVERY'].includes(event)) return;
      // Defer Auth calls until the event's lock has been released.
      setTimeout(() => {
        if (!alive) return;
        if (event === 'SIGNED_OUT') {
          setUser(null); queryClient.clear();
          void router.navigate({ to: '/auth', replace: true });
        } else {
          void refresh();
          void queryClient.invalidateQueries();
          if (event === 'PASSWORD_RECOVERY') {
            sessionStorage.setItem('logical-erp:recovery', 'true');
            void router.navigate({ to: '/reset-password' });
          }
        }
        void router.invalidate();
      }, 0);
    });
    void refresh();
    return () => { alive = false; subscription.unsubscribe(); };
  }, [router, queryClient]);
  useEffect(() => {
    let value = false;
    try { value = localStorage.getItem(themeStorageKey(user?.id)) === 'dark'; } catch { /* storage may be blocked */ }
    setDark(value);
    document.documentElement.classList.toggle('dark', value);
  }, [user?.id]);
  function toggleTheme() {
    const value = !dark;
    setDark(value); document.documentElement.classList.toggle('dark', value);
    try { localStorage.setItem(themeStorageKey(user?.id), value ? 'dark' : 'light'); } catch { /* theme still applies */ }
  }
  return <SessionContext.Provider value={{ user, loading, dark, toggleTheme }}>{children}</SessionContext.Provider>;
}
