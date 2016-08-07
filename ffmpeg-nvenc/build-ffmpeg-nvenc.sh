#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-ffmpeg-nvenc.sh
# Script Ver:	0.8.9
# Description:	Attmpts to build a deb package from ffmpeg-nvenc git source,
#		This is a *rebuild* of the Ubuntu package.
#
# See:		https://trac.ffmpeg-nvenc.org/wiki/CompilationGuide/Ubuntu
#		http://archive.ubuntu.com/ubuntu/pool/universe/f/ffmpeg-nvenc/ffmpeg-nvenc_2.5.8-0ubuntu0.15.04.1.dsc
#		http://packages.ubuntu.com/wily/ffmpeg-nvenc
# Usage:	./build-ffmpeg-nvenc.sh
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

	# fallback to local repo pool TARGET(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming"
	
fi

GIT_URL="https://github.com/ffmpeg/ffmpeg"
TARGET="release/3.1"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b --debbuildopts -nc"
export STEAMOS_TOOLS_BETA_HOOK="false"
PKGNAME="ffmpeg-nvenc"
epoch="8"
PKGVER="3.1.0"
PKGREV="2"
PKGSUFFIX="nvenc1+bsos"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set BUILD_TMP
export BUILD_TMP="${HOME}/build-${PKGNAME}-tmp"
SRCDIR="${PKGNAME}-${PKGVER}"
GIT_DIR="${BUILD_TMP}/${SRCDIR}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get -y --force-yes install autoconf automake build-essential libass-dev libfreetype6-dev \
	libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev \
	libxcb-xfixes0-dev pkg-config texinfo zlib1g-dev bc checkinstall

	echo -e "\n==> Installing $PKGNAME build dependencies...\n"
	sleep 2s

	### REPLACE THESE WITH PACKAGES SPECIFIED BY UPSTREAM SOURCE ###
	sudo apt-get -y --force-yes install yasm libx264-dev cmake mercurial libmp3lame-dev \
	libopus-dev

}

main()
{

	# install prereqs for build

	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	else

		# required for dh_clean
		sudo apt-get install -y --force-yes pkg-kde-tools

	fi

	# Clone upstream source code and TARGET

	echo -e "\n==> Obtaining upstream source code\n"
	sleep 2s

	if [[ -d "${GIT_DIR}" || -f ${BUILD_TMP}/*.orig.tar.gz ]]; then

		echo -e "==Info==\nGit source files already exist! Remove and [r]eclone or [k]eep? ?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "r" ]]; then

			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# clean and clone
			sudo rm -rf "${BUILD_TMP}" && mkdir -p "${BUILD_DIR}"
			git clone -b "${TARGET}" "${GIT_URL}" "${GIT_DIR}"

		else

			# Unpack the original source later on for  clean retry
			# set retry flag
			retry="yes"

		fi

	else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# create and clone to current dir
			mkdir -p "${BUILD_TMP}" || exit 1
			git clone -b "${TARGET}" "${GIT_URL}" "${GIT_DIR}"

	fi
	
	# Add files necessary for nvenc
	# Adapted from https://github.com/lutris/ffmpeg-nvenc-nvenc/blob/master/build.sh
	# NVENC_INC_DIR is defined inside debian/rules to be $(CURDIR)/nvenc

	echo -e "\n==> Installing the NVidia Video SDK for build-time only\n"
	sleep 2s

	export NVENC_INC_DIR="${GIT_DIR}/nvenc-sdk/include"

	rm -f ${BUILD_TMP}/*.zip* "${NVENC_INC_DIR}"
	mkdir -p "${NVENC_INC_DIR}"
	SDK_VER="6.0.1"
	SDK_BASENAME="nvidia_video_sdk_${SDK_VER}"
	SDK_URL="http://developer.download.nvidia.com/assets/cuda/files/${SDK_BASENAME}.zip"
	wget -P "${BUILD_TMP}" "${SDK_URL}"
	unzip -o "${BUILD_TMP}/${SDK_BASENAME}.zip" -d "${BUILD_DIR}" && rm -f "${SDK_BASENAME}.zip"
	cp -rv ${BUILD_TMP}/${SDK_BASENAME}/Samples/common/inc/* "${NVENC_INC_DIR}"

	# trim git (after confimed working build)
	rm -rf "${GIT_DIR}/.git"

	#################################################
	# Prep source
	#################################################

	# create source tarball
	# For now, do not recreate the tarball if keep was used above (to keep it clean)
	# This way, we can try again with the orig source intact
	# Keep this method until a build is good to go, without error.
	
	if [[ "${retry}" == "no" ]]; then

		echo -e "\n==> Creating original tarball\n"
		sleep 2s
		cd "${BUILD_TMP}"
		tar -cvzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" "${SRCDIR}"

	else

		echo -e "\n==> Cleaning old source folders for retry"
		sleep 2s

		rm -rf *.dsc *.xz *.build *.changes ${GIT_DIR}
		mkdir -p "${GIT_DIR}"

		echo -e "\n==> Retrying with prior source tarball\n"
		sleep 2s
		cd "${BUILD_TMP}"
		tar -xzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" -C "${BUILD_TMP}" --totals
		sleep 2s

	fi

	# Try using upstream debian/
	cp -r "${scriptdir}/debian" "${GIT_DIR}"

	###############################################################
	# build package
	###############################################################

	# enter source dir
	cd "${GIT_DIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${epoch}:${PKGVER}+${PKGSUFFIX}-${PKGREV}" --package \
		"${PKGNAME}" -D "${DIST}" -u "${urgency}" "Rebuild of Ubuntu ffmpeg-nvenc ${PKGVER}"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${epoch}:${PKGVER}+${PKGSUFFIX}-${PKGREV}" --package \
		"${PKGNAME}" -D "${DIST}" -u "${urgency}" "Initial upload"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${PKGNAME} from source\n"
	sleep 2s

	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

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
	cat<<- EOF
	#################################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependency errors listed above.
	#################################################################

	EOF

	echo -e "Showing contents of: ${BUILD_TMP}: \n"
	ls "${BUILD_TMP}" | grep -E *${PKGVER}*

	# Ask to transfer files if debian binries are built
	# Exit out with log link to reivew if things fail.

	if [[ $(ls "${BUILD_TMP}" | grep -w "deb" | wc -l) -gt 0 ]]; then

		echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
		sleep 0.5s
		# capture command
		read -erp "Choice: " transfer_choice

		if [[ "$transfer_choice" == "y" ]]; then

			# copy files to remote server
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" \
			--filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_TMP}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			# uplaod local repo changelog
			cp "${GIT_DIR}/debian/changelog" "${scriptdir}/debian"

		elif [[ "$transfer_choice" == "n" ]]; then
			echo -e "Upload not requested\n"
		fi

	else

		# Output log file to sprunge (pastebin) for review
		echo -e "\n==OH NO!==\nIt appears the build has failed. See below log file:"
		cat ${BUILD_TMP}/${PKGNAME}*.build | curl -F 'sprunge=<-' http://sprunge.us

	fi

}

# start main
main
