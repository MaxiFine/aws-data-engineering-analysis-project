# Phase 7: Athena KPI Views Deployment Guide

## Overview
This guide documents how to deploy Athena KPI views for the public API healthcare provider data to your Glue Catalog using manual Terraform and AWS Console methods.

## Files
- `athena_kpi_views_public_api.sql` - Complete SQL views for all KPIs (13 views total)
- `ATHENA_VIEWS_DEPLOYMENT.md` - This deployment guide

## Method 1: AWS Athena Console (Recommended for Testing)

### Step 1: Copy the SQL Views
1. Open `athena_kpi_views_public_api.sql`
2. Copy the entire content or individual view definitions

### Step 2: Execute in Athena Console
1. Navigate to AWS Athena Console
2. Select workgroup: `lakehouse-dev-wg` (or your configured workgroup)
3. Paste the SQL views one by one or all at once
4. Click **Run query**

### Step 3: Verify Views
Once executed, verify views were created:
```sql
SHOW VIEWS IN lakehouse_dev_ufz9ae_catalog;
```

Expected views:
- provider_service_volume
- provider_revenue_performance
- provider_service_analysis
- top_procedures_by_volume
- procedure_cost_efficiency
- provider_charge_accuracy
- beneficiary_concentration_analysis
- yoy_provider_trends
- yoy_procedure_trends
- executive_kpi_summary_public_api
- provider_revenue_percentiles
- procedure_volume_percentiles
- data_quality_overview


## Next Steps

1. ✅ Deploy Athena views (this document)
2. ⬜ Test views with sample queries
3. ⬜ Create QuickSight data source from Athena
4. ⬜ Build executive dashboard in QuickSight
5. ⬜ Configure Power BI connection (optional)

## View Descriptions

| View Name | Purpose | Primary Use Case |
|-----------|---------|-----------------|
| `provider_service_volume` | Provider service counts | Identify high-volume providers |
| `provider_revenue_performance` | Revenue by provider | Financial analysis by provider |
| `provider_service_analysis` | Services by procedure code | Procedure-level insights |
| `top_procedures_by_volume` | Most common procedures | Identify high-demand services |
| `procedure_cost_efficiency` | Cost ratios by procedure | Reimbursement analysis |
| `provider_charge_accuracy` | Payment ratios | Compliance and accuracy checks |
| `beneficiary_concentration_analysis` | Services per patient | Risk assessment |
| `yoy_provider_trends` | Year-over-year provider data | Trend analysis |
| `yoy_procedure_trends` | Year-over-year procedure data | Historical comparison |
| `executive_kpi_summary_public_api` | High-level metrics | Executive dashboards |
| `provider_revenue_percentiles` | Provider benchmarking | Performance ranking |
| `procedure_volume_percentiles` | Procedure benchmarking | Volume ranking |
| `data_quality_overview` | Data completeness | Quality assurance |


