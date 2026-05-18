-- Migration 028: Track ML training usage and store quality metrics

ALTER TABLE ml_training_features
    ADD COLUMN IF NOT EXISTS used_in_model_id VARCHAR(20);

ALTER TABLE ml_model_metadata
    ADD COLUMN IF NOT EXISTS precision_score DECIMAL(5,4),
    ADD COLUMN IF NOT EXISTS recall_score DECIMAL(5,4),
    ADD COLUMN IF NOT EXISTS f1_score DECIMAL(5,4),
    ADD COLUMN IF NOT EXISTS effectiveness_score DECIMAL(5,4),
    ADD COLUMN IF NOT EXISTS false_positive_rate_estimate DECIMAL(5,4);

CREATE INDEX IF NOT EXISTS idx_ml_training_features_unused
    ON ml_training_features (used_in_model_id, feature_extraction_date);
