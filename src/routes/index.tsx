import { createFileRoute } from "@tanstack/react-router";
import { AuthScreen } from "@/components/erp/auth-screen";
import { pageHead } from "@/lib/erp/metadata";

// The home route ships no og:image, so serve-time hosting can inject the
// project's social preview (explicit og:image or latest screenshot).
export const Route = createFileRoute("/")({
  head: () => pageHead("Welcome", "Sign in to Logical Education ERP, your education organization workspace."),
  component: Index,
});

// IMPORTANT: Replace this placeholder. See ./README.md for routing conventions.
function Index() {
  return <AuthScreen />;
}
