"""
Glue ETL Job: RDS Staged → Curated (Iceberg)
Reads ONLY clean records from quality-checks/passed/, creates/merges Iceberg table with ACID support.

Data flow:
- Input: s3://bucket/quality-checks/rds/postgres/passed/ (only clean data)
- Output: s3://bucket/curated/rds/postgres/ (Iceberg table)
- Glue Catalog: data in lakehouse_dev_ufz9ae_catalog database (this is what is being used for testing)

Key features:
- MERGE/UPSERT using record_id as primary key
- Iceberg format-version=2 for ACID transactions
- Time-travel and data versioning support
"""

import sys
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, md5, concat_ws, rank
from pyspark.sql.window import Window

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

# Note: Iceberg configuration is set via Terraform job parameters (--conf flags)

logger.info(f"Starting: {args['JOB_NAME']}")

try:
    passed_path = f"s3://{args['datalake_bucket']}/quality-checks/rds/postgres/passed/"
    curated_path = f"s3://{args['datalake_bucket']}/curated/rds/postgres/"
    database = args['glue_database']
    table_name = "rds_postgres_curated"
    full_table = f"{database}.{table_name}"
    
    logger.info(f"Reading clean (passed) data from: {passed_path}")
    
    # Read only quality-passed Parquet data (filtered by quality job)
    df_staged = spark.read.parquet(passed_path)
    record_count = df_staged.count()
    logger.info(f"Read {record_count} clean records from quality-checks/passed")
    logger.info(f"Schema columns: {df_staged.columns}")
    
    # Ensure record_id exists; if not, generate it deterministically
    if "record_id" not in df_staged.columns:
        logger.info("record_id not found in data, generating it from business keys")
        # Generate from all columns for RDS data
        col_list = [col(c) for c in df_staged.columns if c not in ['ingestion_timestamp', 'curated_timestamp', 'record_id']]
        if col_list:
            df_staged = df_staged.withColumn(
                "record_id",
                md5(concat_ws("|", *col_list))
            )
        else:
            logger.warning("No columns available to generate record_id")
    
    # Deduplicate records by record_id (keep latest by ingestion_timestamp)
    logger.info("Deduplicating records by record_id")
    
    # Define window to rank by ingestion_timestamp (latest first)
    window_spec = Window.partitionBy(col("record_id")).orderBy(col("ingestion_timestamp").desc())
    df_deduped = df_staged.withColumn("rn", rank().over(window_spec)).filter(col("rn") == 1).drop("rn")
    
    dedup_count = df_deduped.count()
    logger.info(f"After deduplication: {dedup_count} unique records (removed {record_count - dedup_count} duplicates)")
    
    # Register as temp view for table creation
    df_deduped.createOrReplaceTempView("staged_data")
    
    # Set default catalog to glue_catalog for Iceberg table reference
    spark.sql("SET spark.sql.defaultCatalog = glue_catalog")
    
    # Create Iceberg table using simplified namespace (database.table)
    logger.info(f"Creating or updating Iceberg table: glue_catalog.{full_table}")
    
    # Check if table already exists
    table_exists = False
    try:
        spark.sql(f"SELECT 1 FROM {full_table} LIMIT 1")
        table_exists = True
        logger.info(f"Iceberg table {full_table} already exists")
    except:
        logger.info(f"Table does not exist, will create: {full_table}")
    
    if not table_exists:
        # Create empty table structure first
        logger.info(f"Creating Iceberg table structure: {full_table}")
        spark.sql(f"""
            CREATE TABLE {full_table}
            USING iceberg
            LOCATION '{curated_path}'
            TBLPROPERTIES ('format-version'='2')
            AS SELECT * FROM staged_data WHERE 1=0
        """)
        logger.info(f"Created table structure")
        
        # Now insert the actual data
        logger.info(f"Inserting initial data into {full_table}")
        spark.sql(f"""
            INSERT INTO {full_table}
            SELECT * FROM staged_data
        """)
        initial_count = spark.sql(f"SELECT COUNT(*) as cnt FROM {full_table}").collect()[0]['cnt']
        logger.info(f"Initial load complete: {initial_count} records")
    else:
        # Table exists, use MERGE for upsert logic
        logger.info(f"Executing MERGE to upsert data into {full_table}")
        merge_sql = f"""
            MERGE INTO {full_table} t
            USING staged_data s
            ON t.record_id = s.record_id
            WHEN MATCHED THEN UPDATE SET *
            WHEN NOT MATCHED THEN INSERT *
        """
        spark.sql(merge_sql)
        logger.info(f"MERGE completed")
    
    # Verify
    final_count = spark.sql(f"SELECT COUNT(*) as cnt FROM {full_table}").collect()[0]['cnt']
    logger.info(f"Success: Iceberg table {full_table} now has {final_count} records")
    
except Exception as e:
    logger.error(f"Failed: {str(e)}")
    raise
finally:
    job.commit()
