const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * ML Feature Extractor for EVENT-Based Anomaly Detection
 * 
 * IMPORTANT: This system evaluates EVENTS, not people.
 * - Each custody event is analyzed independently
 * - Ballistic access timing relative to custody is a key feature
 * - Cross-unit transfers are always flagged for review
 * - Severity indicates REVIEW URGENCY, not wrongdoing
 * 
 * The system is unsupervised - it identifies unusual patterns
 * that warrant human review, not guilt or innocence.
 */

/**
 * Extract temporal features from custody record
 * @param {Object} custodyRecord
 * @returns {Object} Temporal features
 */
const extractTemporalFeatures = (custodyRecord) => {
    const issuedAt = new Date(custodyRecord.issued_at);

    return {
        issue_hour: custodyRecord.issue_hour,
        issue_day_of_week: custodyRecord.issue_day_of_week,
        is_night_issue: custodyRecord.is_night_issue,
        is_weekend_issue: custodyRecord.is_weekend_issue,
        timestamp: issuedAt.getTime()
    };
};

/**
 * Extract behavioral features from historical data
 * @param {string} officerId
 * @param {string} firearmId
 * @returns {Promise<Object>}
 */
const extractBehavioralFeatures = async (officerId, firearmId) => {
    try {
        // Officer's recent activity (last 30 days)
        const officerStats = await query(
            `SELECT 
        COUNT(*) as issue_count_30d,
        AVG(custody_duration_seconds) as avg_duration_30d,
        STDDEV(custody_duration_seconds) as stddev_duration_30d
       FROM custody_records
       WHERE officer_id = $1 
       AND issued_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'`,
            [officerId]
        );

        // Firearm's recent exchange rate (last 7 days)
        const firearmStats = await query(
            `SELECT 
        COUNT(*) as exchange_count_7d,
        COUNT(DISTINCT officer_id) as unique_officers_7d
       FROM custody_records
       WHERE firearm_id = $1 
       AND issued_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'`,
            [firearmId]
        );

        // Officer's consecutive same firearm count
        const consecutiveCount = await query(
            `SELECT COUNT(*) as consecutive_same_firearm
       FROM custody_records
       WHERE officer_id = $1 AND firearm_id = $2`,
            [officerId, firearmId]
        );

        const officerData = officerStats.rows[0] || {};
        const firearmData = firearmStats.rows[0] || {};
        const consecutiveData = consecutiveCount.rows[0] || {};

        return {
            officer_issue_frequency_30d: parseFloat(officerData.issue_count_30d || 0) / 30,
            officer_avg_custody_duration_30d: parseFloat(officerData.avg_duration_30d || 0),
            firearm_exchange_rate_7d: parseFloat(firearmData.exchange_count_7d || 0) / 7,
            consecutive_same_firearm_count: parseInt(consecutiveData.consecutive_same_firearm || 0)
        };
    } catch (error) {
        logger.error('Extract behavioral features error:', error);
        return {
            officer_issue_frequency_30d: 0,
            officer_avg_custody_duration_30d: 0,
            firearm_exchange_rate_7d: 0,
            consecutive_same_firearm_count: 0
        };
    }
};

/**
 * Extract cross-unit transfer context
 * Cross-unit transfers ALWAYS require review (organizational policy)
 * 
 * @param {Object} custodyRecord
 * @returns {Promise<Object>}
 */
