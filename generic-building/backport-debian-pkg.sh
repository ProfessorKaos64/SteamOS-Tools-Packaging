#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-rustc.sh
# Script Ver:	1.1.9
# Description:	Attempts to build a deb package from backported stretch package
#
# See:		https://github.com/rust-lang/rust
#
# Usage:	build-rustc.sh
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

#################################################
# Set variables
#################################################

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)


# Check if USER/HOST is setup under ~/.bashrc, set to default if blank
# This keeps the IP of the remote VPS out of the build script

if [[ "${REMOTE_USER}" == "" || "${REMOTE_HOST}" == "" ]]; then

	# fallback to local repo pool target(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi



if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming_testing"

else

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming"

fi

# Gather vars
echo -e "\n==> Setting vars\n"

read -erp "Target package name: " PKGNAME
read -erp "Target package version: " PKGVER
read -erp "Arch target: " ARCH
read -erp "Paste link to upsteam .dsc: " DSC
read -erp "Paste link to upsteam .orig.tar.gz: " ORIG_TAR_GZ

DSC_FILENAME=$(basename ${ORIG_TAR_GZ})

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="$ARCH"
BUILDER="pbuilder"
export STEAMOS_TOOLS_BETA_HOOK="false"
pkgname="$PKGNAME"
pkgver="$PKGVER"
upstream_rev="1"
pkgrev="1"
pkgsuffix="bpo8+bsos${pkgrev}"
DIST="jessie-backports"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set build_dir
export build_dir="${HOME}/build-${pkgname}-temp"
src_dir="${pkgname}-${pkgver}"
git_dir="${build_dir}/${src_dir}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get -y --force-yes install autoconf automake build-essential pkg-config bc debhelper \
 	g++ clang++ python make curl git

}

main()
{

	# create build_dir
	if [[ -d "${build_dir}" ]]; then

		sudo rm -rf "${build_dir}"
		mkdir -p "${build_dir}"

	else

		mkdir -p "${build_dir}"

	fi

	# enter build dir
	cd "${build_dir}" || exit

	# install prereqs for build

	if [[ "${BUILDER}" != "pdebuild" && "${BUILDER}" != "pbuilder" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi

	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"

	# We are backporting, so don't download anything here
	wget "${ORIG_TAR_GZ}" -q -nc --show-progress
	mv *.tar.gz "${pkgname}_${pkgver}+${pkgsuffix}.orig.tar.gz"

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Backporting Debian package ${pkgname} from source\n"
	sleep 2s

	#  build
	wget "${DSC}" -q -nc --show-progress

	sudo build_dir=${build_dir} DIST=${DIST} ARCH=${ARCH} "${BUILDER}" build --debbuildopts \
	"sa -v${pkgver}" "${DSC_FILENAME}" && rm -f ${DSC_FILENAME}

	#################################################
	# Cleanup
	#################################################
	
	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)
	
	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"
	
	# inform user of packages
	cat<<-EOF
	
	###############################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependcy errors listed above.
	###############################################################
	
	Showing contents of: ${build_dir}
	
	EOF

	ls "${build_dir}" | grep -E "${pkgver}" 

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${build_dir}" ]]; then
			rsync -arv -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${build_dir}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
