import { createFileRoute } from '@tanstack/react-router';
import { Dashboard } from '@/components/erp/dashboard';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/_authenticated/app/dashboard')({ head: () => pageHead('Dashboard', "Organization overview, visible branches, members, invitations and recent activity."), component: Page });
function Page() { return <Dashboard  />; }
