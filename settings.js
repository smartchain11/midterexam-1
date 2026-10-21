export const defaultPublicConfig = {
  supabaseUrl: 'https://waynzfydjphietbvrbsy.supabase.co',
  supabaseAnonKey: 'sb_publishable_CAMmzecMFnFNouUhqg8wRQ_Ez-r2xQV'
};

export function isPublicConfig(value) {
  if (!value || typeof value.supabaseUrl !== 'string' || typeof value.supabaseAnonKey !== 'string') return false;
  try {
    const url = new URL(value.supabaseUrl);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || !['', '/'].includes(url.pathname)) return false;
    if (url.hostname === 'your_project.supabase.co' || value.supabaseAnonKey.startsWith('YOUR_')) return false;
    if (/^sb_publishable_[A-Za-z0-9_-]+$/.test(value.supabaseAnonKey)) return true;
    const token = value.supabaseAnonKey.split('.');
    if (token.length !== 3) return false;
    const payload = JSON.parse(atob(token[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload.role === 'anon';
  } catch { return false; }
}

export function resolvePublicConfig(override, fallback = defaultPublicConfig) {
  if (isPublicConfig(override)) return override;
  return isPublicConfig(fallback) ? fallback : null;
}
