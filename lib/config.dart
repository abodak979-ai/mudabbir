// Supabase project "app". The publishable key is safe to ship in the client:
// every table is protected by row-level security (each user sees only their rows).
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://vjagryktdtdbsazucuqm.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_cMs3EJTWMCUZcQNVwSJkUQ_Tt2AADJ6',
);

const appTimezone = 'Asia/Riyadh';

/// Deep link the sign-in email opens. Must also be listed in Supabase →
/// Authentication → URL Configuration → Redirect URLs.
const authRedirectUrl = 'com.mudabbir.mudabbir://login-callback';
