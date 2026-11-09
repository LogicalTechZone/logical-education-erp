import { createFileRoute } from '@tanstack/react-router';
import { Onboarding } from '@/components/erp/foundation-screen';
import { pageHead } from '@/lib/erp/metadata';
export const Route = createFileRoute('/_authenticated/onboarding')({ head: () => pageHead('Organization onboarding', "Prepare details for your education organization."), component: Page });
function Page() { return <Onboarding  />; }
