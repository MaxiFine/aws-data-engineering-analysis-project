"""
Glue ETL Job: Public API Staged → Curated (Iceberg)
Reads Parquet from staged zone, applies UPSERT logic, writes to Iceberg curated table.

Data flow:
- Input: s3://bucket/quality-checks/public-api/passed/ (Parquet)
- Output: s3://bucket/curated/public-api/ (Iceberg with MERGE/UPSERT)

Per use case:
- ACID transactions via Iceberg
- MERGE/UPSERT with primary key (record_id generated in staged)
- Schema evolution support
- Time travel capability
- Partitioned by year for query optimization
"""

import sys
import logging
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, md5, concat_ws

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
    passed_path = f"s3://{args['datalake_bucket']}/quality-checks/public-api/passed/"
    curated_path = f"s3://{args['datalake_bucket']}/curated/public-api/"
    database = args['glue_database']
    table_name = "public_api_providers"
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
        df_staged = df_staged.withColumn(
            "record_id",
            md5(concat_ws("|", col("rndrng_npi"), col("hcpcs_cd"), col("place_of_srvc"), col("year")))
        )
    
    # Register as temp view for MERGE
    df_staged.createOrReplaceTempView("staged_data")
    
    # Set default catalog to glue_catalog for Iceberg table reference
    spark.sql("SET spark.sql.defaultCatalog = glue_catalog")
    
    # Create Iceberg table using simplified namespace (database.table)
    # When using glue_catalog as default, we reference it as database.table_name
    full_glue_table = f"{database}.{table_name}"
    logger.info(f"Creating or updating Iceberg table: glue_catalog.{full_glue_table}")
    
    # Check if table already exists
    table_exists = False
    try:
        spark.sql(f"SELECT 1 FROM {full_glue_table} LIMIT 1")
        table_exists = True
        logger.info(f"Iceberg table {full_glue_table} already exists")
    except:
        logger.info(f"Table does not exist, will create: {full_glue_table}")
    
    if not table_exists:
        # Create empty table structure first
        logger.info(f"Creating Iceberg table structure: {full_glue_table}")
        spark.sql(f"""
            CREATE TABLE {full_glue_table}
            USING iceberg
            LOCATION '{curated_path}'
            PARTITIONED BY (year)
            TBLPROPERTIES ('format-version'='2')
            AS SELECT * FROM staged_data WHERE 1=0
        """)
        logger.info(f"Created table structure")
        
        # Now insert the actual data
        logger.info(f"Inserting initial data into {full_glue_table}")
        spark.sql(f"""
            INSERT INTO {full_glue_table}
            SELECT * FROM staged_data
        """)
        initial_count = spark.sql(f"SELECT COUNT(*) as cnt FROM {full_glue_table}").collect()[0]['cnt']
        logger.info(f"Initial load complete: {initial_count} records")
    else:
        # Table exists, use MERGE for upsert logic
        logger.info(f"Executing MERGE to upsert data into {full_glue_table}")
        merge_sql = f"""
            MERGE INTO {full_glue_table} t
            USING staged_data s
            ON t.record_id = s.record_id
            WHEN MATCHED THEN UPDATE SET *
            WHEN NOT MATCHED THEN INSERT *
        """
        spark.sql(merge_sql)
        logger.info(f"MERGE completed")
    
    # Verify
    final_count = spark.sql(f"SELECT COUNT(*) as cnt FROM {full_glue_table}").collect()[0]['cnt']
    logger.info(f"Success: Iceberg table {full_glue_table} now has {final_count} records")
    
except Exception as e:
    logger.error(f"Failed: {str(e)}")
    raise
finally:
    job.commit()

