group "default" {
    targets = ["latest"]
}

variable "REGISTRY_PREFIX" {
    default = "atareao"
}

variable "IMAGE_NAME" {
    default = "postgres-backup"
}

target "latest" {
    platforms = ["linux/amd64", "linux/arm64"]
    tags = [
        "${REGISTRY_PREFIX}/${IMAGE_NAME}:latest",
        "${REGISTRY_PREFIX}/${IMAGE_NAME}:v0.1.0"
    ]
}
