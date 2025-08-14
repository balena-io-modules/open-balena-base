
target "default" {
  dockerfile = "Dockerfile"
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
  cache-from = [
    "docker.io/balena/open-balena-base:latest",
    "docker.io/balena/open-balena-base:master",
  ]
}

target "no-systemd" {
  inherits = ["default"]
  dockerfile = "Dockerfile.no-systemd"
  cache-from = [
    "docker.io/balena/open-balena-base:latest-no-systemd",
    "docker.io/balena/open-balena-base:master-no-systemd",
  ]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}

target "s6-overlay" {
  inherits = ["default"]
  dockerfile = "Dockerfile.s6-overlay"
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
