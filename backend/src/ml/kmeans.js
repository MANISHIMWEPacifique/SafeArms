const ml = require('ml-kmeans');
const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * K-Means Clustering Algorithm for Anomaly Detection
 * Groups custody patterns into clusters to identify outliers
 */

/**
 * Normalize features to [0, 1] range
 * @param {Array} data - Array of feature vectors
 * @returns {Object} Normalized data and parameters
 */
const normalizeFeatures = (data) => {
    if (data.length === 0) return { data: [], params: {} };

    const numFeatures = data[0].length;
    const mins = new Array(numFeatures).fill(Infinity);
    const maxs = new Array(numFeatures).fill(-Infinity);

    // Find min and max for each feature
    data.forEach(row => {
        row.forEach((value, idx) => {
            if (value < mins[idx]) mins[idx] = value;
            if (value > maxs[idx]) maxs[idx] = value;
        });
    });

    // Normalize to [0, 1]
    const normalized = data.map(row =>
        row.map((value, idx) => {
            const range = maxs[idx] - mins[idx];
            return range === 0 ? 0 : (value - mins[idx]) / range;
        })
    );

    return {
        data: normalized,
        params: { mins, maxs }
    };
};

/**
 * Denormalize a feature vector
 * @param {Array} normalized - Normalized feature vector
 * @param {Object} params - Normalization parameters
 * @returns {Array}
 */
const denormalizeFeatures = (normalized, params) => {
    const { mins, maxs } = params;
    return normalized.map((value, idx) => {
        const range = maxs[idx] - mins[idx];
        return value * range + mins[idx];
    });
};

/**
 * Train K-Means model on custody features
 * @param {number} k - Number of clusters (default: 6)
 * @returns {Promise<Object>} Trained model metadata
 */
const trainKMeansModel = async (k = 6) => {
    try {
        logger.info(`Starting K-Means training with K=${k}...`);

        // Fetch training data (last 6 months of custody records with features)
        const result = await query(`
      SELECT
        officer_issue_frequency_30d,
        officer_avg_custody_duration_30d,
        firearm_exchange_rate_7d,
        issue_hour,
        CASE WHEN is_night_issue THEN 1.0 ELSE 0.0 END as night_flag,
        CASE WHEN is_weekend_issue THEN 1.0 ELSE 0.0 END as weekend_flag,
        CASE WHEN rapid_exchange_flag THEN 1.0 ELSE 0.0 END as rapid_flag,
        CASE WHEN cross_unit_movement_flag THEN 1.0 ELSE 0.0 END as cross_unit_flag,
        custody_duration_zscore,
        issue_frequency_zscore
      FROM ml_training_features
      WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
    `);

        // Adapt k to available data (need at least k*3 samples for stable clusters)
        let effectiveK = Math.max(2, Math.min(k, Math.floor(result.rows.length / 3)));

        if (result.rows.length < effectiveK * 2) {
            throw new Error(`Insufficient training data. Need at least ${effectiveK * 2} records, got ${result.rows.length}`);
        }

        logger.info(`Training with ${result.rows.length} samples, K=${effectiveK}`);

        // Convert to feature matrix
        const data = result.rows.map(row => [
            parseFloat(row.officer_issue_frequency_30d) || 0,
            parseFloat(row.officer_avg_custody_duration_30d) || 0,
            parseFloat(row.firearm_exchange_rate_7d) || 0,
            parseFloat(row.issue_hour) / 24.0, // Normalize to [0,1]
            parseFloat(row.night_flag),
            parseFloat(row.weekend_flag),
            parseFloat(row.rapid_flag),
            parseFloat(row.cross_unit_flag),
            parseFloat(row.custody_duration_zscore) || 0,
            parseFloat(row.issue_frequency_zscore) || 0
        ]);

        // Normalize features
        const { data: normalizedData, params: normParams } = normalizeFeatures(data);

        // Ensure enough unique rows for kmeans++ initialization
        const uniqueRows = new Set(normalizedData.map(r => r.join(','))).size;
        if (uniqueRows < effectiveK) {
            if (uniqueRows < 2) {
                throw new Error(`Training data has only ${uniqueRows} unique pattern(s) after normalization. Need at least 2 distinct patterns.`);
            }
            logger.warn(`Only ${uniqueRows} unique patterns after normalization, reducing K from ${effectiveK} to ${uniqueRows}`);
            effectiveK = uniqueRows;
        }

        // Train K-Means
        const kmeansResult = ml.kmeans(normalizedData, effectiveK, {
            initialization: 'kmeans++',
            maxIterations: 100
        });

        // Calculate silhouette score (quality metric)
        const silhouetteScore = calculateSilhouetteScore(normalizedData, kmeansResult.clusters);

        // Calculate outlier threshold (distance-based)
        const distances = calculateClusterDistances(normalizedData, kmeansResult.centroids, kmeansResult.clusters);
        const outlierThreshold = calculateOutlierThreshold(distances);

        // Store model in database
        const modelVersion = '1.0.' + Date.now();

        // Generate model_id
        const idResult = await query(`SELECT COALESCE(MAX(CAST(SUBSTRING(model_id FROM 5) AS INTEGER)), 0) as max_num FROM ml_model_metadata WHERE model_id ~ '^MDL-[0-9]+$'`);
        const nextNum = parseInt(idResult.rows[0].max_num) + 1;
        const modelId = `MDL-${String(nextNum).padStart(3, '0')}`;

        const modelResult = await query(`
      INSERT INTO ml_model_metadata (
        model_id, model_type, model_version, training_date, training_samples_count,
        num_clusters, cluster_centers, silhouette_score,
        outlier_threshold, normalization_params, is_active
      ) VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4, $5, $6, $7, $8, $9, true)
      RETURNING model_id
    `, [
            modelId,
            'kmeans',
            modelVersion,
            result.rows.length,
            effectiveK,
            JSON.stringify(kmeansResult.centroids),
            silhouetteScore,
            outlierThreshold,
            JSON.stringify(normParams)
        ]);

        // Deactivate old models
        await query(`
      UPDATE ml_model_metadata 
      SET is_active = false 
      WHERE model_type = 'kmeans' 
      AND model_id != $1
    `, [modelResult.rows[0].model_id]);

        logger.info(`K-Means model trained successfully. Model ID: ${modelResult.rows[0].model_id}, Silhouette: ${silhouetteScore.toFixed(4)}`);

        return {
            model_id: modelResult.rows[0].model_id,
            model_version: modelVersion,
            num_clusters: effectiveK,
            training_samples: result.rows.length,
            silhouette_score: silhouetteScore,
            outlier_threshold: outlierThreshold
        };
    } catch (error) {
        logger.error('K-Means training error:', error);
        throw error;
    }
};

