// Public configuration only. NEVER place a service-role key, password, or other secret here.
export const config = {
  academyName: 'Cardiobug',
  supabaseUrl: '',
  supabasePublishableKey: '',
  contactEmail: '',
  // Enable only after the Google provider is configured in Supabase.
  googleSignIn: false,
  turnstileSiteKey: '',
  // off: no widget; optional: show/send tokens when available; required: require a token.
  // Leave optional until Supabase CAPTCHA enforcement is enabled and tested.
  turnstileMode: 'optional'
};
