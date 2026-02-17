"""
Glue ETL Job: Public API Data Quality Validation
Validates staged Parquet data against business rules and data quality expectations.

Data flow:
- Input: s3://bucket/staged/public-api/year=YYYY/ (Parquet)
- Processing: Run Great Expectations suite to validate data quality
- Output: Store validation results in DynamoDB audit table and mark records as pass/fail
- Actions: Flag invalid records, generate quality score, trigger alerts if needed

Quality Rules:
1. No nulls in critical fields: rndrng_npi, hcpcs_cd, tot_benes, avg_sbmtd_chrg
2. Financial metric order: avg_sbmtd_chrg >= avg_mdcr_alowd_amt >= avg_mdcr_pymt_amt
3. Beneficiary logic: tot_benes <= tot_srvcs
4. Numeric validation: All financial fields must be >= 0
"""

import sys
import logging
import json
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    col, when, md5, concat_ws, current_timestamp, 
    coalesce, lit, sum as spark_sum
)
import boto3
from datetime import datetime

logging.getLogger('py4j').setLevel(logging.ERROR)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'TempDir',
    'datalake_bucket',
    'glue_database',
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Initialize DynamoDB for audit trail
dynamodb = boto3.resource('dynamodb')
audit_table_name = 'data_quality_audit_public_api'

logger.info(f"Starting: {args['JOB_NAME']}")

