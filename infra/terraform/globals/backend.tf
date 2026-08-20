# Terraform Backend Configuration
# ============================================
# This file documents the S3-compatible backend for Terraform state storage
# using Hetzner Object Storage.
#
# The actual backend block is in envs/prod/main.tf (Terraform requires it
# in the root module). This file serves as reference documentation.
#
# Before running terraform init, you must:
# 1. Create an "openclaw-tfstate" bucket in Hetzner Object Storage
# 2. Set the following environment variables:
#    - AWS_ACCESS_KEY_ID (Hetzner Object Storage access key)
#    - AWS_SECRET_ACCESS_KEY (Hetzner Object Storage secret key)
#
# Or source config/inputs.sh which sets them for you.
