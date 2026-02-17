"""
Glue ETL Job: Public API Raw → Staged
Reads CMS healthcare provider data from raw zone, validates, and writes to staged as Parquet.

Data flow:
- Input: s3://bucket/raw/public-api/year=YYYY/data.csv (from Lambda)
- Output: s3://bucket/staged/public-api/year=YYYY/ (Parquet)

Transformations:
- Add ingestion_timestamp
- Keep year partition from raw path
- Basic validation (log schema)
"""

import sys
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import current_timestamp, col, input_file_name, concat_ws, md5
import re

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
    # Read CSV from raw zone (data-sources Lambda puts it at raw/public-api/year=YYYY/)
    raw_path = f"s3://{args['datalake_bucket']}/raw/public-api/"
    logger.info(f"Reading from: {raw_path}")
    
    dynamic_frame = glueContext.create_dynamic_frame.from_options(
        connection_type="s3",
        connection_options={"paths": [raw_path], "recurse": True},
        format="csv",
        format_options={"quoteChar": '"', "withHeader": True, "separator": ","},
        transformation_ctx="read_raw"
    )
    
    df = dynamic_frame.toDF()
    record_count = df.count()
    logger.info(f"Read {record_count} records from raw")
    logger.info(f"Schema: {len(df.columns)} columns - {', '.join(df.columns[:5])}...")
    
    # Extract year from the input file path (raw/public-api/year=YYYY/data.csv)
    def extract_year(filepath):
        match = re.search(r'year=(\d{4})', filepath)
        return match.group(1) if match else None
    
    extract_year_udf = spark.udf.register("extract_year", extract_year)
    
    # Add year partition column, primary key, and ingestion timestamp
    df = df.withColumn("_file_path", input_file_name()) \
            .withColumn("year", extract_year_udf(col("_file_path"))) \
            .drop("_file_path")

    # Generate deterministic primary key (record_id) using MD5 over business keys
    # Chosen fields: Rndrng_NPI + HCPCS_Cd + Place_Of_Srvc + year
    df = df.withColumn(
        "record_id",
        md5(concat_ws("|", col("Rndrng_NPI"), col("HCPCS_Cd"), col("Place_Of_Srvc"), col("year")))
    )

    # Add ingestion timestamp
    df = df.withColumn("ingestion_timestamp", current_timestamp())
    
    logger.info(f"Added year partition, record_id (primary key), and ingestion_timestamp")
    
    # Write to staged as Parquet (partitioned by year from source path)
    staged_path = f"s3://{args['datalake_bucket']}/staged/public-api/"
    logger.info(f"Writing to: {staged_path}")
    
    df.write \
        .mode("append") \
        .partitionBy("year") \
        .parquet(staged_path)
    
    logger.info(f"Success: Written to staged zone")
    
except Exception as e:
    logger.error(f"✗ Failed: {str(e)}")
    raise
finally:
    job.commit()

