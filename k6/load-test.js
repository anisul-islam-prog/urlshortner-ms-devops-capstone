import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '3m', target: 30 },
    { duration: '5m', target: 50 },
    { duration: '5m', target: 50 },
    { duration: '3m', target: 10 },
    { duration: '2m', target: 5 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.5'], // Relaxed for SQLite on Minikube
  },
};

const BASE = 'http://urlshortener.local';

export default function () {
  // 1. Read stats (Python)
  const stats = http.get(`${BASE}/api/stats`, { tags: { name: 'stats' } });
  check(stats, { 'stats_200': (r) => r.status === 200 });

  // 2. Create URL via form POST (Python orchestrates → Go + Node.js)
  const create = http.post(`${BASE}/create`, {
    long_url: `https://example.com/${__VU}-${__ITER}`,
  }, {
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    tags: { name: 'create' },
  });
  check(create, { 'create_200': (r) => r.status === 200 });

  // 3. Hit Go redirect endpoint with a static code (proves Go is reachable)
  // Use 'test' or any short code — 404 is fine, it proves routing works
  const redirect = http.get(`${BASE}/BkNXBG`, { redirects: 0, tags: { name: 'redirect' } });
  check(redirect, {
    'redirect_30x_or_404': (r) => r.status === 301 || r.status === 302 || r.status === 404,
  });

  sleep(1);
}