# ============================================================================
# AWS QuickSight Configuration
# ============================================================================

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  iam_username = split("/", data.aws_caller_identity.current.arn)[1]

  # Single principal for all QuickSight resources
  quicksight_principal = "arn:aws:quicksight:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:user/default/${local.iam_username}"
}


# Generate a random suffix for resource names to avoid conflicts
resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================================
# QuickSight Subscription (Account Setup)
# ============================================================================

# Programmatically subscribes AWS account to QuickSight service
# Only creates subscription when quicksight_subscription variable is provided
# Skip this by setting quicksight_subscription = null if already manually subscribed

resource "aws_quicksight_account_subscription" "subscription" {
  count = var.quicksight_subscription != null ? 1 : 0

  account_name          = "${var.quicksight_subscription.account_name}-${random_id.suffix.hex}"
  authentication_method = var.quicksight_subscription.authentication_method
  edition               = var.quicksight_subscription.edition
  notification_email    = var.quicksight_subscription.notification_email
}

resource "aws_quicksight_account_settings" "settings" {
  count = var.quicksight_subscription != null ? 1 : 0

  termination_protection_enabled = var.quicksight_subscription.termination_protection_enabled

  depends_on = [aws_quicksight_account_subscription.subscription]
}

# ============================================================================
# QuickSight Lakeformation Permissions
# ============================================================================

# QuickSight: Database access for analytics
resource "aws_lakeformation_permissions" "quicksight_database" {

  depends_on = [
    aws_quicksight_account_subscription.subscription
  ]

  principal   = local.quicksight_principal
  permissions = ["DESCRIBE"]
  database {
    name = var.glue_database_name
  }
}

# QuickSight: Table access for analytics
resource "aws_lakeformation_permissions" "quicksight_table" {

  depends_on = [
    aws_quicksight_account_subscription.subscription
  ]

  principal   = local.quicksight_principal
  permissions = ["SELECT", "DESCRIBE"]
  table {
    database_name = var.glue_database_name
    name          = var.glue_table_name
  }
}


# ============================================================================
# QuickSight Athena Data Source
# ============================================================================

resource "aws_quicksight_data_source" "athena" {
  data_source_id = "athena-datasource-${random_id.suffix.hex}"
  name           = var.athena_datasource_name

  depends_on = [
    aws_lakeformation_permissions.quicksight_database,
    aws_lakeformation_permissions.quicksight_table
  ]

  parameters {
    athena {
      work_group = var.athena_workgroup_name
    }

  }

  type = "ATHENA"


  permission {
    actions = [
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:DeleteDataSource",
      "quicksight:UpdateDataSourcePermissions"
    ]
    principal = local.quicksight_principal
  }

  tags = merge(
    var.tags,
    {
      Name = var.athena_datasource_name
    }
  )

}


# ============================================================================
# QuickSight Athena Dataset
# ============================================================================

resource "aws_quicksight_data_set" "athena" {
  data_set_id = "athena-${random_id.suffix.hex}"
  name        = "${var.athena_dataset.name} Dataset"
  import_mode = var.athena_dataset.import_mode # Can be "SPICE" or "DIRECT_QUERY"

  depends_on = [
    aws_lakeformation_permissions.quicksight_database,
    aws_lakeformation_permissions.quicksight_table
  ]

  physical_table_map {
    physical_table_map_id = "table-${random_id.suffix.hex}"


    relational_table {
      data_source_arn = aws_quicksight_data_source.athena.arn
      catalog         = "AwsDataCatalog"
      schema          = var.glue_database_name
      name            = var.glue_table_name

      dynamic "input_columns" {
        for_each = slice(var.athena_dataset.columns, 0, length(var.athena_dataset.columns))
        content {
          name = input_columns.value.name
          type = input_columns.value.type
        }
      }
    }
  }

  permissions {
    actions = [
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:PassDataSet",
      "quicksight:DescribeIngestion",
      "quicksight:ListIngestions",
      "quicksight:UpdateDataSet",
      "quicksight:DeleteDataSet",
      "quicksight:CreateIngestion",
      "quicksight:CancelIngestion",
      "quicksight:UpdateDataSetPermissions"
    ]
    principal = local.quicksight_principal
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.athena_dataset.name} Dataset"
    }
  )
}

