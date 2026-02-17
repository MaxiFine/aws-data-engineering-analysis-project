-- ==============================================================
-- Phase 7: Analytics & BI - Athena KPI Views (Public API)
-- ==============================================================
-- CMS Healthcare Provider Data - KPI views from Iceberg curated layer
-- Source: public_api_providers (curated/public-api/)
--
-- Table Columns and Data Types:
--   - rndrng_npi: string (National Provider Identifier)
--   - hcpcs_cd: string (Procedure/service code)
--   - tot_srvcs: string (Total services count - CAST to numeric)
--   - tot_benes: string (Total unique beneficiaries - CAST to numeric)
--   - avg_sbmtd_chrg: string (Average submitted charge - CAST to decimal)
--   - avg_mdcr_alowd_amt: string (Average Medicare allowed - CAST to decimal)
--   - avg_mdcr_pymt_amt: string (Average Medicare paid - CAST to decimal)
--   - year: int (Partition column - 2013-2023)
--   - record_id: string (MD5 hash of business key)
--   - ingestion_timestamp: timestamp (When data was ingested)
--
-- Usage: Execute in Athena Console with lakehouse-dev-wg workgroup
-- ==============================================================

USE lakehouse_dev_ufz9ae_catalog;

-- =====================================================
-- 1. Provider Performance KPIs
-- =====================================================
-- KPI: Top providers by total services rendered
CREATE OR REPLACE VIEW provider_service_volume AS
SELECT 
    rndrng_npi as provider_id,
    COUNT(*) as record_count,
    COUNT(DISTINCT hcpcs_cd) as unique_procedures,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as total_services_rendered,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as total_unique_beneficiaries,
    ROUND(AVG(CAST(tot_benes AS DOUBLE)), 2) as avg_beneficiaries_per_procedure,
    ROUND(SUM(CAST(tot_srvcs AS DOUBLE)) / NULLIF(SUM(CAST(tot_benes AS DOUBLE)), 0), 2) as services_per_beneficiary,
    MAX(year) as most_recent_year
FROM public_api_providers
WHERE rndrng_npi IS NOT NULL
    AND tot_srvcs IS NOT NULL
GROUP BY rndrng_npi
ORDER BY total_services_rendered DESC;

