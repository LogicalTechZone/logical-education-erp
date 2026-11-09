import { createFileRoute } from '@tanstack/react-router';
import { AuthScreen } from '@/components/erp/auth-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/reset-password')({ head: () => pageHead('Reset password', 'Set a new password for your Logical Education ERP account.'), component: Page });
function Page() { return <AuthScreen mode="reset" />; }
