#!/bin/bash

GCS_BUCKET=terra-featured-workspaces
S3_BUCKET=willyn-omics-test

# Read the file containing GCS paths line by line
while IFS= read -r gcs_path; do

  # Download the file from GCS
  gsutil cp "${gcs_path}" "/tmp/temp_file"

  # Extract the path without the "gs://" prefix
  s3_path="${gcs_path#gs://}"

  # Upload the downloaded file to S3 with the same path
  aws s3 cp "/tmp/temp_file" "s3://${S3_BUCKET}/${s3_path}"

  # Remove the temporary downloaded file
  rm "/tmp/temp_file"

  echo "Uploaded: ${gcs_path} -> s3://${S3_BUCKET}/${s3_path}"
done < "samples_sheet.txt"