import { createContext, useContext, useState, type ReactNode } from 'react';
import { Link, useNavigate, useRouterState } from '@tanstack/react-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Building2, LayoutDashboard, Network, Users, KeyRound, Settings, Moon, Sun, PanelLeftClose, PanelLeftOpen, LogOut, ChevronDown, ArrowUpRight, ShieldCheck } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Brand } from './brand';
import { useSession } from './session';
import { supabase } from '@/integrations/supabase/client';
import { workspaceOptions, profileOptions } from '@/lib/erp/data';
import { hasVerifiedEmail } from '@/lib/erp/access';
const WorkspaceContext = createContext<string | undefined>(undefined);
export const useTenantId = () => useContext(WorkspaceContext);
const navigation = [
  { label: 'Dashboard', path: '/app/dashboard', icon: LayoutDashboard },
  { label: 'Organizations', path: '/app/organizations', icon: Building2 },
  { label: 'Branches', path: '/app/branches', icon: Network },
  { label: 'Users & invitations', path: '/app/users', icon: Users },
  { label: 'Roles & permissions', path: '/app/roles-permissions', icon: KeyRound },
  { label: 'Settings', path: '/app/settings', icon: Settings },
] as const;
export function AppShell({ children }: { children: ReactNode }) {
  const { user, dark, toggleTheme } = useSession();
  const [collapsed, setCollapsed] = useState(false); const [mobile, setMobile] = useState(false);
  const [selected, setSelected] = useState(''); const [account, setAccount] = useState(false);
  const pathname = useRouterState({ select: s => s.location.pathname });
  const { data: organizations, error } = useQuery(workspaceOptions());
  const { data: profile } = useQuery(profileOptions(user?.id));
  const tenantId = organizations?.some(o => o.id === selected) ? selected : organizations?.[0]?.id;
  const active = navigation.find(n => n.path === pathname);
  const navigate = useNavigate(); const queryClient = useQueryClient();
  async function signOut() {
    await queryClient.cancelQueries(); queryClient.clear();
    const { error } = await supabase.auth.signOut();
    if (error) return;
    await navigate({ to: '/auth', replace: true });
  }
  return <WorkspaceContext.Provider value={tenantId}><div className="min-h-screen flex bg-background">
    {mobile && <div className="fixed inset-0 z-30 bg-foreground/30 md:hidden" onClick={() => setMobile(false)} />}
    <aside className={`erp-sidebar ${collapsed ? 'is-collapsed' : ''} ${mobile ? 'is-open' : ''} bg-sidebar border-r border-sidebar-border flex flex-col z-40`}>
      <div className="h-24 flex items-center px-5 border-b border-sidebar-border"><Brand compact={collapsed} /></div>
      <div className="p-4"><div className="flex items-center gap-3 border border-border rounded-md bg-card px-3 py-3"><div className="size-9 shrink-0 rounded-md bg-accent text-primary flex items-center justify-center"><Building2 className="size-4" /></div>{!collapsed && <div className="min-w-0 flex-1"><div className="text-[10px] uppercase tracking-widest text-muted-foreground mb-1">Workspace</div><select aria-label="Select organization" className="w-full bg-card text-foreground text-xs font-medium outline-none" value={tenantId ?? ''} onChange={e => setSelected(e.target.value)}><option value="" disabled>{error ? 'Unable to load' : 'No organization'}</option>{organizations?.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}</select></div>}</div></div>
      {!collapsed && <div className="px-6 pt-4 pb-2 text-[10px] tracking-widest uppercase text-muted-foreground">Workspace management</div>}
      <nav className="px-3 space-y-1">{navigation.map(item => <Button asChild key={item.path} variant="ghost" title={item.label} className={`w-full justify-start h-11 ${pathname === item.path ? 'bg-accent text-primary border-l-2 border-primary' : 'text-muted-foreground'}`}><Link to={item.path} onClick={() => setMobile(false)} aria-current={pathname === item.path ? 'page' : undefined}><item.icon />{!collapsed && <span className="text-[13px]">{item.label}</span>}</Link></Button>)}</nav>
      <div className="mt-auto p-5">{!collapsed && <><div className="flex gap-2 text-xs text-muted-foreground"><ShieldCheck className="size-4 text-primary shrink-0" /><span>Organization access<br /><span className="text-[10px]">Secure by design</span></span></div><div className="mt-5 pt-4 border-t border-border text-[10px] text-muted-foreground">Powered by Logical Tech Zone</div></>}</div>
    </aside>
    <div className="flex-1 min-w-0"><header className="h-20 px-5 md:px-9 border-b border-border bg-card flex items-center justify-between gap-3">
      <div className="flex items-center gap-4 min-w-0"><Button variant="ghost" size="icon" aria-label="Toggle navigation" title="Toggle navigation" onClick={() => { if (window.innerWidth < 768) setMobile(!mobile); else setCollapsed(!collapsed); }}>{collapsed ? <PanelLeftOpen /> : <PanelLeftClose />}</Button><div className="flex gap-2 text-xs text-muted-foreground truncate"><span className="hidden sm:inline">Workspace</span><span className="hidden sm:inline">/</span><span className="text-foreground">{active?.label ?? 'Organization onboarding'}</span></div></div>
      <div className="flex items-center gap-3"><span className="text-[10px] uppercase tracking-widest border border-border text-muted-foreground rounded px-2 py-1 hidden sm:block">Dev workspace</span><Button variant="ghost" size="icon" aria-label="Toggle theme" title={dark ? 'Light mode' : 'Dark mode'} onClick={toggleTheme}>{dark ? <Sun /> : <Moon />}</Button><div className="relative"><Button variant="ghost" className="gap-2" aria-label="Account menu" aria-expanded={account} onClick={() => setAccount(!account)}><span className="size-8 bg-secondary rounded-full flex items-center justify-center text-xs font-semibold">{(profile?.full_name ?? user?.email ?? 'A').slice(0, 1).toUpperCase()}</span><span className="text-xs hidden lg:inline max-w-32 truncate">{profile?.full_name ?? 'My account'}</span><ChevronDown className="size-3" /></Button>{account && <div className="absolute right-0 top-12 w-64 rounded-md bg-popover border border-border shadow-lg p-3 z-50"><p className="text-xs text-muted-foreground break-all p-2">{user?.email}</p><Button variant="ghost" className="w-full justify-start" onClick={() => void signOut()}><LogOut />Sign out</Button></div>}</div></div>
    </header>
    {!hasVerifiedEmail(user) && user && <div className="border-b border-border bg-accent px-9 py-3 text-sm">Confirm your email to access organization information.</div>}
    <main className="px-5 md:px-9 py-8 max-w-[1500px] mx-auto">{children}</main>
    <footer className="px-5 md:px-9 py-6 flex justify-between gap-3 text-[10px] text-muted-foreground"><span>Logical Education ERP</span><span>M1 · Workspace foundation</span></footer>
    </div></div></WorkspaceContext.Provider>;
}
export function PageHeader({ eyebrow, title, description, action }: { eyebrow: string; title: string; description: string; action?: ReactNode }) {
  return <div className="mb-8 flex flex-wrap gap-4 justify-between items-end"><div><p className="text-[10px] uppercase tracking-widest text-muted-foreground mb-2">{eyebrow}</p><h1 className="text-2xl md:text-3xl font-semibold">{title}</h1><p className="mt-2 text-sm text-muted-foreground max-w-xl">{description}</p></div>{action}</div>;
}
export function EmptyState({ title, description, action }: { title: string; description: string; action?: ReactNode }) {
  return <div className="py-12 flex flex-col items-center text-center"><div className="size-12 rounded-full bg-secondary text-muted-foreground flex items-center justify-center mb-4"><Building2 className="size-5" /></div><h3 className="text-sm font-semibold">{title}</h3><p className="text-xs leading-6 text-muted-foreground max-w-sm mt-2">{description}</p>{action && <div className="mt-5">{action}</div>}</div>;
}
export function SectionLink({ to, children }: { to: typeof navigation[number]['path']; children: ReactNode }) { return <Button asChild variant="ghost" size="sm"><Link to={to}>{children}<ArrowUpRight /></Link></Button>; }
