group "default" {
  targets = ["backend-dev"]
}

group "production" {
  targets = ["backend-prod"]
}

target "backend-dev" {
  context = "."
  dockerfile = "docker/django/Dockerfile.dev"
  tags = ["tupilingo-backend:dev"]
  platforms = ["linux/amd64", "linux/arm64"]
  cache-to = ["type=local,dest=.buildx-cache"]
  cache-from = ["type=local,src=.buildx-cache"]
}

target "backend-prod" {
  context = "."
  dockerfile = "docker/django/Dockerfile.prod"
  tags = ["tupilingo-backend:latest"]
  platforms = ["linux/amd64", "linux/arm64"]
  cache-to = ["type=local,dest=.buildx-cache-prod"]
  cache-from = ["type=local,src=.buildx-cache-prod"]
}
