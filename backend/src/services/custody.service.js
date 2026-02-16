const { query, withTransaction } = require('../config/database');
const logger = require('../utils/logger');
const { detectAnomaly } = require('../ml/anomalyDetector');
const CustodyRecord = require('../models/CustodyRecord');

/**
 * Custody Management Service
 * Handles firearm assignment, return, and history tracking
 * 
 * CHAIN-OF-CUSTODY FEATURES:
 * - Cross-unit transfers are explicitly detected and logged
 * - All custody events automatically append to chain-of-custody timeline
 * - Custody records are immutable after creation (enforced by DB triggers)
 */

/**
 * Assign custody of a firearm to an officer
 * @param {Object} custodyData
 * @returns {Promise<Object>}
 */
const assignCustody = async (custodyData) => {
    const {
        firearm_id,
        officer_id,
        unit_id,
        custody_type,
        assignment_reason,
        expected_return_date,
        notes,
        issued_by
    } = custodyData;

    try {
        return await withTransaction(async (client) => {
            // Check if firearm is available
            const firearmCheck = await client.query(
                'SELECT current_status, assigned_unit_id FROM firearms WHERE firearm_id = $1',
                [firearm_id]
            );

            if (firearmCheck.rows.length === 0) {
                throw new Error('Firearm not found');
            }

            if (firearmCheck.rows[0].current_status !== 'available') {
                throw new Error(`Firearm is currently ${firearmCheck.rows[0].current_status}`);
            }

            // Verify officer exists and belongs to the specified unit
            const officerCheck = await client.query(
                'SELECT officer_id, unit_id, is_active FROM officers WHERE officer_id = $1',
                [officer_id]
            );

            if (officerCheck.rows.length === 0) {
                throw new Error('Officer not found');
            }

            const officer = officerCheck.rows[0];

            if (!officer.is_active) {
                throw new Error('Cannot assign custody to inactive officer');
            }

            if (officer.unit_id !== unit_id) {
                throw new Error('Officer does not belong to this unit');
            }

            // CROSS-UNIT TRANSFER DETECTION
            const crossUnitCheck = await CustodyRecord.detectCrossUnitTransfer(firearm_id, unit_id);
            const isCrossUnitTransfer = crossUnitCheck.isCrossUnit;

            // Generate custody ID
            const idResult = await client.query(`SELECT 'CUS-' || LPAD(CAST(COALESCE(MAX(CAST(SUBSTRING(custody_id FROM 5) AS INTEGER)), 0) + 1 AS TEXT), 3, '0') as next_id FROM custody_records`);
            const custodyId = idResult.rows[0].next_id;

            // Create custody record
            const result = await client.query(
                `INSERT INTO custody_records (
                    custody_id, firearm_id, officer_id, unit_id, custody_type,
                    assignment_reason, expected_return_date, notes, issued_by
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                RETURNING *`,
                [
                    custodyId,
                    firearm_id,
                    officer_id,
                    unit_id,
                    custody_type,
                    assignment_reason,
                    expected_return_date || null,
                    notes || null,
                    issued_by
                ]
            );

            const custodyRecord = result.rows[0];

            // Update firearm status to in_custody
            await client.query(
                `UPDATE firearms 
                 SET current_status = 'in_custody', updated_at = CURRENT_TIMESTAMP
                 WHERE firearm_id = $1`,
                [firearm_id]
            );

            // Log cross-unit transfer in audit and movement tables
            if (isCrossUnitTransfer) {
                await client.query(`
                    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, new_values)
                    VALUES ($1, 'CROSS_UNIT_TRANSFER', 'custody_records', $2, $3)
                `, [
                    issued_by,
                    custodyRecord.custody_id,
                    JSON.stringify({
                        firearm_id,
                        from_unit_id: crossUnitCheck.previousUnitId,
                        from_unit_name: crossUnitCheck.previousUnitName,
                        to_unit_id: unit_id,
                        officer_id,
                        custody_type
                    })
                ]);

                logger.info(`Cross-unit transfer detected: Firearm ${firearm_id} moved from ${crossUnitCheck.previousUnitName} to unit ${unit_id}`);
            }

            logger.info(`Custody assigned: ${custodyRecord.custody_id}${isCrossUnitTransfer ? ' (CROSS-UNIT)' : ''}`);

            // Trigger anomaly detection asynchronously (don't block)
            // Cross-unit transfers are flagged as potential anomalies
            setImmediate(() => {
                detectAnomaly({ 
                    ...custodyRecord, 
                    is_cross_unit_transfer: isCrossUnitTransfer 
                }).catch(err => {
                    logger.error('Anomaly detection error:', err);
                });
            });

            return {
                ...custodyRecord,
                is_cross_unit_transfer: isCrossUnitTransfer,
                previous_unit: isCrossUnitTransfer ? crossUnitCheck.previousUnitName : null
            };
        });
    } catch (error) {
        logger.error('Assign custody error:', error);
        throw error;
    }
};

