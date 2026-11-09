import { createFileRoute } from '@tanstack/react-router';
import { FoundationScreen } from '@/components/erp/foundation-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/_authenticated/app/branches')({ head: () => pageHead('Branches', "Organization branch management workspace."), component: Page });
function Page() { return <FoundationScreen kind="branches" />; }