# ============================================================================
# QuickSight Analysis - Athena
# ============================================================================

resource "aws_quicksight_analysis" "athena" {
  analysis_id = "cms-analysis-${random_id.suffix.hex}"
  name        = "${var.athena_dataset.name} Analysis"

  definition {
    data_set_identifiers_declarations {
      data_set_arn = aws_quicksight_data_set.athena.arn
      identifier   = "1"
    }

    sheets {
      sheet_id = "provider-kpis"
      name     = "Provider KPIs"

      # KPI: Top providers by total services rendered
      visuals {
        bar_chart_visual {
          visual_id = "top-providers-services"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Top 20 Providers by Total Services Rendered"
            }
          }

          chart_configuration {
            field_wells {
              bar_chart_aggregated_field_wells {
                category {
                  categorical_dimension_field {
                    field_id = "provider-id"
                    column {
                      data_set_identifier = "1"
                      column_name         = "rndrng_npi"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "total-services"
                    column {
                      data_set_identifier = "1"
                      column_name         = "tot_srvcs"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
              }
            }

            sort_configuration {
              category_sort {
                field_sort {
                  field_id  = "total-services"
                  direction = "DESC"
                }
              }
            }

            category_axis {
              scrollbar_options {
                visibility = "VISIBLE"
              }
            }
          }
        }
      }

      # KPI Cards
      visuals {
        kpi_visual {
          visual_id = "total-services-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Total Services Rendered"
            }
          }

          chart_configuration {
            field_wells {
              values {
                numerical_measure_field {
                  field_id = "total-services-sum"
                  column {
                    data_set_identifier = "1"
                    column_name         = "tot_srvcs"
                  }
                  aggregation_function {
                    simple_numerical_aggregation = "SUM"
                  }
                }
              }
            }
          }
        }
      }

      visuals {
        kpi_visual {
          visual_id = "unique-providers-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Total Unique Providers"
            }
          }

          chart_configuration {
            field_wells {
              values {
                categorical_measure_field {
                  field_id = "provider-count"
                  column {
                    data_set_identifier = "1"
                    column_name         = "rndrng_npi"
                  }
                  aggregation_function = "DISTINCT_COUNT"
                }
              }
            }
          }
        }
      }

      # Services per Beneficiary Distribution
      visuals {
        histogram_visual {
          visual_id = "services-per-beneficiary-dist"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Services per Beneficiary Distribution"
            }
          }

          chart_configuration {
            field_wells {
              histogram_aggregated_field_wells {
                values {
                  numerical_measure_field {
                    field_id = "services-per-beneficiary"
                    column {
                      data_set_identifier = "1"
                      column_name         = "tot_benes"
                    }
                  }
                }
              }
            }
          }
        }
      }

      # Provider Service Metrics by Procedure Code
      visuals {
        table_visual {
          visual_id = "provider-service-metrics"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Provider Service Metrics by Procedure Code"
            }
          }

          chart_configuration {
            field_wells {
              table_aggregated_field_wells {
                group_by {
                  categorical_dimension_field {
                    field_id = "provider-id"
                    column {
                      data_set_identifier = "1"
                      column_name         = "rndrng_npi"
                    }
                  }
                }

                group_by {
                  categorical_dimension_field {
                    field_id = "procedure-code"
                    column {
                      data_set_identifier = "1"
                      column_name         = "hcpcs_cd"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "total-services"
                    column {
                      data_set_identifier = "1"
                      column_name         = "tot_srvcs"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "total-patients"
                    column {
                      data_set_identifier = "1"
                      column_name         = "tot_benes"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "avg-submitted-charge"
                    column {
                      data_set_identifier = "1"
                      column_name         = "avg_sbmtd_chrg"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "AVERAGE"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "avg-paid-amount"
                    column {
                      data_set_identifier = "1"
                      column_name         = "avg_mdcr_pymt_amt"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "AVERAGE"
                    }
                  }
                }
              }
            }

            sort_configuration {
              row_sort {
                field_sort {
                  field_id  = "total-services"
                  direction = "DESC"
                }
              }
            }
          }
        }
      }

      # Top Procedures by Volume
      visuals {
        bar_chart_visual {
          visual_id = "top-procedures-volume"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Top 20 Procedures by Total Services Nationwide"
            }
          }

          chart_configuration {
            field_wells {
              bar_chart_aggregated_field_wells {
                category {
                  categorical_dimension_field {
                    field_id = "procedure-code"
                    column {
                      data_set_identifier = "1"
                      column_name         = "hcpcs_cd"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "total-services-nationwide"
                    column {
                      data_set_identifier = "1"
                      column_name         = "tot_srvcs"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
              }
            }

            sort_configuration {
              category_sort {
                field_sort {
                  field_id  = "total-services-nationwide"
                  direction = "DESC"
                }
              }
            }

            category_axis {
              scrollbar_options {
                visibility = "VISIBLE"
              }
            }
          }
        }
      }

      # Procedure Metrics KPI Card
      visuals {
        kpi_visual {
          visual_id = "unique-procedures-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Total Unique Procedures"
            }
          }

          chart_configuration {
            field_wells {
              values {
                categorical_measure_field {
                  field_id = "procedure-count"
                  column {
                    data_set_identifier = "1"
                    column_name         = "hcpcs_cd"
                  }
                  aggregation_function = "DISTINCT_COUNT"
                }
              }
            }
          }
        }
      }

      # Procedure Cost Efficiency Analysis
      visuals {
        scatter_plot_visual {
          visual_id = "procedure-cost-efficiency"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Procedure Cost Efficiency: Submitted vs Paid Amounts"
            }
          }

          chart_configuration {
            field_wells {
              scatter_plot_categorically_aggregated_field_wells {
                x_axis {
                  numerical_measure_field {
                    field_id = "avg-submitted-charge-nationwide"
                    column {
                      data_set_identifier = "1"
                      column_name         = "avg_sbmtd_chrg"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "AVERAGE"
                    }
                  }
                }

                y_axis {
                  numerical_measure_field {
                    field_id = "avg-paid-amount-nationwide"
                    column {
                      data_set_identifier = "1"
                      column_name         = "avg_mdcr_pymt_amt"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "AVERAGE"
                    }
                  }
                }

                category {
                  categorical_dimension_field {
                    field_id = "procedure-code-efficiency"
                    column {
                      data_set_identifier = "1"
                      column_name         = "hcpcs_cd"
                    }
                  }
                }

                size {
                  categorical_measure_field {
                    field_id = "providers-offering-service"
                    column {
                      data_set_identifier = "1"
                      column_name         = "rndrng_npi"
                    }
                    aggregation_function = "DISTINCT_COUNT"
                  }
                }
              }
            }
          }
        }
      }

      # Provider Charge Accuracy Analysis
      visuals {
        bar_chart_visual {
          visual_id = "provider-charge-accuracy"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Top 20 Providers by Payment Accuracy Ratio"
            }
          }

          chart_configuration {
            field_wells {
              bar_chart_aggregated_field_wells {
                category {
                  categorical_dimension_field {
                    field_id = "provider-accuracy"
                    column {
                      data_set_identifier = "1"
                      column_name         = "rndrng_npi"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "payment-accuracy-ratio"
                    column {
                      data_set_identifier = "1"
                      column_name         = "avg_mdcr_pymt_amt"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "AVERAGE"
                    }
                  }
                }
              }
            }

            sort_configuration {
              category_sort {
                field_sort {
                  field_id  = "payment-accuracy-ratio"
                  direction = "DESC"
                }
              }
            }

            category_axis {
              scrollbar_options {
                visibility = "VISIBLE"
              }
            }
          }
        }
      }

      # Average Payment Accuracy KPI
      visuals {
        kpi_visual {
          visual_id = "avg-payment-accuracy-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Average Payment per Service"
            }
          }

          chart_configuration {
            field_wells {
              values {
                numerical_measure_field {
                  field_id = "avg-payment-nationwide"
                  column {
                    data_set_identifier = "1"
                    column_name         = "avg_mdcr_pymt_amt"
                  }
                  aggregation_function {
                    simple_numerical_aggregation = "AVERAGE"
                  }
                }
              }
            }
          }
        }
      }

      # Beneficiary Concentration Risk Analysis
      visuals {
        scatter_plot_visual {
          visual_id = "beneficiary-concentration-risk"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Beneficiary Concentration Risk: Services vs Beneficiaries"
            }
          }

          chart_configuration {
            field_wells {
              scatter_plot_categorically_aggregated_field_wells {
                x_axis {
                  numerical_measure_field {
                    field_id = "total-beneficiaries"
                    column {
                      data_set_identifier = "1"
                      column_name         = "tot_benes"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }

                y_axis {
                  numerical_measure_field {
                    field_id = "total-services-concentration"
                    column {
                      data_set_identifier = "1"
                      column_name         = "tot_srvcs"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }

                category {
                  categorical_dimension_field {
                    field_id = "provider-concentration"
                    column {
                      data_set_identifier = "1"
                      column_name         = "rndrng_npi"
                    }
                  }
                }
              }
            }
          }
        }
      }

      # Services per Beneficiary KPI
      visuals {
        kpi_visual {
          visual_id = "avg-services-per-beneficiary-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Average Services per Beneficiary"
            }
          }

          chart_configuration {
            field_wells {
              values {
                numerical_measure_field {
                  field_id = "services-per-beneficiary-ratio"
                  column {
                    data_set_identifier = "1"
                    column_name         = "tot_srvcs"
                  }
                  aggregation_function {
                    simple_numerical_aggregation = "SUM"
                  }
                }
              }
            }
          }
        }
      }



      # Executive Dashboard Summary KPIs
      visuals {
        kpi_visual {
          visual_id = "total-paid-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Total Medicare Payments"
            }
          }

          chart_configuration {
            field_wells {
              values {
                numerical_measure_field {
                  field_id = "total-paid-executive"
                  column {
                    data_set_identifier = "1"
                    column_name         = "avg_mdcr_pymt_amt"
                  }
                  aggregation_function {
                    simple_numerical_aggregation = "SUM"
                  }
                }
              }
            }
          }
        }
      }

      visuals {
        kpi_visual {
          visual_id = "total-beneficiaries-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Total Beneficiaries Served"
            }
          }

          chart_configuration {
            field_wells {
              values {
                numerical_measure_field {
                  field_id = "total-beneficiaries-executive"
                  column {
                    data_set_identifier = "1"
                    column_name         = "tot_benes"
                  }
                  aggregation_function {
                    simple_numerical_aggregation = "SUM"
                  }
                }
              }
            }
          }
        }
      }

      visuals {
        kpi_visual {
          visual_id = "total-submitted-charges-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Total Submitted Charges"
            }
          }

          chart_configuration {
            field_wells {
              values {
                numerical_measure_field {
                  field_id = "total-submitted-executive"
                  column {
                    data_set_identifier = "1"
                    column_name         = "avg_sbmtd_chrg"
                  }
                  aggregation_function {
                    simple_numerical_aggregation = "SUM"
                  }
                }
              }
            }
          }
        }
      }

      visuals {
        kpi_visual {
          visual_id = "unique-procedures-executive-kpi"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Unique Procedures Performed"
            }
          }

          chart_configuration {
            field_wells {
              values {
                categorical_measure_field {
                  field_id = "unique-procedures-executive"
                  column {
                    data_set_identifier = "1"
                    column_name         = "hcpcs_cd"
                  }
                  aggregation_function = "DISTINCT_COUNT"
                }
              }
            }
          }
        }
      }

      # Provider Revenue Percentiles Benchmarking
      visuals {
        histogram_visual {
          visual_id = "provider-revenue-percentiles"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Provider Revenue Distribution (Benchmarking)"
            }
          }

          chart_configuration {
            field_wells {
              histogram_aggregated_field_wells {
                values {
                  numerical_measure_field {
                    field_id = "provider-total-paid"
                    column {
                      data_set_identifier = "1"
                      column_name         = "avg_mdcr_pymt_amt"
                    }
                  }
                }
              }
            }
          }
        }
      }

      # Top Revenue Providers Bar Chart
      visuals {
        bar_chart_visual {
          visual_id = "top-revenue-providers"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Top 20 Providers by Total Revenue"
            }
          }

          chart_configuration {
            field_wells {
              bar_chart_aggregated_field_wells {
                category {
                  categorical_dimension_field {
                    field_id = "provider-revenue-rank"
                    column {
                      data_set_identifier = "1"
                      column_name         = "rndrng_npi"
                    }
                  }
                }

                values {
                  numerical_measure_field {
                    field_id = "provider-revenue-total"
                    column {
                      data_set_identifier = "1"
                      column_name         = "avg_mdcr_pymt_amt"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
              }
            }

            sort_configuration {
              category_sort {
                field_sort {
                  field_id  = "provider-revenue-total"
                  direction = "DESC"
                }
              }
            }

            category_axis {
              scrollbar_options {
                visibility = "VISIBLE"
              }
            }
          }
        }
      }
    }
  }

  permissions {
    actions = [
      "quicksight:RestoreAnalysis",
      "quicksight:UpdateAnalysisPermissions",
      "quicksight:DeleteAnalysis",
      "quicksight:DescribeAnalysisPermissions",
      "quicksight:QueryAnalysis",
      "quicksight:DescribeAnalysis",
      "quicksight:UpdateAnalysis"
    ]
    principal = local.quicksight_principal
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.athena_dataset.name} Analysis"
    }
  )

}


