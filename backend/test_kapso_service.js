const assert = require('assert');
const kapsoService = require('./services/kapsoService');

async function testKapsoService() {
  console.log('--- Testing KapsoService Unit Logic ---');

  // 0. Verify safe default paused state
  const pausedRes = await kapsoService.requestOtp('0918207786', 'customer');
  assert.strictEqual(pausedRes.disabled, true, 'Kapso should be paused by default unless KAPSO_ENABLED=true');
  console.log('✅ Default paused kill-switch passed.');

  kapsoService.enabled = true;

  // 1. Phone normalization
  const n1 = kapsoService.normalizePhone('0918207786');
  assert.strictEqual(n1, '218918207786', '0918207786 should normalize to 218918207786');

  const n2 = kapsoService.normalizePhone('+218918207786');
  assert.strictEqual(n2, '218918207786', '+218918207786 should normalize to 218918207786');

  const n3 = kapsoService.normalizePhone('918207786');
  assert.strictEqual(n3, '218918207786', '918207786 should normalize to 218918207786');
  console.log('✅ Phone normalization passed.');

  // 2. Request OTP
  const reqRes = await kapsoService.requestOtp('0918207786', 'customer');
  assert.strictEqual(reqRes.success, true);
  assert.strictEqual(reqRes.normalizedPhone, '218918207786');
  console.log('✅ Request OTP response:', reqRes.mode);

  // 3. Verify OTP negative case
  const failRes = kapsoService.verifyOtp('0918207786', '0000');
  assert.strictEqual(failRes.success, false);
  console.log('✅ Invalid OTP handled correctly.');

  // 4. Verify OTP positive case (retrieve stored OTP)
  const stored = kapsoService.otpStore.get('218918207786');
  assert.ok(stored, 'Stored OTP entry should exist');
  const validOtp = stored.otp;

  const successRes = kapsoService.verifyOtp('0918207786', validOtp);
  assert.strictEqual(successRes.success, true);
  assert.strictEqual(successRes.verified, true);
  console.log('✅ Valid OTP verification passed.');

  // 5. Replay attack prevention (consumed OTP)
  const replayRes = kapsoService.verifyOtp('0918207786', validOtp);
  assert.strictEqual(replayRes.success, false);
  console.log('✅ Replay attack prevented (OTP consumed).');

  console.log('🎉 All KapsoService tests passed successfully!');
}

testKapsoService().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
