module "quicksight" {
  source = "./modules/quicksight"

  quicksight_subscription = var.quicksight_subscription # Optional QuickSight subscription configuration (Only specify if account doesn't have QuickSight subscription)

  athena_datasource_name = var.athena_datasource_name
  athena_workgroup_name  = var.athena_workgroup_name
  glue_database_name     = var.glue_database_name
  glue_table_name        = var.glue_table_name

  tags = var.tags

  athena_dataset = var.athena_dataset
}