import { createFileRoute } from '@tanstack/react-router';
import { AuthScreen } from '@/components/erp/auth-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/login')({ head: () => pageHead('Login', 'Access your education organization workspace.'), component: Page });
function Page() { return <AuthScreen mode="login" />; }