const extractCrossUnitTransferContext = async (custodyRecord) => {
    try {
        const { firearm_id, unit_id, custody_id } = custodyRecord;

        // Get the previous custody record for this firearm
        const previousCustody = await query(`
            SELECT 
                cr.custody_id,
                cr.unit_id as previous_unit_id,
                u.unit_name as previous_unit_name,
                cr.returned_at,
                o.full_name as previous_officer_name
            FROM custody_records cr
            JOIN units u ON cr.unit_id = u.unit_id
            JOIN officers o ON cr.officer_id = o.officer_id
            WHERE cr.firearm_id = $1
            AND cr.custody_id != $2
            ORDER BY cr.issued_at DESC
            LIMIT 1
        `, [firearm_id, custody_id]);

        if (previousCustody.rows.length === 0) {
            return {
                is_cross_unit_transfer: false,
                previous_unit_id: null,
                previous_unit_name: null,
                cross_unit_transfer_count_30d: 0,
                is_first_custody: true
            };
        }

        const prevRecord = previousCustody.rows[0];
        const isCrossUnit = prevRecord.previous_unit_id !== unit_id;

        // Count cross-unit transfers in last 30 days for this firearm
        const crossUnitCount = await query(`
            WITH custody_with_prev AS (
                SELECT 
                    cr.custody_id,
                    cr.unit_id,
                    cr.issued_at,
                    LAG(cr.unit_id) OVER (ORDER BY cr.issued_at) as prev_unit_id
                FROM custody_records cr
                WHERE cr.firearm_id = $1
                AND cr.issued_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
            )
            SELECT COUNT(*) as count
            FROM custody_with_prev
            WHERE unit_id != prev_unit_id AND prev_unit_id IS NOT NULL
        `, [firearm_id]);

        return {
            is_cross_unit_transfer: isCrossUnit,
            previous_unit_id: prevRecord.previous_unit_id,
            previous_unit_name: isCrossUnit ? prevRecord.previous_unit_name : null,
            cross_unit_transfer_count_30d: parseInt(crossUnitCount.rows[0]?.count || 0),
            is_first_custody: false
        };
    } catch (error) {
        logger.error('Extract cross-unit transfer context error:', error);
        return {
            is_cross_unit_transfer: false,
            previous_unit_id: null,
            previous_unit_name: null,
            cross_unit_transfer_count_30d: 0,
            is_first_custody: false
        };
    }
};

/**
 * Detect pattern-based anomaly flags
 * @param {Object} custodyRecord
 * @returns {Promise<Object>}
 */
const extractPatternFlags = async (custodyRecord) => {
    try {
        const { firearm_id, officer_id, unit_id } = custodyRecord;

        // Check for rapid exchange (firearm returned and reissued within 1 hour)
        const rapidExchange = await query(
            `SELECT COUNT(*) as count
       FROM custody_records
       WHERE firearm_id = $1
       AND returned_at IS NOT NULL
       AND returned_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'`,
            [firearm_id]
        );

        // Check for cross-unit movement in officer's history
        const crossUnit = await query(
            `SELECT COUNT(*) as count
       FROM custody_records cr
       JOIN officers o ON cr.officer_id = o.officer_id
       WHERE cr.officer_id = $1
       AND o.unit_id != $2`,
            [officer_id, unit_id]
        );

        // Time since last return for this firearm
        const lastReturn = await query(
            `SELECT returned_at
       FROM custody_records
       WHERE firearm_id = $1 AND returned_at IS NOT NULL
       ORDER BY returned_at DESC
       LIMIT 1`,
            [firearm_id]
        );

        let timeSinceLastReturn = null;
        if (lastReturn.rows.length > 0) {
            const lastReturnTime = new Date(lastReturn.rows[0].returned_at);
            const now = new Date();
            timeSinceLastReturn = (now - lastReturnTime) / 1000; // seconds
        }

        return {
            rapid_exchange_flag: parseInt(rapidExchange.rows[0]?.count || 0) > 0,
            cross_unit_movement_flag: parseInt(crossUnit.rows[0]?.count || 0) > 0,
            time_since_last_return_seconds: timeSinceLastReturn
        };
    } catch (error) {
        logger.error('Extract pattern flags error:', error);
        return {
            rapid_exchange_flag: false,
            cross_unit_movement_flag: false,
            time_since_last_return_seconds: null
        };
    }
};

