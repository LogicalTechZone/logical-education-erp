export function hasVerifiedEmail(user: { email_confirmed_at?: string | null } | null) {
  return Boolean(user?.email_confirmed_at);
}
export function themeStorageKey(userId: string | undefined) {
  return `logical-erp:theme:${userId ?? 'signed-out'}`;
}
