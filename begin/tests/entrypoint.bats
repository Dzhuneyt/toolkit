#!/usr/bin/env bats

load test_helper/common

# End-to-end checks of the entrypoint's self-resolution: if lib/ isn't located,
# sourcing fails and --help can't print. We assert via the symlink AND directly.

setup() {
  _common_setup
  BEGIN_BIN="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)/begin"
  export BEGIN_BIN
  WORK="$(mktemp -d)"
  export WORK
}

teardown() {
  rm -rf "${WORK}"
}

@test "entrypoint: --help works when invoked directly" {
  run "${BEGIN_BIN}" --help
  assert_success
  assert_output --partial "begin <query>"
}

@test "entrypoint: no args prints usage" {
  run "${BEGIN_BIN}"
  assert_success
  assert_output --partial "begin <query>"
}

@test "entrypoint: resolves lib/ through a symlink from an unrelated CWD" {
  mkdir -p "${WORK}/bin" "${WORK}/elsewhere"
  ln -s "${BEGIN_BIN}" "${WORK}/bin/begin"

  # Run the symlink by absolute path while sitting in a totally unrelated dir.
  run bash -c "cd '${WORK}/elsewhere' && '${WORK}/bin/begin' --help"
  assert_success
  assert_output --partial "begin <query>"
}

@test "entrypoint: symlink on PATH resolves and runs by bare name" {
  mkdir -p "${WORK}/bin"
  ln -s "${BEGIN_BIN}" "${WORK}/bin/begin"

  PATH="${WORK}/bin:${PATH}" run begin --help
  assert_success
  assert_output --partial "begin <query>"
}
