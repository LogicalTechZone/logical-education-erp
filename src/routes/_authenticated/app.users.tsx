import { createFileRoute } from '@tanstack/react-router';
import { FoundationScreen } from '@/components/erp/foundation-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/_authenticated/app/users')({ head: () => pageHead('Users and invitations', "Manage your organization’s membership and invitation access."), component: Page });
function Page() { return <FoundationScreen kind="users" />; }
