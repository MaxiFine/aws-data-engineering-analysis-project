import json
import boto3
import requests
import csv
import io
import os

s3 = boto3.client('s3')
bucket_name = os.environ.get("BUCKET_NAME", "default-bucket-name")

# CMS dataset UUIDs
DATASET_UUIDS = {
    "2013": "ad5e7548-98ab-4325-af4b-b2a7099b9351",
    "2014": "f63b48ae-946e-48f7-9f56-327a68da4e0b",
    "2015": "f8cdb11a-d5f7-4fbe-aac4-05abc8ee2c83",
    "2016": "7918e22a-fbfb-4a07-9f59-f8aab2b757d4",
    "2017": "85bf3c9c-2244-490d-ad7d-c34e4c28f8ea",
    "2018": "fb6d9fe8-38c1-4d24-83d4-0b7b291000b2",
    "2019": "867b8ac7-ccb7-4cc9-873d-b24340d89e32",
    "2020": "c957b49e-1323-49e7-8678-c09da387551d",
    "2021": "31dc2c47-f297-4948-bfb4-075e1bec3a02",
    "2022": "e650987d-01b7-4f09-b75e-b0b075afbf98",
    "2023": "0e9f2f2b-7bf9-451a-912c-e02e654dd725"
}


def lambda_handler(event, context):
    for year, uuid in DATASET_UUIDS.items():
        print(f"Fetching {year} data...")

        all_data = []
        offset = 0
        page_size = 10000  # Adjust if Lambda memory/time allows

        while True:
            url = f"https://data.cms.gov/data-api/v1/dataset/{uuid}/data"
            params = {"offset": offset, "size": page_size}

            print(f"→ Requesting: {url} (offset={offset})")

            try:
                response = requests.get(url, params=params, timeout=60)

                if response.status_code != 200:
                    print(f"Request failed ({response.status_code}): {response.text[:200]}")
                    break

                data = response.json()

                if not data:
                    print(f"Finished fetching all pages for {year}.")
                    break

                all_data.extend(data)
                offset += page_size

                # Stop early if fewer than expected results are returned
                if len(data) < page_size:
                    print(f"Last page reached for {year}.")
                    break

            except Exception as e:
                print(f"Error fetching {year}: {e}")
                break

        # --- Convert to CSV and Upload to S3 ---
        if all_data:
            # Create CSV in memory
            csv_buffer = io.StringIO()

            # Extract CSV headers dynamically
            headers = list(all_data[0].keys())
            writer = csv.DictWriter(csv_buffer, fieldnames=headers)
            writer.writeheader()
            writer.writerows(all_data)

            # S3 key (file path)
            key = f"raw/public-api/year={year}/data.csv"

            # Upload CSV
            s3.put_object(
                Bucket=bucket_name,
                Key=key,
                Body=csv_buffer.getvalue(),
                ContentType="text/csv"
            )

            print(f"✅ Uploaded {len(all_data)} records for {year} to s3://{bucket_name}/{key}")
        else:
            print(f"⚠️ No data found or failed for {year}")

    return {
        "statusCode": 200,
        "body": json.dumps("All available datasets processed and uploaded as CSV successfully.")
    }