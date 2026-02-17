Flow Left to Implement (From Use Case)

Phase 2: Data Quality Layer
Add Great Expectations/Deequ checks in staged layer
Profile data for null counts, distributions, outliers
Store validation audit trail in DynamoDB or Glue table
Generate alerts for data quality violations

Phase 3: RDS Data Source
Create rds-raw-to-staged job (extract from MySQL/PostgreSQL)
Create rds-staged-to-curated job (Iceberg upsert by primary key)
Handle incremental loads (CDC or timestamp-based)

Phase 4: CSV/JSON Data Source (hold off for now)
Create csv-json-raw-to-staged job (schema detection/inference)
Create csv-json-staged-to-curated job (multi-format support)

Phase 5: Orchestration
Step Functions workflow: trigger jobs sequentially
Error handling and retry logic
Dependency management (raw → staged → curated)

Phase 6: Governance & Access Control
Lake Formation LF-Tags for PII, domain, sensitivity
Row/column-level masking for sensitive data
Separate roles: analyst, ETL, ML teams

Phase 7: Analytics & BI
Athena views for common KPI queries
Redshift Spectrum federated queries
QuickSight dashboards (optional)

Phase 8: Cost Optimization & Monitoring
S3 lifecycle policies (move to Glacier after 180 days)
CloudWatch alarms for job failures and cost anomalies
Athena query limits and caching