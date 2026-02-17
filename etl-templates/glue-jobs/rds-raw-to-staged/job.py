"""
Glue ETL Job: RDS Raw → Staged
Reads RDS data from DMS (csv) from raw zone, adds metadata, and writes to staged as Parquet.

Data flow:
- Input: s3://bucket/raw/rds/postgres/ (csv files from AWS DMS)
- Output: s3://bucket/staged/rds/postgres/ (Parquet)

Transformations:
- Add ingestion_timestamp
- Generate record_id based on all columns (MD5 hash for uniqueness)
"""

import sys
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import current_timestamp, col, md5, concat_ws

logging.getLogger('py4j').setLevel(logging.ERROR)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'TempDir',
    'datalake_bucket',
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

logger.info(f"Starting: {args['JOB_NAME']}")

try:
    # Read Parquet files from raw RDS zone (output from AWS DMS)
    raw_path = f"s3://{args['datalake_bucket']}/raw/rds/postgres/"
    logger.info(f"Reading from: {raw_path}")
    
    dynamic_frame = glueContext.create_dynamic_frame.from_options(
        connection_type="s3",
        connection_options={"paths": [raw_path], "recurse": True},
        format="csv",
        transformation_ctx="read_raw_rds"
    )
    
    df = dynamic_frame.toDF()
    record_count = df.count()
    logger.info(f"Read {record_count} records from raw RDS")
    logger.info(f"Schema: {len(df.columns)} columns")
    
    # Add ingestion timestamp
    df = df.withColumn("ingestion_timestamp", current_timestamp())
    
    # Generate deterministic record_id using MD5 hash of all columns
    all_cols = [col(c) for c in df.columns if c != "ingestion_timestamp"]
    df = df.withColumn(
        "record_id",
        md5(concat_ws("|", *all_cols))
    )
    
    logger.info(f"Added record_id and ingestion_timestamp")
    
    # Write to staged as Parquet
    staged_path = f"s3://{args['datalake_bucket']}/staged/rds/postgres/"
    logger.info(f"Writing to: {staged_path}")
    
    df.write.mode("append").parquet(staged_path)
    
    logger.info(f"Success: Written {record_count} records to staged zone")
    
except Exception as e:
    logger.error(f"Failed: {str(e)}")
    raise
finally:
    job.commit()

