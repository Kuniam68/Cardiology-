// Public configuration only. NEVER place a service-role key, password, or other secret here.
export const config = Object.freeze({
  paymentSandboxEnabled: false,
  paymentCheckoutEnabled: false,
  academyName: 'Cardiobug',
  supabaseUrl: 'https://zeneffylfgiyezpegqto.supabase.co',
  supabasePublishableKey: 'sb_publishable_8MQdRvaNvA4x2mZMRy3z0g_Q8ppjjyZ',
  contactEmail: '',
  // Enable only after the Google provider is configured in Supabase.
  googleSignIn: false,
  turnstileSiteKey: '0x4AAAAAAGEOAgSqIGZqRx5x',
  // off: no widget; optional: show/send tokens when available; required: require a token.
  // Leave optional until Supabase CAPTCHA enforcement is enabled and tested.
  turnstileMode: 'optional'
});

if(config.supabaseUrl!=='https://zeneffylfgiyezpegqto.supabase.co'||config.paymentSandboxEnabled!==false)throw new Error('Production configuration rejected.');
