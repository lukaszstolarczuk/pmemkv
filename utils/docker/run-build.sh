#!/usr/bin/env bash
#
# Copyright 2019, Intel Corporation
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the
#       distribution.
#
#     * Neither the name of the copyright holder nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# run-build.sh - is called inside a Docker container,
#                starts pmemkv build with tests.
#

set -e

EXAMPLE_TEST_DIR="/tmp/build_example"
PREFIX=/usr

function sudo_password() {
	echo $USERPASS | sudo -Sk $*
}

function cleanup() {
	find . -name ".coverage" -exec rm {} \;
	find . -name "coverage.xml" -exec rm {} \;
	find . -name "*.gcov" -exec rm {} \;
	find . -name "*.gcda" -exec rm {} \;
}

function upload_codecov() {
	clang_used=$(cmake -LA -N . | grep CMAKE_CXX_COMPILER | grep clang | wc -c)

	if [[ $clang_used > 0 ]]; then
		gcovexe="llvm-cov gcov"
	else
		gcovexe="gcov"
	fi

	# the output is redundant in this case, i.e. we rely on parsed report from codecov on github
	bash <(curl -s https://codecov.io/bash) -c -F $1 -x "$gcovexe"
	cleanup
}

function compile_example_standalone() {
	rm -rf $EXAMPLE_TEST_DIR
	mkdir $EXAMPLE_TEST_DIR
	cd $EXAMPLE_TEST_DIR

	cmake $WORKDIR/examples/$1

	# exit on error
	if [[ $? != 0 ]]; then
		cd -
		return 1
	fi

	make -j$(nproc)
	cd -
}

function run_example_standalone() {
	cd $EXAMPLE_TEST_DIR

	rm -f pool
	./$1 pool
	# exit on error
	if [[ $? != 0 ]]; then
		cd -
		return 1
	fi

	cd -
}

# Resize /dev/shm, since default one is too small
sudo_password -S mount -oremount,size=4G /dev/shm
cd $WORKDIR

echo
echo "### Making sure there is no libpmemkv currently installed"
echo "---------------------------- Error expected! ------------------------------"
compile_example_standalone pmemkv_basic_cpp && exit 1
echo "---------------------------------------------------------------------------"

echo
echo "##############################################################"
echo "### Verify build and install (in dir: ${PREFIX})"
echo "##############################################################"

mkdir $WORKDIR/build
cd $WORKDIR/build

cmake .. -DCMAKE_BUILD_TYPE=Debug \
	-DTEST_DIR=/dev/shm \
	-DCMAKE_INSTALL_PREFIX=$PREFIX \
	-DCOVERAGE=$COVERAGE \
	-DDEVELOPER_MODE=1

make -j$(nproc)
make -j$(nproc) doc
ctest --output-on-failure
sudo_password -S make -j$(nproc) install

if [ "$COVERAGE" == "1" ]; then
	upload_codecov tests
fi

# Verify installed libraries
compile_example_standalone pmemkv_basic_c
run_example_standalone pmemkv_basic_c
compile_example_standalone pmemkv_basic_cpp
run_example_standalone pmemkv_basic_cpp
compile_example_standalone pmemkv_config_c
run_example_standalone pmemkv_config_c

# Uninstall libraries
cd $WORKDIR/build
sudo_password -S make uninstall

cd $WORKDIR
rm -rf $WORKDIR/build
