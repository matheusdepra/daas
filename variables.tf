variable "project_id" {
  description = "GCP project ID (ex: daas-mvp-472103)"
  type        = string
}

variable "project_number" {
  description = "GCP project number (numeric)"
  type        = string
}

variable "region" {
  description = "GCP region where resources will be deployed"
  type        = string
  default     = "us-central1"
}

variable "ingest_image" {
  description = "Container image for Cloud Run ingest worker (Artifact Registry URL)"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+)-docker.pkg.dev/.+/.+:.+$", var.ingest_image))
    error_message = "ingest_image must be a valid Artifact Registry image URL (ex: us-central1-docker.pkg.dev/project/repo/image:tag)"
  }
}

variable "silver_image" {
  description = "Container image for Cloud Run bronze to silver worker (Artifact Registry URL)"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+)-docker.pkg.dev/.+/.+:.+$", var.silver_image))
    error_message = "silver_image must be a valid Artifact Registry image URL (ex: us-central1-docker.pkg.dev/project/repo/image:tag)"
  }
}