# # ============================================================================
# # QuickSight Template - Athena
# # ============================================================================

resource "aws_quicksight_template" "athena" {
  template_id         = "template-${random_id.suffix.hex}"
  name                = "${var.athena_dataset.name} Template"
  version_description = "Initial template version"

  source_entity {
    source_analysis {
      arn = aws_quicksight_analysis.athena.arn
      data_set_references {
        data_set_arn         = aws_quicksight_data_set.athena.arn
        data_set_placeholder = "athena-dataset-${random_id.suffix.hex}"
      }
    }
  }

  permissions {
    actions = [
      "quicksight:DescribeTemplate",
      "quicksight:UpdateTemplate",
      "quicksight:DeleteTemplate"
    ]
    principal = local.quicksight_principal
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.athena_dataset.name} Template"
    }
  )

}

# ============================================================================
# QuickSight Dashboard - Athena
# ============================================================================

resource "aws_quicksight_dashboard" "athena" {
  dashboard_id        = "dashboard-${random_id.suffix.hex}"
  name                = "${var.athena_dataset.name} Dashboard"
  version_description = "Initial dashboard version"

  source_entity {
    source_template {
      arn = aws_quicksight_template.athena.arn
      data_set_references {
        data_set_arn         = aws_quicksight_data_set.athena.arn
        data_set_placeholder = "athena-dataset-${random_id.suffix.hex}"
      }
    }
  }

  permissions {
    actions = [
      "quicksight:DescribeDashboard",
      "quicksight:ListDashboardVersions",
      "quicksight:UpdateDashboardPermissions",
      "quicksight:QueryDashboard",
      "quicksight:UpdateDashboard",
      "quicksight:DeleteDashboard",
      "quicksight:DescribeDashboardPermissions",
      "quicksight:UpdateDashboardPublishedVersion"
    ]
    principal = local.quicksight_principal
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.athena_dataset.name} Dashboard"
    }
  )

}