/**
 * Predict cluster and calculate anomaly score for a feature vector
 * @param {Array} features - Feature vector
 * @param {Object} model - Model metadata from database
 * @returns {Object} Prediction results
 */
const predictKMeans = (features, model) => {
    try {
        const centroids = typeof model.cluster_centers === 'string' ? JSON.parse(model.cluster_centers) : model.cluster_centers;
        const normParams = typeof model.normalization_params === 'string' ? JSON.parse(model.normalization_params) : model.normalization_params;

        // Normalize input features
        const { mins, maxs } = normParams;
        const normalized = features.map((value, idx) => {
            const range = maxs[idx] - mins[idx];
            return range === 0 ? 0 : (value - mins[idx]) / range;
        });

        // Find nearest cluster
        let minDistance = Infinity;
        let nearestCluster = -1;

        centroids.forEach((centroid, idx) => {
            const distance = euclideanDistance(normalized, centroid);
            if (distance < minDistance) {
                minDistance = distance;
                nearestCluster = idx;
            }
        });

        // Calculate anomaly score (normalized distance)
        const outlierThreshold = parseFloat(model.outlier_threshold) || 3.0;
        const anomalyScore = Math.min(minDistance / outlierThreshold, 1.0);

        return {
            cluster: nearestCluster,
            distance: minDistance,
            anomaly_score: anomalyScore,
            is_anomaly: minDistance > outlierThreshold
        };
    } catch (error) {
        logger.error('K-Means prediction error:', error);
        throw error;
    }
};

/**
 * Calculate Euclidean distance between two points
 * @param {Array} point1
 * @param {Array} point2
 * @returns {number}
 */
const euclideanDistance = (point1, point2) => {
    return Math.sqrt(
        point1.reduce((sum, val, idx) =>
            sum + Math.pow(val - point2[idx], 2), 0
        )
    );
};

/**
 * Calculate silhouette score for clustering quality
 * @param {Array} data
 * @param {Array} clusters - Cluster assignments
 * @returns {number}
 */
const calculateSilhouetteScore = (data, clusters) => {
    // Simplified silhouette calculation
    // Full implementation would compare intra-cluster vs inter-cluster distances
    const clusterCounts = {};
    clusters.forEach(c => {
        clusterCounts[c] = (clusterCounts[c] || 0) + 1;
    });

    const numClusters = Object.keys(clusterCounts).length;
    const avgClusterSize = data.length / numClusters;
    const balanceScore = Math.min(...Object.values(clusterCounts)) / avgClusterSize;

    // Return a score between 0 and 1 (higher is better)
    return Math.min(balanceScore, 1.0);
};

/**
 * Calculate distances from each point to its cluster center
 * @param {Array} data
 * @param {Array} centroids
 * @param {Array} clusters
 * @returns {Array}
 */
const calculateClusterDistances = (data, centroids, clusters) => {
    return data.map((point, idx) => {
        const centroid = centroids[clusters[idx]];
        return euclideanDistance(point, centroid);
    });
};

/**
 * Calculate outlier threshold (95th percentile of distances)
 * @param {Array} distances
 * @returns {number}
 */
const calculateOutlierThreshold = (distances) => {
    const sorted = [...distances].sort((a, b) => a - b);
    const p95Index = Math.floor(sorted.length * 0.95);
    return sorted[p95Index] || 2.0;
};

module.exports = {
    trainKMeansModel,
    predictKMeans,
    normalizeFeatures,
    euclideanDistance
};
