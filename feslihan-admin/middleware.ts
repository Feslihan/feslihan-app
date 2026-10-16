import { clerkMiddleware } from "@clerk/nextjs/server";

// Session handling only — the UI gates itself with <SignedIn>/<SignedOut>,
// and real authorization lives in the backend's ADMIN_CLERK_IDS allowlist.
export default clerkMiddleware();

export const config = {
  matcher: [
    "/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)",
    "/(api|trpc)(.*)",
  ],
};
