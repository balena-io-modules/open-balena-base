
target "no-init" {
  dockerfile = "Dockerfile.no-init"
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}

target "s6-overlay" {
  dockerfile = "Dockerfile.s6-overlay"
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