/**
 * Calculate statistical features (z-scores)
 * @param {Object} custodyRecord
 * @param {Object} behavioralFeatures
 * @returns {Promise<Object>}
 */
const extractStatisticalFeatures = async (custodyRecord, behavioralFeatures) => {
    try {
        // Get population statistics for custody duration
        const durationStats = await query(
            `SELECT 
        AVG(custody_duration_seconds) as mean,
        STDDEV(custody_duration_seconds) as stddev
       FROM custody_records
       WHERE custody_duration_seconds IS NOT NULL`
        );

        // Get population statistics for issue frequency
        const frequencyStats = await query(
            `SELECT 
        AVG(issue_frequency) as mean,
        STDDEV(issue_frequency) as stddev
       FROM (
         SELECT officer_id, COUNT(*)::DECIMAL / 30 as issue_frequency
         FROM custody_records
         WHERE issued_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
         GROUP BY officer_id
       ) freq_table`
        );

        const durationData = durationStats.rows[0] || {};
        const frequencyData = frequencyStats.rows[0] || {};

        // Calculate z-scores
        const durationMean = parseFloat(durationData.mean || 0);
        const durationStddev = parseFloat(durationData.stddev || 1);
        const frequencyMean = parseFloat(frequencyData.mean || 0);
        const frequencyStddev = parseFloat(frequencyData.stddev || 1);

        // For new custody (not yet returned), estimate duration as expected duration
        const estimatedDuration = behavioralFeatures.officer_avg_custody_duration_30d || durationMean;

        const custodyDurationZScore = durationStddev > 0
            ? (estimatedDuration - durationMean) / durationStddev
            : 0;

        const issueFrequencyZScore = frequencyStddev > 0
            ? (behavioralFeatures.officer_issue_frequency_30d - frequencyMean) / frequencyStddev
            : 0;

        return {
            custody_duration_zscore: custodyDurationZScore,
            issue_frequency_zscore: issueFrequencyZScore
        };
    } catch (error) {
        logger.error('Extract statistical features error:', error);
        return {
            custody_duration_zscore: 0,
            issue_frequency_zscore: 0
        };
    }
};

/**
 * Extract ballistic-access context features relative to custody events
 * 
 * KEY FEATURE: Timing of ballistic access relative to custody changes
 * - Access during active custody
 * - Access shortly before/after custody transfer
 * - Access patterns around cross-unit movements
 * 
 * @param {string} firearmId
 * @param {Object} custodyRecord - Current custody event for timing context
 * @returns {Promise<Object>}
 */
