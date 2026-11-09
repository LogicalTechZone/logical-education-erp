import { createFileRoute } from '@tanstack/react-router';
import { Organizations } from '@/components/erp/organizations';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/_authenticated/app/organizations')({ head: () => pageHead('Organizations', "Browse organizations available to your account."), component: Page });
function Page() { return <Organizations  />; }
