const { query, withTransaction } = require('../config/database');
const logger = require('../utils/logger');
const { sendApprovalNotification } = require('./email.service');

/**
 * Workflow Service
 * Manages approval workflows for loss reports, destruction requests, and procurement requests
 */

/**
 * Submit a loss report
 * @param {Object} lossData
 * @returns {Promise<Object>}
 */
const submitLossReport = async (lossData) => {
    const {
        firearm_id,
        unit_id,
        reported_by,
        officer_id,
        loss_type,
        loss_date,
        loss_location,
        circumstances,
        police_case_number
    } = lossData;

    try {
        const result = await query(
            `INSERT INTO loss_reports (
        firearm_id, unit_id, reported_by, officer_id,
        loss_type, loss_date, loss_location, circumstances, police_case_number
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *`,
            [
                firearm_id,
                unit_id,
                reported_by,
                officer_id || null,
                loss_type,
                loss_date,
                loss_location,
                circumstances,
                police_case_number || null
            ]
        );

        logger.info(`Loss report submitted: ${result.rows[0].loss_id}`);

        return result.rows[0];
    } catch (error) {
        logger.error('Submit loss report error:', error);
        throw error;
    }
};

/**
 * Approve/reject a loss report
 * @param {string} lossId
 * @param {Object} approvalData
 * @returns {Promise<Object>}
 */
const processLossReport = async (lossId, approvalData) => {
    const { reviewed_by, status, review_notes } = approvalData;

    try {
        return await withTransaction(async (client) => {
            // Get loss report details
            const lossCheck = await client.query(
                'SELECT * FROM loss_reports WHERE loss_id = $1',
                [lossId]
            );

            if (lossCheck.rows.length === 0) {
                throw new Error('Loss report not found');
            }

            const lossReport = lossCheck.rows[0];

            // Guard against re-processing already reviewed reports
            if (lossReport.status !== 'pending') {
                throw new Error(`Loss report has already been ${lossReport.status}`);
            }

            // Update loss report status
            const result = await client.query(
                `UPDATE loss_reports 
         SET status = $1, reviewed_by = $2, review_date = CURRENT_TIMESTAMP, review_notes = $3
         WHERE loss_id = $4
         RETURNING *`,
                [status, reviewed_by, review_notes, lossId]
            );

            // If approved, update firearm status
            if (status === 'approved') {
                const newStatus = lossReport.loss_type === 'stolen' ? 'stolen' : 'lost';
                await client.query(
                    `UPDATE firearms 
           SET current_status = $1, updated_at = CURRENT_TIMESTAMP
           WHERE firearm_id = $2`,
                    [newStatus, lossReport.firearm_id]
                );
            }

            logger.info(`Loss report ${status}: ${lossId}`);

            // Send notification to reporter
            setImmediate(async () => {
                try {
                    const reporterResult = await query(
                        'SELECT email, full_name FROM users WHERE user_id = $1',
                        [lossReport.reported_by]
                    );

                    if (reporterResult.rows.length > 0) {
                        await sendApprovalNotification(
                            reporterResult.rows[0].email,
                            reporterResult.rows[0].full_name,
                            {
                                type: 'Loss Report',
                                status: status.toUpperCase(),
                                details: `Your loss report has been ${status}. ${review_notes || ''}`
                            }
                        );
                    }
                } catch (err) {
                    logger.error('Send loss report notification error:', err);
                }
            });

            return result.rows[0];
        });
    } catch (error) {
        logger.error('Process loss report error:', error);
        throw error;
    }
};

/**
 * Submit a destruction request
 * @param {Object} destructionData
 * @returns {Promise<Object>}
 */
const submitDestructionRequest = async (destructionData) => {
    const {
        firearm_id,
        unit_id,
        requested_by,
        destruction_reason,
        condition_description,
        supporting_documents
    } = destructionData;

    try {
        const result = await query(
            `INSERT INTO destruction_requests (
        firearm_id, unit_id, requested_by, destruction_reason,
        condition_description, supporting_documents
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *`,
            [
                firearm_id,
                unit_id,
                requested_by,
                destruction_reason,
                condition_description,
                supporting_documents || null
            ]
        );

        logger.info(`Destruction request submitted: ${result.rows[0].destruction_id}`);

        return result.rows[0];
    } catch (error) {
        logger.error('Submit destruction request error:', error);
        throw error;
    }
};

/**
 * Approve/reject a destruction request
 * @param {string} destructionId
 * @param {Object} approvalData
 * @returns {Promise<Object>}
 */
