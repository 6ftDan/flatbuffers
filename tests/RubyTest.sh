#!/bin/bash -eu
# Copyright 2014 Google Inc. All rights reserved.
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

pushd "$(dirname $0)" >/dev/null
test_dir="$(pwd)"
gen_code_path=${test_dir}
runtime_library_dir=${test_dir}/../ruby

# Emit Ruby code for the example schema in the test dir:
${test_dir}/../flatc -p -o ${gen_code_path} monster_test.fbs

# Syntax: run_tests <interpreter> <benchmark vtable dedupes>
#                   <benchmark read count> <benchmark build count>
interpreters_tested=()
function run_tests() {
  if $(which ${1} >/dev/null); then
    echo "Testing with interpreter: ${1}"
    $1 rb_test.rb $2 $3 $4
    interpreters_tested+=(${1})
    echo
  fi
}

# Run test suite with these interpreters. The arguments are benchmark counts.
run_tests ruby 100 100 100
