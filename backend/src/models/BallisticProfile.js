const { query } = require('../config/database');

const BallisticProfile = {
    async findById(ballisticId) {
        const result = await query(`
      SELECT bp.*, f.serial_number, f.manufacturer, f.model
      FROM ballistic_profiles bp
      JOIN firearms f ON bp.firearm_id = f.firearm_id
      WHERE bp.ballistic_id = $1
    `, [ballisticId]);
        return result.rows[0];
    },

    async findByFirearmId(firearmId) {
        const result = await query(
            'SELECT * FROM ballistic_profiles WHERE firearm_id = $1',
            [firearmId]
        );
        return result.rows[0];
    },

    async create(profileData) {
        const { firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, extractor_marks, chamber_marks, test_conducted_by, forensic_lab, test_ammunition, notes } = profileData;

        const result = await query(`
      INSERT INTO ballistic_profiles (
        firearm_id, test_date, test_location, rifling_characteristics,
        firing_pin_impression, ejector_marks, extractor_marks, chamber_marks,
        test_conducted_by, forensic_lab, test_ammunition, notes
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING *
    `, [firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, extractor_marks, chamber_marks, test_conducted_by, forensic_lab, test_ammunition, notes]);

        return result.rows[0];
    },

    // UPDATE REMOVED - Ballistic profiles are immutable after HQ registration
    // This ensures forensic integrity for investigative search and matching purposes

    async search(searchParams) {
        const { test_location, forensic_lab, limit = 50 } = searchParams;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (test_location) {
            pCount++;
            where += ` AND test_location ILIKE $${pCount}`;
            params.push(`%${test_location}%`);
        }

        if (forensic_lab) {
            pCount++;
            where += ` AND forensic_lab = $${pCount}`;
            params.push(forensic_lab);
        }

        pCount++;
        params.push(limit);

        const result = await query(`
      SELECT bp.*, f.serial_number, f.manufacturer, f.model
      FROM ballistic_profiles bp
      JOIN firearms f ON bp.firearm_id = f.firearm_id
      ${where}
      ORDER BY bp.test_date DESC
      LIMIT $${pCount}
    `, params);
        return result.rows;
    }
};

module.exports = BallisticProfile;
