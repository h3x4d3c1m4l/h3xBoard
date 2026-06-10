// Runtime configuration. In Docker this file is overwritten at container start
// from the API_URL environment variable (see docker/40-h3xboard-config.sh).
// During local dev it stays empty, so the compile-time fallback
// (--dart-define=API_URL / Env.apiUrl) is used instead.
window.h3xboardConfig = {};
