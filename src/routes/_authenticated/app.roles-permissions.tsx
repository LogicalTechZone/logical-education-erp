import { createFileRoute } from '@tanstack/react-router';
import { FoundationScreen } from '@/components/erp/foundation-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/_authenticated/app/roles-permissions')({ head: () => pageHead('Roles and permissions', "Organization and branch role management workspace."), component: Page });
function Page() { return <FoundationScreen kind="roles" />; }
