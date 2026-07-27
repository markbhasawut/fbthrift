#!/usr/bin/env bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

usage() {
  echo "usage: $0 THRIFT1 WORK_DIR {smoke|fixtures|conformance|stress} [STRESS_REQUESTS]" >&2
  exit 2
}

[[ $# -ge 3 ]] || usage

thrift1=$1
work_dir=$2
suite=$3
stress_requests=${4:-1000}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "${script_dir}/../../.." && pwd)
public_module_path=github.com/facebook/fbthrift
internal_module_path=thrift
go_executable=${THRIFT_GO_EXECUTABLE:-}

[[ -x "${thrift1}" ]] || { echo "thrift1 is not executable: ${thrift1}" >&2; exit 2; }
if [[ -z ${go_executable} ]]; then
  go_executable=$(command -v go) || {
    echo "Go 1.26 or newer is required" >&2
    exit 2
  }
fi
[[ -x "${go_executable}" ]] || {
  echo "Go executable is not executable: ${go_executable}" >&2
  exit 2
}

go_version=$("${go_executable}" env GOVERSION)
go_minor=${go_version#go1.}
go_minor=${go_minor%%.*}
if [[ ! ${go_minor} =~ ^[0-9]+$ ]] || (( go_minor < 26 )); then
  echo "Go 1.26 or newer is required; found ${go_version}" >&2
  exit 2
fi

rm -rf -- "${work_dir}"
public_root="${work_dir}/public"
internal_root="${work_dir}/internal"
mkdir -p "${public_root}" "${internal_root}"
export GOCACHE="${work_dir}/.gocache"

copy_tree() {
  local source=$1
  local destination=$2
  mkdir -p "$(dirname -- "${destination}")"
  cmake -E copy_directory "${source}" "${destination}"
}

copy_tree "${source_root}/thrift/lib/go/thrift" \
  "${public_root}/thrift/lib/go/thrift"
copy_tree "${source_root}/thrift/test/go" "${public_root}/thrift/test/go"
copy_tree "${source_root}/thrift/lib/go/thrift/e2e/handler" \
  "${internal_root}/lib/go/thrift/e2e/handler"
rm -f -- \
  "${public_root}/thrift/lib/go/thrift/go.mod" \
  "${public_root}/thrift/lib/go/thrift/go.sum"

cp "${source_root}/thrift/lib/go/thrift/go.mod" "${public_root}/go.mod"
cp "${source_root}/thrift/lib/go/thrift/go.sum" "${public_root}/go.sum"
(
  cd "${public_root}"
  "${go_executable}" mod edit -module="${public_module_path}" -go=1.26.0
  GOWORK=off "${go_executable}" mod download all
)
(
  cd "${internal_root}"
  "${go_executable}" mod init "${internal_module_path}"
  "${go_executable}" mod edit -go=1.26.0
)
(
  cd "${work_dir}"
  "${go_executable}" work init ./public ./internal
  "${go_executable}" work edit -go=1.26.0
)

generation_root="${work_dir}/.codegen"
generation_index=0
generate_go() {
  local idl=$1
  local namespace
  local package_path
  local package_root
  local output
  local -a compiler_args=()

  if [[ ${idl} == thrift/test/testset/golden/testset.thrift ]]; then
    compiler_args=(-nowarn)
  fi

  namespace=$(awk '$1 == "namespace" && $2 == "go" { print $3; exit }' \
    "${source_root}/${idl}")
  namespace=${namespace#\'}
  namespace=${namespace%\'}
  namespace=${namespace#\"}
  namespace=${namespace%\"}
  [[ -n "${namespace}" ]] || {
    echo "missing namespace go in ${idl}" >&2
    exit 2
  }

  if [[ ${namespace} != */* ]]; then
    namespace=${namespace//./\/}
  fi

  if [[ ${namespace} == "${public_module_path}/"* ]]; then
    package_root=${public_root}
    package_path=${namespace#"${public_module_path}/"}
  elif [[ ${namespace} == "${internal_module_path}/"* ]]; then
    package_root=${internal_root}
    package_path=${namespace#"${internal_module_path}/"}
  else
    echo "unsupported in-tree Go namespace: ${namespace} (${idl})" >&2
    exit 2
  fi

  output="${generation_root}/${generation_index}"
  generation_index=$((generation_index + 1))
  mkdir -p "${output}" "${package_root}/${package_path}"
  "${thrift1}" \
    "${compiler_args[@]}" \
    -I "${source_root}" \
    -o "${output}" \
    --gen mstch_go \
    "${source_root}/${idl}"
  [[ -f "${output}/gen-go/metadata.go" ]] || {
    echo "Go generator did not emit metadata.go by default for ${idl}" >&2
    exit 1
  }
  cmake -E copy_directory \
    "${output}/gen-go" "${package_root}/${package_path}"
}

core_idls=(
  thrift/lib/thrift/id.thrift
  thrift/lib/thrift/standard.thrift
  thrift/lib/thrift/type_rep.thrift
  thrift/lib/thrift/type.thrift
  thrift/lib/thrift/any_rep.thrift
  thrift/lib/thrift/any.thrift
  thrift/lib/thrift/metadata.thrift
  thrift/lib/thrift/RpcMetadata.thrift
  thrift/lib/thrift/RocketUpgrade.thrift
  thrift/lib/thrift/protocol_detail.thrift
)
for idl in "${core_idls[@]}"; do
  generate_go "${idl}"
done

fixture_idls=(
  thrift/test/go/if/dummy.thrift
  thrift/test/go/if/gonamespace.thrift
  thrift/test/go/if/my_test_struct.thrift
  thrift/test/go/if/thrifttest.thrift
  thrift/lib/go/thrift/e2e/if/service.thrift
)
for idl in "${fixture_idls[@]}"; do
  generate_go "${idl}"
done

case "${suite}" in
  smoke)
    packages=(
      ./thrift/lib/go/thrift
      ./thrift/lib/go/thrift/dummy
      ./thrift/lib/go/thrift/e2e
      ./thrift/lib/go/thrift/format
      ./thrift/lib/go/thrift/metadata
      ./thrift/lib/go/thrift/rocket
      ./thrift/lib/go/thrift/types
      thrift/lib/go/thrift/e2e/handler
    )
    (cd "${public_root}" && "${go_executable}" test "${packages[@]}")
    ;;
  fixtures)
    (cd "${public_root}" && "${go_executable}" test ./thrift/test/go)
    ;;
  conformance)
    conformance_idls=(
      thrift/conformance/if/any.thrift
      thrift/conformance/if/conformance.thrift
      thrift/conformance/if/patch_data.thrift
      thrift/conformance/if/protocol.thrift
      thrift/conformance/if/rpc.thrift
      thrift/conformance/if/rpc_setup.thrift
      thrift/conformance/if/serialization.thrift
      thrift/conformance/if/test_suite.thrift
      thrift/conformance/if/test_value.thrift
      thrift/conformance/if/type.thrift
      thrift/test/testset/Enum.thrift
      thrift/test/testset/golden/testset.thrift
    )
    for idl in "${conformance_idls[@]}"; do
      generate_go "${idl}"
    done
    mkdir -p \
      "${public_root}/cmd/conformance_server" \
      "${public_root}/cmd/rpc_client" \
      "${public_root}/cmd/rpc_server" \
      "${public_root}/bin"
    cp "${source_root}/thrift/conformance/go/conformance_server.go" \
      "${public_root}/cmd/conformance_server/main.go"
    cp "${source_root}/thrift/conformance/go/rpc_client.go" \
      "${public_root}/cmd/rpc_client/main.go"
    cp "${source_root}/thrift/conformance/go/rpc_server.go" \
      "${public_root}/cmd/rpc_server/main.go"
    (
      cd "${public_root}"
      "${go_executable}" build -o bin/conformance-server ./cmd/conformance_server
      "${go_executable}" build -o bin/rpc-client ./cmd/rpc_client
      "${go_executable}" build -o bin/rpc-server ./cmd/rpc_server
    )
    ;;
  stress)
    [[ ${stress_requests} =~ ^[1-9][0-9]*$ ]] || {
      echo "STRESS_REQUESTS must be a positive integer" >&2
      exit 2
    }
    (
      cd "${public_root}"
      FBTHRIFT_GO_STRESS_REQUESTS="${stress_requests}" \
        "${go_executable}" test -count=1 -run '^TestServerStress$' ./thrift/lib/go/thrift/stress
    )
    ;;
  *)
    usage
    ;;
esac
