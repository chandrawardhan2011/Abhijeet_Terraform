-- /opt/icp/db/seed.sql
-- Seed data for the ICP database.
-- The literal string __FLAG_<INSTANCE>__ is substituted at install time
-- by install.sh with the real HMAC-suffixed flag from flag_for().

USE icp;

-- Users: a regular user, a second regular user (for IDOR walking),
-- and the ICP_55 default-credential admin.
INSERT INTO users (id, username, password_md5, email, role) VALUES
  (1, 'rajesh',   MD5('Welcome@2026'), 'rajesh@icp.lab',   'user'),
  (2, 'priya',    MD5('Sunset#11'),    'priya@icp.lab',    'user'),
  (3, 'admin',    MD5('admin'),        'admin@icp.lab',    'adjuster');  -- ICP_55

-- Policies: row 7 carries the ICP_11 flag in flag_note (UNION-leak target).
INSERT INTO policies (id, name, plan, premium, flag_note) VALUES
  (1, 'TermLife Basic',     'TERM',     8500.00,  NULL),
  (2, 'TermLife Plus',      'TERM',    12500.00,  NULL),
  (3, 'Health Family',      'HEALTH',  18000.00,  NULL),
  (4, 'Health Senior',      'HEALTH',  24000.00,  NULL),
  (5, 'Motor Comprehensive','MOTOR',    9200.00,  NULL),
  (6, 'Travel Annual',      'TRAVEL',   3400.00,  NULL),
  (7, 'Home Standard',      'HOME',     5600.00,  '__FLAG_ICP_11__');

-- Claims: a couple per user so IDOR walking has something to find.
INSERT INTO claims (id, user_id, policy_id, description, status, fraud_flag) VALUES
  (1, 1, 1, 'Hospital admission March 2026',         'approved', 0),
  (2, 1, 5, 'Vehicle bumper damage',                  'review',   0),
  (3, 2, 3, 'Annual health check-up reimbursement',   'submitted',0),
  (4, 2, 6, 'Trip cancellation due to illness',       'review',   1),
  (5, 1, 7, 'Plumbing damage __FLAG_ICP_25_SINK__',   'submitted',0);  -- desc field for stored XSS demos

-- Settlements: history rows for ICP_32 (settlement-history IDOR).
INSERT INTO settlements (policy_id, amount, paid_on) VALUES
  (1, 145000.00, '2026-03-22'),
  (3,  18750.00, '2026-02-14'),
  (7,  __FLAG_ICP_32_AMT_PLACEHOLDER__, '2026-01-30');

-- Nominees: bank account ciphertext is set by install.sh after AES-ECB encrypt.
INSERT INTO nominees (id, policyholder_id, name, relation, bank_ifsc, bank_account_enc) VALUES
  (1, 1, 'Sunita Devi',  'spouse', 'SBIN0001234', UNHEX('__ENC_ICP_44_NOMINEE_1__')),
  (2, 2, 'Ravi Kumar',   'father', 'HDFC0009876', UNHEX('__ENC_ICP_44_NOMINEE_2__'));

-- Adjudication queue: a couple of claims sitting in 'queued' state.
INSERT INTO adjudications (claim_id, state, decision) VALUES
  (3, 'queued', 'pending'),
  (4, 'queued', 'pending');

-- Initial testimonials seeded by the Bureau of Communications.
INSERT INTO testimonials (author_name, body, submitted_at) VALUES
  ('R. Subramaniam, Hyderabad',
   'Our family has held a Shikra Term Life policy since 1984. When my wife required emergency surgery in 2019, the claim was settled within seven working days. The Bureau acted with both efficiency and discretion, and the cooperative model showed its worth.',
   '2026-01-14 11:20:00'),
  ('Mrs. P. Devi, Madras',
   'I appreciate that Shikra is not a corporation. There is no agent harassing me to upgrade. There is no quarterly target. There is only the policy, the premium, and the promise. This is enough.',
   '2026-02-03 09:45:00'),
  ('Capt. (Retd) A. Bhat, Bombay',
   'The Branch IV team handled my late father''s nominee record with care and patience over three weeks of correspondence. I commend the staff at Bombay branch by name: Mrs. Iyer, Mr. Pillai. The cooperative is fortunate to have them.',
   '2026-02-19 16:30:00'),
  ('Anonymous',
   'My motor claim was processed in four days. I had braced myself for paperwork. There was paperwork, but it was the right amount of paperwork.',
   '2026-03-08 13:15:00');