/**
 * Return custody of a firearm
 * @param {string} custodyId
 * @param {Object} returnData
 * @returns {Promise<Object>}
 */
const returnCustody = async (custodyId, returnData) => {
    const { returned_to, return_condition, notes } = returnData;
    
    // Ensure notes is null if undefined (PostgreSQL needs explicit null)
    const safeNotes = notes !== undefined ? notes : null;

    try {
        return await withTransaction(async (client) => {
            // Get custody record
            const custodyCheck = await client.query(
                'SELECT * FROM custody_records WHERE custody_id = $1',
                [custodyId]
            );

            if (custodyCheck.rows.length === 0) {
                throw new Error('Custody record not found');
            }

            const custody = custodyCheck.rows[0];

            if (custody.returned_at) {
                throw new Error('Custody already returned');
            }

            // Update custody record with return information
            const result = await client.query(
                `UPDATE custody_records 
         SET returned_at = CURRENT_TIMESTAMP,
             returned_to = $1,
             return_condition = $2,
             notes = CASE 
               WHEN $3::TEXT IS NOT NULL THEN CONCAT(COALESCE(notes, ''), ' | Return: ', $3::TEXT)
               ELSE notes 
             END
         WHERE custody_id = $4
         RETURNING *`,
                [returned_to, return_condition, safeNotes, custodyId]
            );

            const updatedRecord = result.rows[0];

            // Update firearm status based on return condition
            let newStatus = 'available';
            if (return_condition === 'needs_maintenance') {
                newStatus = 'maintenance';
            } else if (return_condition === 'damaged') {
                newStatus = 'maintenance';
            }

            await client.query(
                `UPDATE firearms 
         SET current_status = $1, updated_at = CURRENT_TIMESTAMP
         WHERE firearm_id = $2`,
                [newStatus, custody.firearm_id]
            );

            logger.info(`Custody returned: ${custodyId}`);

            return updatedRecord;
        });
    } catch (error) {
        logger.error('Return custody error:', error);
        throw error;
    }
};

/**
 * Get custody history for a firearm
 * @param {string} firearmId
 * @param {Object} options
 * @returns {Promise<Array>}
 */
const getFirearmCustodyHistory = async (firearmId, options = {}) => {
    try {
        const { limit = 50, offset = 0 } = options;

        const result = await query(
            `SELECT 
        cr.*,
        o.full_name as officer_name,
        o.officer_number,
        o.rank,
        u.unit_name,
        issued_by_user.full_name as issued_by_name,
        returned_to_user.full_name as returned_to_name
       FROM custody_records cr
       JOIN officers o ON cr.officer_id = o.officer_id
       JOIN units u ON cr.unit_id = u.unit_id
       LEFT JOIN users issued_by_user ON cr.issued_by = issued_by_user.user_id
       LEFT JOIN users returned_to_user ON cr.returned_to = returned_to_user.user_id
       WHERE cr.firearm_id = $1
       ORDER BY cr.issued_at DESC
       LIMIT $2 OFFSET $3`,
            [firearmId, limit, offset]
        );

        return result.rows;
    } catch (error) {
        logger.error('Get firearm custody history error:', error);
        throw error;
    }
};

/**
 * Get custody history for an officer
 * @param {string} officerId
 * @param {Object} options
 * @returns {Promise<Array>}
 */
const getOfficerCustodyHistory = async (officerId, options = {}) => {
    try {
        const { limit = 50, offset = 0 } = options;

        const result = await query(
            `SELECT 
        cr.*,
        f.serial_number,
        f.manufacturer,
        f.model,
        f.firearm_type,
        u.unit_name,
        issued_by_user.full_name as issued_by_name
       FROM custody_records cr
       JOIN firearms f ON cr.firearm_id = f.firearm_id
       JOIN units u ON cr.unit_id = u.unit_id
       LEFT JOIN users issued_by_user ON cr.issued_by = issued_by_user.user_id
       WHERE cr.officer_id = $1
       ORDER BY cr.issued_at DESC
       LIMIT $2 OFFSET $3`,
            [officerId, limit, offset]
        );

        return result.rows;
    } catch (error) {
        logger.error('Get officer custody history error:', error);
        throw error;
    }
};

/**
 * Get active custody assignments
 * @param {Object} filters
 * @returns {Promise<Array>}
 */
