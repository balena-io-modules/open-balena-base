#!/bin/bash
# Generates systemd-env.txt reference file by running actual systemd
# This file should be regenerated whenever test.env is modified

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

echo "Starting systemd container..."
CONTAINER_ID=$(docker run --rm -d \
  --name systemd-env-test \
  --privileged \
  -v "${FIXTURES_DIR}:/usr/src/app/tests/fixtures:rw" \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --tmpfs /run \
  --tmpfs /run/lock \
  jrei/systemd-ubuntu:latest)

echo "Waiting for systemd to initialize..."
sleep 3

echo "Installing and running test service..."
docker exec systemd-env-test bash -c "
  cp /usr/src/app/tests/fixtures/test-env.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl start test-env.service
  sleep 2
  echo 'Generated systemd-env.txt:'
  cat /usr/src/app/tests/fixtures/systemd-env.txt
"

echo "Stopping container..."
docker stop systemd-env-test > /dev/null

echo ""
echo "✓ Successfully generated ${FIXTURES_DIR}/systemd-env.txt"
