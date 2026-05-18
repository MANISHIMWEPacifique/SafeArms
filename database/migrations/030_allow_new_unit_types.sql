-- Add 'training_school' and 'special_unit' to unit_type validation
ALTER TABLE units DROP CONSTRAINT units_unit_type_check;
ALTER TABLE units ADD CONSTRAINT units_unit_type_check CHECK (unit_type IN ('headquarters', 'district', 'station', 'specialized', 'training_school', 'special_unit'));
