import lightLogo from '@/assets/logical-tech-zone-light.png.asset.json';
import darkLogo from '@/assets/logical-tech-zone-dark.png.asset.json';
import { useSession } from './session';

export function Brand({ compact = false }: { compact?: boolean }) {
  const { dark } = useSession();
  const logo = dark ? darkLogo : lightLogo;

  return <div className="flex items-center gap-3 min-w-0"><img src={logo.url} alt="Logical Tech Zone" className={compact ? 'w-10 h-10 object-contain shrink-0' : 'w-20 h-10 object-contain shrink-0'} />{!compact && <div className="min-w-0"><div className="text-sm font-bold leading-5 text-foreground">Logical Education</div><div className="text-[10px] uppercase tracking-widest text-muted-foreground">ERP · Logical Tech Zone</div></div>}</div>;
}
