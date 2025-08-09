#!/usr/bin/env node
/* End-to-end MVP happy-path exercise using the running API */

const base = process.env.API_URL || 'http://localhost:3000/api';

async function main() {
  const email = `user${Date.now()}@example.com`;
  const password = 'Password123!';
  const name = 'Alex Roomie';

  const headers = { 'content-type': 'application/json' };

  // Register
  let res = await fetch(`${base}/auth/register`, {
    method: 'POST', headers, body: JSON.stringify({ email, password, name })
  });
  let body = await res.json();
  console.log('REGISTER', res.status, body.message);
  if (!res.ok) throw new Error('register failed');
  let token = body.data?.token;

  const auth = () => ({ authorization: `Bearer ${token}` });

  // Create household
  res = await fetch(`${base}/households`, {
    method: 'POST', headers: { ...headers, ...auth() }, body: JSON.stringify({ name: 'E2E Household' })
  });
  body = await res.json();
  console.log('CREATE_HOUSEHOLD', res.status, body.message);
  if (!res.ok) throw new Error('create household failed');
  const householdId = body.data?.id;

  // Create task
  res = await fetch(`${base}/tasks`, {
    method: 'POST', headers: { ...headers, ...auth() }, body: JSON.stringify({ title: 'E2E Task', points: 10, householdId })
  });
  body = await res.json();
  console.log('CREATE_TASK', res.status, body.message);
  if (!res.ok) throw new Error('create task failed');
  const taskId = body.data?.id;

  // Complete task
  res = await fetch(`${base}/tasks/${taskId}/complete`, { method: 'POST', headers: { 'content-type': 'application/json', ...auth() }, body: JSON.stringify({}) });
  body = await res.json();
  console.log('COMPLETE_TASK', res.status, body.message);
  if (!res.ok) throw new Error('complete task failed');

  // Create reward
  res = await fetch(`${base}/rewards`, {
    method: 'POST', headers: { ...headers, ...auth() }, body: JSON.stringify({ name: 'E2E Reward', cost: 5, householdId })
  });
  body = await res.json();
  console.log('CREATE_REWARD', res.status, body.message);
  if (!res.ok) throw new Error('create reward failed');
  const rewardId = body.data?.id;

  // List rewards
  res = await fetch(`${base}/rewards/household/${householdId}`, { headers: { ...auth() } });
  body = await res.json();
  console.log('LIST_REWARDS', res.status, Array.isArray(body.data) ? body.data.length : (body.data?.length || 0));
  if (!res.ok) throw new Error('list rewards failed');

  // Redeem reward
  res = await fetch(`${base}/rewards/${rewardId}/redeem`, { method: 'POST', headers: { 'content-type': 'application/json', ...auth() }, body: JSON.stringify({}) });
  body = await res.json();
  console.log('REDEEM_REWARD', res.status, body.message);
  if (!res.ok) throw new Error('redeem reward failed');

  // Leaderboard
  res = await fetch(`${base}/gamification/leaderboard/${householdId}`, { headers: { ...auth() } });
  body = await res.json();
  console.log('LEADERBOARD', res.status, body?.data?.leaderboard?.length ?? 0);
  if (!res.ok) throw new Error('leaderboard failed');

  console.log('\n✅ E2E MVP flow completed successfully');
}

main().catch(e => { console.error('❌ E2E failed', e); process.exit(1); });