const processDestructionRequest = async (destructionId, approvalData) => {
    const { reviewed_by, status, review_notes } = approvalData;

    try {
        return await withTransaction(async (client) => {
            const destructionCheck = await client.query(
                'SELECT * FROM destruction_requests WHERE destruction_id = $1',
                [destructionId]
            );

            if (destructionCheck.rows.length === 0) {
                throw new Error('Destruction request not found');
            }

            const destructionRequest = destructionCheck.rows[0];

            // Guard against re-processing already reviewed requests
            if (destructionRequest.status !== 'pending') {
                throw new Error(`Destruction request has already been ${destructionRequest.status}`);
            }

            const result = await client.query(
                `UPDATE destruction_requests 
         SET status = $1, reviewed_by = $2, review_date = CURRENT_TIMESTAMP, review_notes = $3
         WHERE destruction_id = $4
         RETURNING *`,
                [status, reviewed_by, review_notes, destructionId]
            );

            if (status === 'approved') {
                await client.query(
                    `UPDATE firearms 
           SET current_status = 'destroyed', is_active = false, updated_at = CURRENT_TIMESTAMP
           WHERE firearm_id = $1`,
                    [destructionRequest.firearm_id]
                );
            }

            logger.info(`Destruction request ${status}: ${destructionId}`);

            return result.rows[0];
        });
    } catch (error) {
        logger.error('Process destruction request error:', error);
        throw error;
    }
};

/**
 * Submit a procurement request
 * @param {Object} procurementData
 * @returns {Promise<Object>}
 */
const submitProcurementRequest = async (procurementData) => {
    const {
        unit_id,
        requested_by,
        firearm_type,
        quantity,
        justification,
        priority,
        estimated_cost,
        preferred_supplier
    } = procurementData;

    try {
        const result = await query(
            `INSERT INTO procurement_requests (
        unit_id, requested_by, firearm_type, quantity, justification,
        priority, estimated_cost, preferred_supplier
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *`,
            [
                unit_id,
                requested_by,
                firearm_type,
                quantity,
                justification,
                priority || 'routine',
                estimated_cost || null,
                preferred_supplier || null
            ]
        );

        logger.info(`Procurement request submitted: ${result.rows[0].procurement_id}`);

        return result.rows[0];
    } catch (error) {
        logger.error('Submit procurement request error:', error);
        throw error;
    }
};

/**
 * Approve/reject a procurement request
 * @param {string} procurementId
 * @param {Object} approvalData
 * @returns {Promise<Object>}
 */
const processProcurementRequest = async (procurementId, approvalData) => {
    const { reviewed_by, status, review_notes } = approvalData;

    try {
        // Check current status before processing
        const checkResult = await query(
            'SELECT status FROM procurement_requests WHERE procurement_id = $1',
            [procurementId]
        );
        if (checkResult.rows.length === 0) {
            throw new Error('Procurement request not found');
        }
        if (checkResult.rows[0].status !== 'pending') {
            throw new Error(`Procurement request has already been ${checkResult.rows[0].status}`);
        }

        const result = await query(
            `UPDATE procurement_requests 
       SET status = $1, reviewed_by = $2, review_date = CURRENT_TIMESTAMP, review_notes = $3
       WHERE procurement_id = $4
       RETURNING *`,
            [status, reviewed_by, review_notes, procurementId]
        );

        if (result.rows.length === 0) {
            throw new Error('Procurement request not found');
        }

        logger.info(`Procurement request ${status}: ${procurementId}`);

        return result.rows[0];
    } catch (error) {
        logger.error('Process procurement request error:', error);
        throw error;
    }
};

/**
 * Get pending approvals for HQ Commander
 * @returns {Promise<Object>}
 */
const getPendingApprovals = async () => {
    try {
        const lossReports = await query(
            `SELECT 
        lr.*,
        f.serial_number,
        u.unit_name,
        reported_by_user.full_name as reported_by_name
       FROM loss_reports lr
       JOIN firearms f ON lr.firearm_id = f.firearm_id
       JOIN units u ON lr.unit_id = u.unit_id
       JOIN users reported_by_user ON lr.reported_by = reported_by_user.user_id
       WHERE lr.status = 'pending'
       ORDER BY lr.created_at DESC`
        );

        const destructionRequests = await query(
            `SELECT 
        dr.*,
        f.serial_number,
        u.unit_name,
        requested_by_user.full_name as requested_by_name
       FROM destruction_requests dr
       JOIN firearms f ON dr.firearm_id = f.firearm_id
       JOIN units u ON dr.unit_id = u.unit_id
       JOIN users requested_by_user ON dr.requested_by = requested_by_user.user_id
       WHERE dr.status = 'pending'
       ORDER BY dr.created_at DESC`
        );

        const procurementRequests = await query(
            `SELECT 
        pr.*,
        u.unit_name,
        requested_by_user.full_name as requested_by_name
       FROM procurement_requests pr
       JOIN units u ON pr.unit_id = u.unit_id
       JOIN users requested_by_user ON pr.requested_by = requested_by_user.user_id
       WHERE pr.status = 'pending'
       ORDER BY pr.created_at DESC`
        );

        return {
            loss_reports: lossReports.rows,
            destruction_requests: destructionRequests.rows,
            procurement_requests: procurementRequests.rows,
            total_pending: lossReports.rows.length + destructionRequests.rows.length + procurementRequests.rows.length
        };
    } catch (error) {
        logger.error('Get pending approvals error:', error);
        throw error;
    }
};

module.exports = {
    submitLossReport,
    processLossReport,
    submitDestructionRequest,
    processDestructionRequest,
    submitProcurementRequest,
    processProcurementRequest,
    getPendingApprovals
};
