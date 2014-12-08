#!/usr/bin/env bash

# tijscore
#
# Copyright (c) 2014 by Appcelerator, Inc. All Rights Reserved.
# Licensed under the terms of the Apache Public License.
# Please see the LICENSE included with this distribution for details.

declare -r configuration="Release"
declare -r sdk_list="iphoneos iphonesimulator"
#declare -r sdk_list="iphonesimulator"
declare -r iphoneos_arch_list="armv7 arm64"
declare -r iphonesimulator_arch_list="i386 x86_64"
#declare -r iphonesimulator_arch_list="x86_64"

# No user serviceable parts below this line.

declare -r project_name_list="WTF JavaScriptCore"
declare -r build_dir="build"
declare -r universal_library_path="${build_dir}/libTiCore.a"
declare -r private_header_dir="${build_dir}/PRIVATE_HEADERS"
declare -r public_header_dir="${build_dir}/PUBLIC_HEADERS/JavaScriptCore"

function echo_and_eval {
    local -r cmd="${1:?}"
    echo "${cmd}" && eval "${cmd}"
}

echo_and_eval "rm -rf \"${build_dir}\""
echo_and_eval "mkdir -p \"${private_header_dir}\" \"${public_header_dir}\""

library_path_list=""
for project_name in ${project_name_list}; do
		project="${project_name}/${project_name}.xcodeproj"
		for sdk in ${sdk_list}; do
				project_build_dir="${project_name}/build/${configuration}-${sdk}"
				xcodebuild="xcodebuild -project ${project} -sdk ${sdk} -configuration ${configuration} -target ${project_name}"
				echo_and_eval "rm -rf ${project_build_dir}"
				arch_list="${sdk}_arch_list"
				for arch in ${!arch_list}; do
						if [ "${project_name}" = "JavaScriptCore" ]; then
								echo_and_eval "(cd \"${build_dir}\"; ln -sf libWTF-${arch}.a libWTF.a)"
						fi

						log_file="${build_dir}/build_output-${project_name}-${sdk}-${arch}.txt"
						echo_and_eval "(time ${xcodebuild} clean        ) | tee    ${log_file}"
						echo_and_eval "(time ${xcodebuild} -arch ${arch}) | tee -a ${log_file}"
						
						library_name1="lib${project_name}.a"
						library_path1="${project_build_dir}/${library_name1}"

						library_name2="lib${project_name}-${arch}.a"
						library_path2="${build_dir}/${library_name2}"
						echo_and_eval "cp -p \"${library_path1}\" \"${library_path2}\""

						if [ "${project_name}" = "JavaScriptCore" ]; then
								library_path_list+=" ${library_path2}"
						fi
				done # arch

				if [ "${project_name}" = "WTF" ]; then
						echo_and_eval "(time cp -n -a -v \"${project_build_dir}/usr/local/include/\" \"${private_header_dir}\")"
				fi

				if [ "${project_name}" = "JavaScriptCore" ]; then
						echo_and_eval "(time cp -n -a -v \"${project_build_dir}/PRIVATE_HEADERS/\" \"${private_header_dir}\")"
						echo_and_eval "(time cp -n -a -v \"${project_build_dir}/usr/local/include/\" \"${public_header_dir}\")"
				fi
				
		done # sdk
done # project_name


echo_and_eval "lipo ${library_path_list} -create -output ${universal_library_path}"

for sdk in ${sdk_list}; do
		arch_list="${sdk}_arch_list"
		for arch in ${!arch_list}; do
				echo_and_eval "xcrun -sdk iphoneos lipo ${universal_library_path} -verify_arch ${arch}"
				if (( $? != 0 )); then
						echo "LOGIC ERROR: YOU DID NOT BUILD IN SYMBOLS FOR ${arch}"
						exit 1
				fi
		done
done

echo_and_eval "xcrun -sdk iphoneos lipo -info ${universal_library_path}"
