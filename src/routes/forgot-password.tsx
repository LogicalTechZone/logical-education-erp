import { createFileRoute } from '@tanstack/react-router';
import { AuthScreen } from '@/components/erp/auth-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/forgot-password')({ head: () => pageHead('Password recovery', 'Recover access to your Logical Education ERP account.'), component: Page });
function Page() { return <AuthScreen mode="forgot" />; }
