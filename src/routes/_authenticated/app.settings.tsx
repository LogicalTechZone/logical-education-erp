import { createFileRoute } from '@tanstack/react-router';
import { FoundationScreen } from '@/components/erp/foundation-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/_authenticated/app/settings')({ head: () => pageHead('Account settings', "Manage account appearance and review profile details."), component: Page });
function Page() { return <FoundationScreen kind="settings" />; }