const extractBallisticContext = async (firearmId, custodyRecord = null) => {
    try {
        // Check if firearm has ballistic profile
        const ballisticProfile = await query(
            `SELECT ballistic_id, test_date, is_locked 
             FROM ballistic_profiles 
             WHERE firearm_id = $1`,
            [firearmId]
        );

        const hasBallisticProfile = ballisticProfile.rows.length > 0;
        
        if (!hasBallisticProfile) {
            return {
                has_ballistic_profile: false,
                ballistic_accesses_7d: 0,
                ballistic_accesses_24h: 0,
                ballistic_access_during_custody: false,
                ballistic_access_before_custody_hours: null,
                ballistic_access_after_custody_hours: null,
                ballistic_access_timing_score: 0
            };
        }

        // Get ballistic access count in last 7 days and 24 hours
        const accessCounts = await query(
            `SELECT 
                COUNT(*) FILTER (WHERE accessed_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') as accesses_7d,
                COUNT(*) FILTER (WHERE accessed_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours') as accesses_24h
             FROM ballistic_access_logs
             WHERE firearm_id = $1`,
            [firearmId]
        );

        const accesses7d = parseInt(accessCounts.rows[0]?.accesses_7d || 0);
        const accesses24h = parseInt(accessCounts.rows[0]?.accesses_24h || 0);

        // If we have custody context, analyze timing
        let ballisticAccessDuringCustody = false;
        let accessBeforeCustodyHours = null;
        let accessAfterCustodyHours = null;
        let timingScore = 0;

        if (custodyRecord && custodyRecord.issued_at) {
            const issuedAt = new Date(custodyRecord.issued_at);
            const returnedAt = custodyRecord.returned_at ? new Date(custodyRecord.returned_at) : null;

            // Find ballistic accesses relative to this custody event
            const timingAnalysis = await query(`
                SELECT 
                    accessed_at,
                    CASE 
                        WHEN accessed_at >= $2 AND (accessed_at <= $3 OR $3 IS NULL) THEN 'during'
                        WHEN accessed_at < $2 THEN 'before'
                        ELSE 'after'
                    END as timing_category,
                    EXTRACT(EPOCH FROM (accessed_at - $2)) / 3600.0 as hours_from_issue
                FROM ballistic_access_logs
                WHERE firearm_id = $1
                AND accessed_at >= $2 - INTERVAL '48 hours'
                AND accessed_at <= COALESCE($3, CURRENT_TIMESTAMP) + INTERVAL '48 hours'
                ORDER BY accessed_at
            `, [firearmId, issuedAt, returnedAt]);

            for (const access of timingAnalysis.rows) {
                const hoursFromIssue = parseFloat(access.hours_from_issue);

                if (access.timing_category === 'during') {
                    ballisticAccessDuringCustody = true;
                } else if (access.timing_category === 'before' && hoursFromIssue > -48) {
                    accessBeforeCustodyHours = accessBeforeCustodyHours === null 
                        ? Math.abs(hoursFromIssue) 
                        : Math.min(accessBeforeCustodyHours, Math.abs(hoursFromIssue));
                } else if (access.timing_category === 'after') {
                    accessAfterCustodyHours = accessAfterCustodyHours === null
                        ? hoursFromIssue
                        : Math.min(accessAfterCustodyHours, hoursFromIssue);
                }
            }

            // Calculate timing score (higher = more suspicious timing pattern)
            // Note: "Suspicious" means warrants review, NOT wrongdoing
            if (ballisticAccessDuringCustody) {
                timingScore += 0.3; // Access during custody is normal for forensic work
            }
            if (accessBeforeCustodyHours !== null && accessBeforeCustodyHours < 6) {
                timingScore += 0.5; // Access within 6h before custody change
            }
            if (accessAfterCustodyHours !== null && accessAfterCustodyHours < 6) {
                timingScore += 0.5; // Access within 6h after custody change
            }
            if (accesses24h > 3) {
                timingScore += 0.4; // High access frequency
            }
        }

        return {
            has_ballistic_profile: true,
            ballistic_accesses_7d: accesses7d,
            ballistic_accesses_24h: accesses24h,
            ballistic_access_during_custody: ballisticAccessDuringCustody,
            ballistic_access_before_custody_hours: accessBeforeCustodyHours,
            ballistic_access_after_custody_hours: accessAfterCustodyHours,
            ballistic_access_timing_score: Math.min(timingScore, 1.0)
        };
    } catch (error) {
        logger.error('Extract ballistic context error:', error);
        return {
            has_ballistic_profile: false,
            ballistic_accesses_7d: 0,
            ballistic_accesses_24h: 0,
            ballistic_access_during_custody: false,
            ballistic_access_before_custody_hours: null,
            ballistic_access_after_custody_hours: null,
            ballistic_access_timing_score: 0
        };
    }
};

/**
 * Extract all features from a custody record (EVENT-BASED)
 * 
 * IMPORTANT: This extracts features for a single EVENT, not a person.
 * The ML system evaluates custody events independently.
 * 
 * @param {Object} custodyRecord
 * @returns {Promise<Object>} Complete feature set for this event
 */
