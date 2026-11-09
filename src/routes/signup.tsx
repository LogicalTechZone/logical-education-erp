import { createFileRoute } from '@tanstack/react-router';
import { AuthScreen } from '@/components/erp/auth-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/signup')({ head: () => pageHead('Create account', 'Create your Logical Education ERP account.'), component: Page });
function Page() { return <AuthScreen mode="signup" />; }