-- KPI: Top providers by total revenue (paid amount)
CREATE OR REPLACE VIEW provider_revenue_performance AS
SELECT 
    rndrng_npi as provider_id,
    COUNT(DISTINCT hcpcs_cd) as unique_procedures,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as total_services,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as total_beneficiaries,
    ROUND(SUM(CAST(avg_sbmtd_chrg AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_submitted_charges,
    ROUND(SUM(CAST(avg_mdcr_alowd_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_allowed_amount,
    ROUND(SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_paid,
    ROUND(AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as avg_payment_per_service,
    MAX(year) as most_recent_year
FROM public_api_providers
WHERE rndrng_npi IS NOT NULL
    AND avg_mdcr_pymt_amt IS NOT NULL
GROUP BY rndrng_npi
ORDER BY total_paid DESC;

-- KPI: Provider metrics by service type
CREATE OR REPLACE VIEW provider_service_analysis AS
SELECT 
    rndrng_npi as provider_id,
    hcpcs_cd as procedure_code,
    COUNT(*) as data_points,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as total_services,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as total_patients,
    ROUND(AVG(CAST(tot_srvcs AS DOUBLE)), 2) as avg_services_per_year,
    ROUND(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 2) as avg_submitted_charge,
    ROUND(AVG(CAST(avg_mdcr_alowd_amt AS DOUBLE)), 2) as avg_allowed_amount,
    ROUND(AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as avg_paid_amount,
    MAX(year) as most_recent_year
FROM public_api_providers
WHERE rndrng_npi IS NOT NULL
    AND hcpcs_cd IS NOT NULL
GROUP BY 
    rndrng_npi,
    hcpcs_cd
ORDER BY total_services DESC;

-- =====================================================
-- 2. Service/Procedure KPIs
-- =====================================================
-- KPI: Most commonly performed procedures
CREATE OR REPLACE VIEW top_procedures_by_volume AS
SELECT 
    hcpcs_cd as procedure_code,
    COUNT(DISTINCT rndrng_npi) as provider_count,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as total_services_nationwide,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as total_patients_nationwide,
    ROUND(SUM(CAST(tot_srvcs AS DOUBLE)) / NULLIF(COUNT(DISTINCT rndrng_npi), 0), 2) as avg_services_per_provider,
    ROUND(AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as avg_payment_per_service,
    ROUND(SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_paid_nationwide,
    MAX(year) as most_recent_year
FROM public_api_providers
WHERE hcpcs_cd IS NOT NULL
GROUP BY hcpcs_cd
ORDER BY total_services_nationwide DESC;

-- KPI: Procedure cost efficiency analysis
CREATE OR REPLACE VIEW procedure_cost_efficiency AS
SELECT 
    hcpcs_cd as procedure_code,
    COUNT(DISTINCT rndrng_npi) as providers_offering_service,
    ROUND(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 2) as avg_submitted_charge_nationwide,
    ROUND(AVG(CAST(avg_mdcr_alowd_amt AS DOUBLE)), 2) as avg_allowed_amount_nationwide,
    ROUND(AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as avg_paid_amount_nationwide,
    ROUND(100.0 * AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)) / NULLIF(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 0), 2) as payment_to_submitted_ratio_pct,
    ROUND(100.0 * AVG(CAST(avg_mdcr_alowd_amt AS DOUBLE)) / NULLIF(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 0), 2) as allowed_to_submitted_ratio_pct,
    ROUND(MIN(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as min_payment,
    ROUND(MAX(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as max_payment
FROM public_api_providers
WHERE hcpcs_cd IS NOT NULL
    AND CAST(avg_sbmtd_chrg AS DOUBLE) > 0
GROUP BY hcpcs_cd
ORDER BY procedure_code;

-- =====================================================
-- 3. Charge Submission Analysis
-- =====================================================
-- KPI: Provider charge accuracy
CREATE OR REPLACE VIEW provider_charge_accuracy AS
SELECT 
    rndrng_npi as provider_id,
    COUNT(*) as record_count,
    ROUND(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 2) as avg_submitted_per_service,
    ROUND(AVG(CAST(avg_mdcr_alowd_amt AS DOUBLE)), 2) as avg_allowed_per_service,
    ROUND(AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as avg_paid_per_service,
    ROUND(100.0 * AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)) / NULLIF(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 0), 2) as payment_accuracy_ratio_pct,
    CASE 
        WHEN 100.0 * AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)) / NULLIF(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 0) >= 95 THEN 'Excellent'
        WHEN 100.0 * AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)) / NULLIF(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 0) >= 85 THEN 'Good'
        WHEN 100.0 * AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)) / NULLIF(AVG(CAST(avg_sbmtd_chrg AS DOUBLE)), 0) >= 75 THEN 'Fair'
        ELSE 'Poor'
    END as accuracy_rating,
    MAX(year) as most_recent_year
FROM public_api_providers
WHERE rndrng_npi IS NOT NULL
GROUP BY rndrng_npi
ORDER BY payment_accuracy_ratio_pct DESC;

-- KPI: Beneficiary concentration risk
CREATE OR REPLACE VIEW beneficiary_concentration_analysis AS
SELECT 
    rndrng_npi as provider_id,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as total_services,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as total_beneficiaries,
    ROUND(SUM(CAST(tot_srvcs AS DOUBLE)) / NULLIF(SUM(CAST(tot_benes AS DOUBLE)), 0), 2) as services_per_beneficiary,
    CASE 
        WHEN SUM(CAST(tot_srvcs AS DOUBLE)) / NULLIF(SUM(CAST(tot_benes AS DOUBLE)), 0) >= 20 THEN 'Very High Concentration'
        WHEN SUM(CAST(tot_srvcs AS DOUBLE)) / NULLIF(SUM(CAST(tot_benes AS DOUBLE)), 0) >= 10 THEN 'High Concentration'
        WHEN SUM(CAST(tot_srvcs AS DOUBLE)) / NULLIF(SUM(CAST(tot_benes AS DOUBLE)), 0) >= 5 THEN 'Medium Concentration'
        ELSE 'Low Concentration'
    END as concentration_level,
    MAX(year) as most_recent_year
FROM public_api_providers
WHERE rndrng_npi IS NOT NULL
GROUP BY rndrng_npi
ORDER BY services_per_beneficiary DESC;

-- =====================================================
-- 4. Temporal Analysis
-- =====================================================
-- KPI: Year-over-year provider trends
CREATE OR REPLACE VIEW yoy_provider_trends AS
SELECT 
    rndrng_npi as provider_id,
    year,
    COUNT(DISTINCT hcpcs_cd) as unique_procedures,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as annual_services,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as annual_beneficiaries,
    ROUND(SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as annual_revenue,
    ROUND(AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as avg_payment_per_service
FROM public_api_providers
WHERE rndrng_npi IS NOT NULL
GROUP BY 
    rndrng_npi,
    year
ORDER BY rndrng_npi, year DESC;

-- KPI: Year-over-year procedure trends
CREATE OR REPLACE VIEW yoy_procedure_trends AS
SELECT 
    hcpcs_cd as procedure_code,
    year,
    COUNT(DISTINCT rndrng_npi) as providers_offering,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as annual_services_nationwide,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as annual_patients_nationwide,
    ROUND(AVG(CAST(avg_mdcr_pymt_amt AS DOUBLE)), 2) as avg_payment_per_service,
    ROUND(SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_paid_nationwide
FROM public_api_providers
WHERE hcpcs_cd IS NOT NULL
GROUP BY 
    hcpcs_cd,
    year
ORDER BY hcpcs_cd, year DESC;

-- =====================================================
-- 5. Executive Dashboard Summary
-- =====================================================
-- Single-row summary for quick executive insights
CREATE OR REPLACE VIEW executive_kpi_summary_public_api AS
SELECT 
    MAX(year) as data_year,
    COUNT(DISTINCT rndrng_npi) as total_providers,
    COUNT(DISTINCT hcpcs_cd) as unique_procedures,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as total_services_rendered,
    CAST(SUM(CAST(tot_benes AS DOUBLE)) AS BIGINT) as total_beneficiaries_served,
    ROUND(SUM(CAST(avg_sbmtd_chrg AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_submitted_charges,
    ROUND(SUM(CAST(avg_mdcr_alowd_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_allowed_charges,
    ROUND(SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as total_paid,
    ROUND(100.0 * SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)) / NULLIF(SUM(CAST(avg_sbmtd_chrg AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 0), 2) as overall_payment_ratio_pct,
    ROUND(SUM(CAST(tot_srvcs AS DOUBLE)) / NULLIF(SUM(CAST(tot_benes AS DOUBLE)), 0), 2) as avg_services_per_beneficiary
FROM public_api_providers;

-- =====================================================
-- 6. Benchmarking Views
-- =====================================================
-- KPI: Provider performance percentiles
CREATE OR REPLACE VIEW provider_revenue_percentiles AS
SELECT 
    rndrng_npi as provider_id,
    ROUND(SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)), 2) as provider_total_paid,
    ROUND(100.0 * SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE)) / SUM(SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE))) OVER (), 2) as pct_of_total_paid,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as provider_service_count,
    PERCENT_RANK() OVER (ORDER BY SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE))) as revenue_percentile,
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE))) >= 0.9 THEN 'Top 10%'
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE))) >= 0.75 THEN 'Top 25%'
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(CAST(avg_mdcr_pymt_amt AS DOUBLE) * CAST(tot_srvcs AS DOUBLE))) >= 0.5 THEN 'Top 50%'
        ELSE 'Bottom 50%'
    END as performance_tier
FROM public_api_providers
WHERE rndrng_npi IS NOT NULL
GROUP BY rndrng_npi
ORDER BY provider_total_paid DESC;

-- KPI: Procedure volume by percentile
CREATE OR REPLACE VIEW procedure_volume_percentiles AS
SELECT 
    hcpcs_cd as procedure_code,
    CAST(SUM(CAST(tot_srvcs AS DOUBLE)) AS BIGINT) as procedure_volume,
    ROUND(100.0 * SUM(CAST(tot_srvcs AS DOUBLE)) / SUM(SUM(CAST(tot_srvcs AS DOUBLE))) OVER (), 2) as pct_of_total_volume,
    COUNT(DISTINCT rndrng_npi) as provider_count,
    PERCENT_RANK() OVER (ORDER BY SUM(CAST(tot_srvcs AS DOUBLE))) as volume_percentile,
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(CAST(tot_srvcs AS DOUBLE))) >= 0.9 THEN 'Top 10% (High Volume)'
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(CAST(tot_srvcs AS DOUBLE))) >= 0.75 THEN 'Top 25% (Medium-High Volume)'
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(CAST(tot_srvcs AS DOUBLE))) >= 0.5 THEN 'Top 50% (Medium Volume)'
        ELSE 'Bottom 50% (Low Volume)'
    END as volume_tier