const extractAllFeatures = async (custodyRecord) => {
    try {
        const { officer_id, firearm_id, custody_id, unit_id } = custodyRecord;

        // Extract all feature types in parallel where possible
        const [
            behavioral,
            patternFlags,
            crossUnitContext,
            ballisticContext
        ] = await Promise.all([
            extractBehavioralFeatures(officer_id, firearm_id),
            extractPatternFlags(custodyRecord),
            extractCrossUnitTransferContext(custodyRecord),
            extractBallisticContext(firearm_id, custodyRecord) // Pass custody for timing context
        ]);

        // Extract features that depend on others
        const temporal = extractTemporalFeatures(custodyRecord);
        const statistical = await extractStatisticalFeatures(custodyRecord, behavioral);

        // Build event context for anomaly records
        const eventContext = {
            event_type: 'custody_assignment',
            event_id: custody_id,
            firearm_id,
            officer_id,
            unit_id,
            is_cross_unit_transfer: crossUnitContext.is_cross_unit_transfer,
            previous_unit_id: crossUnitContext.previous_unit_id,
            previous_unit_name: crossUnitContext.previous_unit_name,
            is_first_custody: crossUnitContext.is_first_custody
        };

        // Combine all features
        const features = {
            custody_id,
            event_context: eventContext,
            ...temporal,
            ...behavioral,
            ...patternFlags,
            ...crossUnitContext,
            ...statistical,
            ...ballisticContext,
            extracted_at: new Date()
        };

        logger.info(`Features extracted for custody: ${custody_id}`);

        // Store features in database for model training
        await storeFeatures(custodyRecord, features);

        return features;
    } catch (error) {
        logger.error('Extract all features error:', error);
        throw error;
    }
};

/**
 * Store extracted features in ml_training_features table
 * @param {Object} custodyRecord
 * @param {Object} features
 * @returns {Promise<void>}
 */
const storeFeatures = async (custodyRecord, features) => {
    try {
        await query(
            `INSERT INTO ml_training_features (
        officer_id, firearm_id, unit_id, custody_record_id,
        custody_duration_seconds, issue_hour, issue_day_of_week,
        is_night_issue, is_weekend_issue,
        officer_issue_frequency_30d, officer_avg_custody_duration_30d,
        firearm_exchange_rate_7d, officer_unit_consistency_score,
        time_since_last_return_seconds, consecutive_same_firearm_count,
        cross_unit_movement_flag, rapid_exchange_flag,
        custody_duration_zscore, issue_frequency_zscore,
        has_ballistic_profile, ballistic_accesses_7d
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)`,
            [
                custodyRecord.officer_id,
                custodyRecord.firearm_id,
                custodyRecord.unit_id,
                custodyRecord.custody_id,
                custodyRecord.custody_duration_seconds || 0,
                features.issue_hour,
                features.issue_day_of_week,
                features.is_night_issue,
                features.is_weekend_issue,
                features.officer_issue_frequency_30d,
                features.officer_avg_custody_duration_30d,
                features.firearm_exchange_rate_7d,
                1.0, // unit_consistency_score (placeholder)
                features.time_since_last_return_seconds,
                features.consecutive_same_firearm_count,
                features.cross_unit_movement_flag,
                features.rapid_exchange_flag,
                features.custody_duration_zscore,
                features.issue_frequency_zscore,
                features.has_ballistic_profile,
                features.ballistic_accesses_7d,
                // New chain-of-custody and ballistic timing features
                features.is_cross_unit_transfer,
                features.cross_unit_transfer_count_30d,
                features.ballistic_accesses_24h,
                features.ballistic_access_timing_score,
                JSON.stringify(features.event_context)
            ]
        );
    } catch (error) {
        logger.error('Store features error:', error);
        // Don't throw - feature storage failure shouldn't break custody operations
    }
};

module.exports = {
    extractAllFeatures,
    extractTemporalFeatures,
    extractBehavioralFeatures,
    extractPatternFlags,
    extractStatisticalFeatures,
    extractBallisticContext,
    extractCrossUnitTransferContext
};
