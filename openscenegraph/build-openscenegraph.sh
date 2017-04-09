#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/mdeguzis/SteamOS-Tools
# Scipt name:	build-openscenegraph.sh
# Script Ver:	0.1.1
#		release
#
# See:		https://github.com/openscenegraph/OpenSceneGraph
#
# Usage:	./build-openscenegraph.sh
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

#################################################
# Set variables
#################################################

ARG1="$1"
SCRIPTDIR=$(pwd)
TIME_START=$(date +%s)
TIME_STAMP_START=(`date +"%T"`)

# Check if USER/HOST is setup under ~/.bashrc, set to default if blank
# This keeps the IP of the remote VPS out of the build script

if [[ "${REMOTE_USER}" == "" || "${REMOTE_HOST}" == "" ]]; then

	# fallback to local repo pool TARGET(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi

if [[ "$ARG1" == "--testing" ]]; then

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming_testing"

else

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming"

fi
# upstream var for master build
SRC_URL="https://github.com/openscenegraph/OpenSceneGraph"
TARGET="OpenSceneGraph-3.5.4"

# package vars
DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
DATE_SHORT=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
# The imported debian/ files from upstream have syntax errors for the 
# doxygen sequences. Build arch-dep packages for now.
BUILDOPTS="--debbuildopts -nc -- --binary-arch"
export STEAMOS_TOOLS_BETA_HOOK="false"
export NO_LINTIAN="false"
export NO_PKG_TEST="false"
export NO_APT_PREFS="true"
PKGNAME="openscenegraph"
PKGVER="3.5.4"
PKGREV="1"
PKGSUFFIX="git+bsos"
DIST="${DIST:=brewmaster}"
URGENCY="low"
UPLOADER="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
MAINTAINER="mdeguzis"

# set build directoriess
unset BUILD_TMP
export BUILD_TMP="${BUILD_TMP:=${HOME}/package-builds/build-${PKGNAME}-tmp}"
SRC_DIR="${BUILD_TMP}/${PKGNAME}-${PKGVER}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y debhelper debhelper dpkg-dev  cmake g++ \
	ccache doxygen libgif-dev libjpeg-dev libtiff-dev lib3ds-dev libfreetype6-dev \
	libpng-dev libcoin80-dev libjasper-dev libgdal-dev libx11-dev libxmu-dev freeglut3-dev \
	libgl1-mesa-dev libxine2-dev libavcodec-dev libswscale-dev libavdevice-dev \
	libavresample-dev libqt4-dev libqt4-opengl-dev librsvg2-dev libpoppler-glib-dev

}

main()
{

	# create BUILD_TMP
	if [[ -d "${BUILD_TMP}" ]]; then

		sudo rm -rf "${BUILD_TMP}"
		mkdir -p "${BUILD_TMP}"

	else

		mkdir -p "${BUILD_TMP}"

	fi

	# enter build dir
	cd "${BUILD_TMP}" || exit

	# install prereqs for build
	if [[ "${BUILDER}" != "pdebuild" && "${BUILDER}" != "sbuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi

		# Clone upstream source code and TARGET

	echo -e "\n==> Obtaining upstream source code\n"
	sleep 2s

	if [[ -d "${SRC_DIR}" || -f ${BUILD_TMP}/*.orig.tar.gz ]]; then

		echo -e "==Info==\nGit source files already exist! Remove and [r]eclone or [k]eep? ?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "r" ]]; then

			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# clean and clone
			sudo rm -rf "${BUILD_TMP}" && mkdir -p "${BUILD_TMP}"
			git clone -b "${TARGET}" "${SRC_DIR}" "${SRC_DIR}"

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
			git clone -b "${TARGET}" "${SRC_DIR}" "${SRC_DIR}"

	fi


	# Get latest commit
	cd "${SRC_DIR}"
	export ${PKGNAME}_LATEST_COMMIT=$(git log -n 1 --pretty=format:"%h")

	#################################################
	# prep source
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# Trim .git folders
	find "${SRC_DIR}" -name "*.git" -type d -exec sudo rm -r {} \;

	# create source tarball
	# For now, do not recreate the tarball if keep was used above (to keep it clean)
	# This way, we can try again with the orig source intact
	# Keep this method until a build is good to go, without error.
	
	if [[ "${retry}" == "no" ]]; then

		echo -e "\n==> Creating original tarball\n"
		sleep 2s
		cd "${BUILD_TMP}"
		tar -cvzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" $(basename ${SRC_DIR})
		
	else
	
		echo -e "\n==> Cleaning old source foldrers for retry"
		sleep 2s
		
		rm -rf *.dsc *.xz *.build *.changes ${SRC_DIR}
		mkdir -p "${SRC_DIR}"
	
		echo -e "\n==> Retrying with prior source tarball\n"
		sleep 2s
		cd "${BUILD_TMP}"
		tar -xzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" -C "${BUILD_TMP}" --totals
		sleep 2s

	fi


	# Add debian files
	cp -r "${SCRIPTDIR}/debian" "${SRC_DIR}"

	#################################################
	# build package
	#################################################

	# enter source dir
	cd "${SRC_DIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${PKGVER}+${PKGSUFFIX}-${PKGREV}" -M \
		--package "${PKGNAME}" -D "${DIST}" -u "${URGENCY}" "Update release to commit ${PKGNAME}_LATEST_COMMIT"
		vim "debian/changelog"

	else

		dch -p --create --force-distribution -v "${PKGVER}+${PKGSUFFIX}-${PKGREV}" -M \
		--package "${PKGNAME}" -D "${DIST}" -u "${URGENCY}" "Initial upload/backport"
		vim "debian/changelog"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${PKGNAME} from source\n"
	sleep 2s

	USENETWORK=$USENETWORK DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

	#################################################
	# Cleanup
	#################################################

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$TIME_START) / 60 " | bc)

	# output finish
	echo -e "\nTime started: ${TIME_STAMP_START}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"

	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)

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
			--filter="merge ${HOME}/.config/libregeek-packaging/repo-filter.txt" \
			${BUILD_TMP}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			# uplaod local repo changelog
			cp "${SRC_DIR}/debian/changelog" "${SCRIPTDIR}/debian"

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
