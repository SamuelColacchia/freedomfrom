#!/bin/bash
#
# swift_protobuf.sh
#
# A Run Script Build Phase script used by the BloomFilterTool project of the
# SimpleURLFilter sample code. This script makes use of the `protoc` command line tool
# from https://github.com/apple/swift-protobuf to generate Swift code representing the 
# protobuf defined by the `input_file`.
#
# To operate, the `protoc` and `protoc-gen-swift` tools should be installed and accessible.
# These can be installed via homebrew: `brew install swift-protobuf`
#
# Please see the LICENSE.txt file included with this sample.
##

root_dir="${PROJECT_DIR}/BloomFilterTool"
input_file="${root_dir}/pir_database.proto"

# Find 'protoc' executable
protoc_x="$(which protoc)"
protoc_x="${protoc_x:-/opt/homebrew/bin/protoc}"
protoc_gen_swift_x="$(which protoc-gen-swift)"
protoc_gen_swift_x="${protoc_gen_swift_x:-/opt/homebrew/bin/protoc-gen-swift}"

if [ ! -x $protoc_x -o ! -x $protoc_gen_swift_x ]; then
	echo "warning: Could not find 'protoc' and/or 'protoc-gen-swift' executable. Consider installing via 'brew install swift-protobuf'"
	echo "warning: Unable to generate Swift protobuf message definition."
	exit 0
fi

# Generate swift code from the protobuf message
(set -x; "$protoc_x" --plugin="protoc-gen-swift=${protoc_gen_swift_x}" --swift_out="$root_dir" --proto_path="$root_dir" "$input_file")

rez=$?
if [ $rez = 0 ]; then
	echo "note: Generated Swift protobuf message represenation."
else
	echo "error: Unable to generate Swift code from protobuf message definition."
fi
exit $rez
