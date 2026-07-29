import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Baseline
    { duration: '3m', target: 30 },   // Pre-spike ramp
    { duration: '5m', target: 50 },   // Peak (M2-safe)
    { duration: '5m', target: 50 },   // Sustained peak
    { duration: '3m', target: 10 },   // Cooldown
    { duration: '2m', target: 5 },    // Back to baseline
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.3'],
  },
};

const BASE = 'http://urlshortener.local';

export default function () {
  // 1. Python: Read stats (lightweight, read-only)
  const stats = http.get(`${BASE}/api/stats`, { tags: { name: 'stats' } });
  check(stats, { 'stats_200': (r) => r.status === 200 });

  // 2. Python: Create URL via form POST
  // This internally orchestrates Python → Go + Node.js + SQLite writes
  const createRes = http.post(`${BASE}/create`, {
    long_url: `https://example.com/${__VU}-${__ITER}`,
  }, {
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    tags: { name: 'create' },
  });
  check(createRes, { 'create_200': (r) => r.status === 200 });

  // 3. Go: Test redirect endpoint with GET
  // redirects: 0 means we don't follow to external site (facebook/google etc)
  // We accept 301/302 (successful redirect) or 404 (short code doesn't exist — still proves Go is reachable)
  const redirectRes = http.get(`${BASE}/r/test123`, { redirects: 0, tags: { name: 'redirect' } });
  check(redirectRes, {
    'redirect_30x_or_404': (r) => r.status === 301 || r.status === 302 || r.status === 404,
  });

  sleep(1);
}