FROM public_api_providers
WHERE hcpcs_cd IS NOT NULL
GROUP BY hcpcs_cd
ORDER BY procedure_volume DESC;

-- =====================================================
-- 7. Data Quality Dashboard
-- =====================================================
-- View into data completeness and quality
CREATE OR REPLACE VIEW data_quality_overview AS
SELECT 
    year,
    COUNT(*) as total_records,
    COUNT(DISTINCT rndrng_npi) as unique_providers,
    COUNT(DISTINCT hcpcs_cd) as unique_procedures,
    COUNT(CASE WHEN rndrng_npi IS NOT NULL THEN 1 END) as records_with_provider,
    COUNT(CASE WHEN hcpcs_cd IS NOT NULL THEN 1 END) as records_with_procedure,
    COUNT(CASE WHEN tot_srvcs IS NOT NULL THEN 1 END) as records_with_services,
    COUNT(CASE WHEN tot_benes IS NOT NULL THEN 1 END) as records_with_beneficiaries,
    COUNT(CASE WHEN avg_mdcr_pymt_amt IS NOT NULL THEN 1 END) as records_with_payment,
    ROUND(100.0 * COUNT(CASE WHEN rndrng_npi IS NOT NULL THEN 1 END) / NULLIF(COUNT(*), 0), 2) as provider_completeness_pct,
    ROUND(100.0 * COUNT(CASE WHEN avg_mdcr_pymt_amt IS NOT NULL THEN 1 END) / NULLIF(COUNT(*), 0), 2) as payment_completeness_pct
