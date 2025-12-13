-- SafeArms Initial Data Seed
-- Creates default HQ unit and admin user

-- Insert HQ Unit
INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, commander_name, is_active)
VALUES (
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'Rwanda National Police Headquarters',
    'headquarters',
    'Kacyiru, Kigali',
    'Kigali',
    'Gasabo',
    'Commissioner General',
    true
);

-- Insert Admin User
-- Default password: Admin@123 (must be changed on first login)
INSERT INTO users (
    user_id, 
    username, 
    password_hash, 
    full_name, 
    email, 
    phone_number, 
    role, 
    unit_id,
    otp_verified,
    unit_confirmed,
    is_active,
    must_change_password
) VALUES (
    'b0000000-0000-0000-0000-000000000001'::uuid,
    'admin',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'System Administrator',
    'admin@rnp.gov.rw',
    '+250788000000',
    'admin',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true,
    true,
    true,
    true
);

-- Note: To generate the password hash, run this in Node.js:
-- const bcrypt = require('bcrypt');
-- bcrypt.hash('Admin@123', 10).then(console.log);

COMMENT ON TABLE units IS 'Seeded with RNP Headquarters as default unit';
COMMENT ON TABLE users IS 'Seeded with admin user (username: admin, password: Admin@123)';