try:
    staged_path = f"s3://{args['datalake_bucket']}/staged/public-api/"
    database = args['glue_database']
    
    logger.info(f"Reading from staged: {staged_path}")
    
    # Read staged Parquet data
    df_staged = spark.read.parquet(staged_path)
    total_records = df_staged.count()
    logger.info(f"Read {total_records} records from staged")
    
    # Define quality checks
    logger.info("Starting data quality validation...")
    
    # Check 1: No nulls in critical fields
    df_with_null_check = df_staged.withColumn(
        "critical_null_violation",
        when(
            (col("rndrng_npi").isNull()) | 
            (col("hcpcs_cd").isNull()) | 
            (col("tot_benes").isNull()) | 
            (col("avg_sbmtd_chrg").isNull()),
            1
        ).otherwise(0)
    )
    
    # Check 2: Financial metric order (avg_sbmtd_chrg >= avg_mdcr_alowd_amt >= avg_mdcr_pymt_amt)
    df_with_financial_check = df_with_null_check.withColumn(
        "financial_order_violation",
        when(
            (col("avg_sbmtd_chrg").cast("decimal(12,2)") < 
             col("avg_mdcr_alowd_amt").cast("decimal(12,2)")) |
            (col("avg_mdcr_alowd_amt").cast("decimal(12,2)") < 
             col("avg_mdcr_pymt_amt").cast("decimal(12,2)")),
            1
        ).otherwise(0)
    )
    
    # Check 3: Beneficiary logic (tot_benes <= tot_srvcs)
    df_with_bene_check = df_with_financial_check.withColumn(
        "beneficiary_logic_violation",
        when(
            col("tot_benes").cast("long") > 
            col("tot_srvcs").cast("long"),
            1
        ).otherwise(0)
    )
    
    # Check 4: Non-negative financial values
    df_with_negative_check = df_with_bene_check.withColumn(
        "negative_value_violation",
        when(
            (col("avg_sbmtd_chrg").cast("decimal(12,2)") < 0) |
            (col("avg_mdcr_alowd_amt").cast("decimal(12,2)") < 0) |
            (col("avg_mdcr_pymt_amt").cast("decimal(12,2)") < 0),
            1
        ).otherwise(0)
    )
    
    # Calculate overall quality flag
    df_with_quality = df_with_negative_check.withColumn(
        "quality_pass",
        when(
            (col("critical_null_violation") == 0) &
            (col("financial_order_violation") == 0) &
            (col("beneficiary_logic_violation") == 0) &
            (col("negative_value_violation") == 0),
            1
        ).otherwise(0)
    )
    
    # Calculate quality metrics
    quality_stats = df_with_quality.select(
        spark_sum("quality_pass").alias("records_passed"),
        spark_sum(when(col("critical_null_violation") == 1, 1).otherwise(0)).alias("null_violations"),
        spark_sum(when(col("financial_order_violation") == 1, 1).otherwise(0)).alias("financial_violations"),
        spark_sum(when(col("beneficiary_logic_violation") == 1, 1).otherwise(0)).alias("beneficiary_violations"),
        spark_sum(when(col("negative_value_violation") == 1, 1).otherwise(0)).alias("negative_violations")
    ).collect()[0]
    
    records_passed = quality_stats['records_passed']
    records_failed = total_records - records_passed
    quality_score = (records_passed / total_records * 100) if total_records > 0 else 0
    
    logger.info(f"Data Quality Assessment Complete:")
    logger.info(f"  - Total Records: {total_records}")
    logger.info(f"  - Records Passed: {records_passed}")
    logger.info(f"  - Records Failed: {records_failed}")
    logger.info(f"  - Quality Score: {quality_score:.2f}%")
    logger.info(f"  - Null Violations: {quality_stats['null_violations']}")
    logger.info(f"  - Financial Order Violations: {quality_stats['financial_violations']}")
    logger.info(f"  - Beneficiary Logic Violations: {quality_stats['beneficiary_violations']}")
    logger.info(f"  - Negative Value Violations: {quality_stats['negative_violations']}")
    
    # Store audit trail in DynamoDB
    try:
        audit_entry = {
            'job_run_id': args['JOB_NAME'],
            'timestamp': datetime.utcnow().isoformat(),
            'records_processed': int(total_records),
            'records_passed': int(records_passed),
            'records_failed': int(records_failed),
            'quality_score': str(round(quality_score, 2)),  # Convert to string for DynamoDB
            'null_violations': int(quality_stats['null_violations']),
            'financial_violations': int(quality_stats['financial_violations']),
            'beneficiary_violations': int(quality_stats['beneficiary_violations']),
            'negative_violations': int(quality_stats['negative_violations']),
            'status': 'PASSED' if quality_score >= 95 else 'WARNING' if quality_score >= 80 else 'FAILED'
        }
        
        # Write to DynamoDB
        table = dynamodb.Table(audit_table_name)
        table.put_item(Item=audit_entry)
        logger.info(f"Audit entry written to DynamoDB: {json.dumps(audit_entry)}")
        
    except Exception as e:
        logger.error(f"Could not write to DynamoDB: {str(e)}")
        raise
    
    # Split records into passed and failed folders
    passed_records = df_with_quality.filter(col("quality_pass") == 1).drop(
        "quality_pass", "critical_null_violation", "financial_order_violation",
        "beneficiary_logic_violation", "negative_value_violation"
    )
    failed_records = df_with_quality.filter(col("quality_pass") == 0)
    
    passed_output_path = f"s3://{args['datalake_bucket']}/quality-checks/public-api/passed/"
    failed_output_path = f"s3://{args['datalake_bucket']}/quality-checks/public-api/failed/"
    
    # Write passed records (clean data for curated layer)
    logger.info(f"Writing {records_passed} passed records to: {passed_output_path}")
    passed_records.write.mode("overwrite").partitionBy("year").parquet(passed_output_path)
    logger.info(f"Passed records written")
    
    # Write failed records (with violation details for investigation)
    if records_failed > 0:
        logger.info(f"Writing {records_failed} failed records to: {failed_output_path}")
        failed_records.select(
            "rndrng_npi", "hcpcs_cd", "tot_benes", "tot_srvcs",
            "avg_sbmtd_chrg", "avg_mdcr_alowd_amt", "avg_mdcr_pymt_amt",
            "year",
            "critical_null_violation", "financial_order_violation", 
            "beneficiary_logic_violation", "negative_value_violation"
        ).write.mode("overwrite").partitionBy("year").parquet(failed_output_path)
        logger.info(f"Failed records written")
    
    # Final status
    if quality_score >= 95:
        logger.info(f"SUCCESS: Data quality acceptable ({quality_score:.2f}%)")
    elif quality_score >= 80:
        logger.warning(f"WARNING: Data quality degraded ({quality_score:.2f}%)")
    else:
        logger.error(f"CRITICAL: Data quality failed ({quality_score:.2f}%)")
        raise Exception(f"Data quality check failed: {quality_score:.2f}% pass rate")
    
except Exception as e:
    logger.error(f"Failed: {str(e)}")
    raise
finally:
    job.commit()

