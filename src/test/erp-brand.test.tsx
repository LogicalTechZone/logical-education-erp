import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Brand } from '@/components/erp/brand';
import darkLogo from '@/assets/logical-tech-zone-dark.png.asset.json';
import lightLogo from '@/assets/logical-tech-zone-light.png.asset.json';

const session = vi.hoisted(() => ({ dark: false }));
vi.mock('@/components/erp/session', () => ({ useSession: () => session }));

describe('theme-specific branding', () => {
  it('uses the full-color logo by default in light mode', () => {
    session.dark = false;
    render(<Brand />);
    expect(screen.getByRole('img', { name: 'Logical Tech Zone' })).toHaveAttribute('src', lightLogo.url);
  });

  it('uses the orange transparent logo in dark mode', () => {
    session.dark = true;
    render(<Brand />);
    expect(screen.getByRole('img', { name: 'Logical Tech Zone' })).toHaveAttribute('src', darkLogo.url);
  });
});