FROM public_api_providers
GROUP BY year
ORDER BY year DESC;

-- =====================================================
-- Notes for Phase 7 Integration
-- =====================================================
-- 1. Time Travel Queries (Iceberg capability):
--    SELECT * FROM public_api_providers 
--    FOR SYSTEM_TIME AS OF TIMESTAMP '2025-11-15 10:00:00'
--    WHERE rndrng_npi = '1234567890'
--
-- 2. Partition Pruning: Queries leverage 'year' partition for performance
--    All views use year column which is partitioned in Iceberg
--
-- 3. Type Casting: All numeric calculations cast string columns to DOUBLE
--    - tot_srvcs, tot_benes cast to DOUBLE then to BIGINT for aggregations
--    - avg_sbmtd_chrg, avg_mdcr_alowd_amt, avg_mdcr_pymt_amt cast to DOUBLE
--
-- 4. Access Control: Lake Formation LF-Tags inherited:
--    - sensitivity: public (no PII in public CMS data)
--    - domain: healthcare
--
-- 5. Cost Optimization:
--    - Query results stored in athena-results S3 (7-day retention)
--    - Byte scanned limit: 1GB per query
--    - Partition pruning reduces bytes scanned significantly for year-based queries
--
-- 6. View Dependencies: All views depend on public_api_providers base table
--    Base table created at: s3://bucket/curated/public-api/
--    Partitioned by year (2013-2023)
