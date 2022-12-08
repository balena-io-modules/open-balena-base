
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
    "docker.io/balena/open-balena-base:no-systemd-latest",
    "docker.io/balena/open-balena-base:no-systemd-master",
  ]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
