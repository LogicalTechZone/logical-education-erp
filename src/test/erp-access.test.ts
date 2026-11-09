import { describe, expect, it } from 'vitest';
import { hasVerifiedEmail, themeStorageKey } from '@/lib/erp/access';
describe('M1 account requirements', () => {
  it('requires confirmed email for tenant-bearing access', () => {
    expect(hasVerifiedEmail({ email_confirmed_at: null })).toBe(false);
    expect(hasVerifiedEmail({ email_confirmed_at: '2026-11-09T11:57:00Z' })).toBe(true);
  });
  it('keeps theme preferences separate for each user', () => {
    expect(themeStorageKey('owner')).not.toBe(themeStorageKey('staff'));
    expect(themeStorageKey(undefined)).toBe('logical-erp:theme:signed-out');
  });
});