const getActiveCustody = async (filters = {}) => {
    try {
        const { unit_id, officer_id, limit = 100, offset = 0 } = filters;

        let whereClause = 'WHERE cr.returned_at IS NULL';
        let params = [];
        let paramCount = 0;

        if (unit_id) {
            paramCount++;
            whereClause += ` AND cr.unit_id = $${paramCount}`;
            params.push(unit_id);
        }

        if (officer_id) {
            paramCount++;
            whereClause += ` AND cr.officer_id = $${paramCount}`;
            params.push(officer_id);
        }

        paramCount++;
        params.push(limit);
        const limitParam = `$${paramCount}`;

        paramCount++;
        params.push(offset);
        const offsetParam = `$${paramCount}`;

        const result = await query(
            `SELECT 
        cr.*,
        cr.issued_at as assigned_date,
        f.serial_number as firearm_serial,
        f.manufacturer,
        f.model,
        f.firearm_type,
        o.full_name as officer_name,
        o.officer_number,
        o.rank,
        u.unit_name,
        CASE WHEN cr.returned_at IS NULL THEN 'active' ELSE 'returned' END as status
       FROM custody_records cr
       JOIN firearms f ON cr.firearm_id = f.firearm_id
       JOIN officers o ON cr.officer_id = o.officer_id
       JOIN units u ON cr.unit_id = u.unit_id
       ${whereClause}
       ORDER BY cr.issued_at DESC
       LIMIT ${limitParam} OFFSET ${offsetParam}`,
            params
        );

        return result.rows;
    } catch (error) {
        logger.error('Get active custody error:', error);
        throw error;
    }
};

/**
 * Get custody statistics for a unit
 * @param {string} unitId
 * @returns {Promise<Object>}
 */
const getUnitCustodyStats = async (unitId) => {
    try {
        const result = await query(
            `SELECT 
        COUNT(*) FILTER (WHERE returned_at IS NULL) as active_custody,
        COUNT(*) FILTER (WHERE returned_at IS NOT NULL) as total_returned,
        COUNT(DISTINCT officer_id) as officers_with_firearms,
        COUNT(DISTINCT firearm_id) as firearms_in_custody,
        AVG(custody_duration_seconds) FILTER (WHERE custody_duration_seconds IS NOT NULL) as avg_duration_seconds
       FROM custody_records
       WHERE unit_id = $1`,
            [unitId]
        );

        return result.rows[0];
    } catch (error) {
        logger.error('Get unit custody stats error:', error);
        throw error;
    }
};

/**
 * Get custody records for a specific unit (Station Commander use)
 * @param {string} unitId
 * @param {Object} options
 * @returns {Promise<Array>}
 */
const getUnitCustody = async (unitId, options = {}) => {
    try {
        const { status, custody_type, limit = 100, offset = 0 } = options;

        let whereClause = 'WHERE cr.unit_id = $1';
        let params = [unitId];
        let paramCount = 1;

        // Filter by status (active = not returned, returned = returned)
        if (status === 'active') {
            whereClause += ' AND cr.returned_at IS NULL';
        } else if (status === 'returned') {
            whereClause += ' AND cr.returned_at IS NOT NULL';
        }

        if (custody_type && custody_type !== 'all') {
            paramCount++;
            whereClause += ` AND cr.custody_type = $${paramCount}`;
            params.push(custody_type);
        }

        paramCount++;
        params.push(limit);
        const limitParam = `$${paramCount}`;

        paramCount++;
        params.push(offset);
        const offsetParam = `$${paramCount}`;

        const result = await query(
            `SELECT 
        cr.custody_id,
        cr.firearm_id,
        cr.officer_id,
        cr.custody_type,
        cr.issued_at as assigned_date,
        cr.returned_at,
        cr.return_condition,
        cr.notes,
        f.serial_number as firearm_serial,
        f.manufacturer,
        f.model,
        f.firearm_type,
        f.caliber,
        o.full_name as officer_name,
        o.officer_number,
        o.rank,
        u.unit_name,
        CASE WHEN cr.returned_at IS NULL THEN 'active' ELSE 'returned' END as status
       FROM custody_records cr
       JOIN firearms f ON cr.firearm_id = f.firearm_id
       JOIN officers o ON cr.officer_id = o.officer_id
       JOIN units u ON cr.unit_id = u.unit_id
       ${whereClause}
       ORDER BY cr.issued_at DESC
       LIMIT ${limitParam} OFFSET ${offsetParam}`,
            params
        );

        return result.rows;
    } catch (error) {
        logger.error('Get unit custody error:', error);
        throw error;
    }
};

module.exports = {
    assignCustody,
    returnCustody,
    getFirearmCustodyHistory,
    getOfficerCustodyHistory,
    getActiveCustody,
    getUnitCustody,
    getUnitCustodyStats
};
