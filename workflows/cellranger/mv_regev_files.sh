#!/bin/bash

# Check for required arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 <tsv_file> <s3_bucket_name>"
  exit 1
fi

# Assign arguments to variables
tsv_file="$1"
s3_bucket_name="$2"

# Make sure AWS CLI is installed (check for awscli command)
if ! command -v aws &> /dev/null; then
  echo "Error: AWS CLI not found. Please install awscli first."
  exit 1
fi

# Loop through each line in the TSV file
while IFS=$'\t' read -r _ gcs_path; do
  # Skip the first column (header)
  [[ -z "$gcs_path" ]] && continue

  # Download from GCS (assuming gsutil is installed)
  gsutil -u aaa-willyn-test cp "$gcs_path" /tmp/temp_file

  # Extract the path without the "gs://" prefix
  s3_path="${gcs_path#gs://}"

  # Copy the file to S3 with desired path structure
  aws s3 cp /tmp/temp_file "s3://${s3_bucket_name}/${s3_path}"

  # Check for successful copy
  if [ $? -eq 0 ]; then
    echo "Successfully copied $gcs_path to s3://${s3_bucket_name}/${s3_path}"
  else
    echo "Error copying $gcs_path to S3"
  fi
done < "$tsv_file"

echo "Finished processing $tsv_file"
