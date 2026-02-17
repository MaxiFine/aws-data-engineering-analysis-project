# Glue Catalog Database - Central schema registry for Iceberg tables
# Location points to curated zone per usecasedetail.md design pattern
resource "aws_glue_catalog_database" "lakehouse" {
  name         = "${replace(var.resource_prefix, "-", "_")}_catalog"
  description  = "Data & BI Lakehouse Glue Catalog - Central schema registry for Iceberg tables"
  location_uri = "s3://${var.datalake_bucket_name}/curated/"

  tags = var.tags
}
