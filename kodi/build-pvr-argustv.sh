#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-pvr-argustv.sh
# Script Ver:	1.0.5
# Description:	Attempts to build a deb package from Kodi PVR argustv addon git source
#
# See:		https://github.com/kodi-pvr/pvr.argustv
#		http://www.cyberciti.biz/faq/linux-unix-formatting-dates-for-display/
# Usage:	build-pvr-argustv.sh
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

# repo destination vars (use only local hosts!)
USER="mikeyd"
HOST="archboxmtd"

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming"
	
fi

# upstream vars
git_url="https://github.com/kodi-pvr/pvr.argustv"
git_branch="Jarvis"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS=""
pkgname="kodi-pvr-argustv"
pkgver="1.11.10"
pkgrev="1"
pkgsuffix="git+bsos${pkgrev}"
DIST="brewmaster"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set build_dir
export build_dir="${HOME}/build-${pkgname}-temp"
git_dir="${build_dir}/${pkgname}"

install_prereqs()
{

	echo -e "\n==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config checkinstall bc \
	debhelper cmake kodi-pvr-dev libkodiplatform-dev kodi-addon-dev libjsoncpp-dev

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
	
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi


	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"

	git clone -b "$git_branch" "$git_url" "$git_dir"

	#################################################
	# Build platform
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create the tarball from latest tarball creation script
	# use latest revision designated at the top of this script

	# create source tarball
	tar -cvzf "${pkgname}_${pkgver}.orig.tar.gz" "${pkgname}"

	# emter source dir
	cd "${pkgname}"


 	# update changelog with dch

		dch -v "${pkgver}+${pkgsuffix}" -M --package "${pkgname}" -D "${DIST}" -u low

	else

		dch --create -v "${pkgver}+${pkgsuffix}" -M --package "${pkgname}" -D "${DIST}" -u low

	fi


	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

	#################################################
	# Cleanup
	#################################################

	# clean up dirs

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)

	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"


	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)

	# back out of build temp to script dir if called from git clone
	if [[ "${scriptdir}" != "" ]]; then
		cd "${scriptdir}" || exit
	else
		cd "${HOME}" || exit
	fi

	# If "build_all" is requested, skip user interaction

	if [[ "$build_all" == "yes" ]]; then

		echo -e "\n==INFO==\nAuto-build requested"
		mv ${build_dir}/*.deb "$auto_build_dir"
		sleep 2s

	else

		# inform user of packages
		echo -e "\n############################################################"
		echo -e "If package was built without errors you will see it below."
		echo -e "If you don't, please check build dependcy errors listed above."
		echo -e "############################################################\n"

		echo -e "Showing contents of: ${git_dir}/build: \n"
		ls "${build_dir}" | grep -E "${pkgver}" 

		echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
		sleep 0.5s
		# capture command
		read -ep "Choice: " transfer_choice

		if [[ "$transfer_choice" == "y" ]]; then

			# transfer files
			if [[ -d "${build_dir}/" ]]; then
				rsync -arv --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" ${build_dir}/ ${USER}@${HOST}:${REPO_FOLDER}

				# Preserve changelog
				cp "${git_dir}/debian/changelog" ""$scriptdir/debian"/changelog" 

			fi

		elif [[ "$transfer_choice" == "n" ]]; then
			echo -e "Upload not requested\n"
		fi

	fi

}

# start main
main
