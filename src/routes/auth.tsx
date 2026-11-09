import { createFileRoute } from '@tanstack/react-router';
import { AuthScreen } from '@/components/erp/auth-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/auth')({ head: () => pageHead('Sign in', 'Sign in securely to your Logical Education ERP workspace.'), component: Page });
function Page() { return <AuthScreen mode="login" />; }
