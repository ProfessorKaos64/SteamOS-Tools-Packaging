#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	Michael DeGuzis
# Git:	    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name	build-pcsx2.sh
# Script Ver:	0.9.7
# Description:	Attempts to build a deb package from PCSX2 git source
#		It is highly suggested to build in a 32 bit environment!!!
#		Ref: https://github.com/ProfessorKaos64/RetroRig/pull/85
#
# See:		https://code.google.com/p/pcsx2/wiki/CompilationGuideForLinux
# Usage:	./build-pcsx2.sh
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

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b"
export STEAMOS_TOOLS_BETA_HOOK="false"
pkgname="pcsx2"
pkgrev="1"
DIST="brewmaster"
urgency="low"
ARCH="i386"
BUILDER_OPTS="--basetgz merge ${HOME}/pbuilder/brewmaster-i386-base.tgz"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# sub-packages (used for copying to package pool only)
subpkg1="pcsx2-dbg"

# build dirs
export BUILD_DIR="/home/desktop/build-pcsx2-temp"
src_dir="${pkgname}-${pkgver}"
git_dir="$BUILD_DIR/${pkgname}"
git_url="https://github.com/PCSX2/pcsx2"
branch="master"

# package vars
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

install_prereqs()
{
	
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install needed packages
	sudo apt-get install -y --force-yes git devscripts build-essential checkinstall

	echo -e "\n==> Installing pcsx2 build dependencies...\n"
	sleep 2s

	#############################################################
	# Check for i386 environment, warn user before building
	#############################################################
	
	arch_check=$(uname -m)
	if [[ "$arch_check" == "i386" ]]; then
	
		# 32-bit build depedencies required to build on x86_64
		sudo apt-get install -y --force-yes libaio-dev:i386 libasound2-dev:i386 \
		libbz2-dev:i386 libcg:i386 libcggl:i386 libwayland-dev:i386 libegl1-mesa-dev:i386 \
		libgl1-mesa-dev:i386 libglew-dev:i386 libglu1-mesa-dev:i386 libglu1-mesa-dev:i386 \
		libwxgtk3.0-dev:i386 libjpeg62-turbo-dev:i386 libfreetype6-dev:i386 libdirectfb-dev:i386 \
		libglib2.0-dev:i386 libavahi-client-dev:i386 libpulse-dev:i386 libsdl1.2-dev:i386 \
		libsoundtouch-dev:i386 libsparsehash-dev libwxbase3.0-dev:i386 libx11-dev:i386 \
		nvidia-cg-dev:i386 nvidia-cg-toolkit portaudio19-dev:i386 zlib1g-dev:i386 \
		libgtk2.0-dev libpng++-dev libsdl2-dev
		
	elif [[ "$arch_check" == "x86_64" ]]; then
	
		# 32-bit build depedencies required to build on x86_64
		sudo apt-get install -y --force-yes devscripts build-essential checkinstall \
		cmake debhelper dpkg-dev libaio-dev libasound2-dev libbz2-dev libgl1-mesa-dev \
		libglu1-mesa-dev libgtk2.0-dev libpng12-dev libpng++-dev libpulse-dev libsdl2-dev \
		libsoundtouch-dev libwxbase3.0-dev libwxgtk3.0-dev libx11-dev locales portaudio19-dev zlib1g-dev 
		
	fi

}

main()
{
	# Note: based on:
	# https://github.com/PCSX2/pcsx2/blob/master/debian-packager/create_built_tarball.sh

	# create BUILD_DIR
	if [[ -d "${BUILD_DIR}" ]]; then

		sudo rm -rf "${BUILD_DIR}"
		mkdir -p "${BUILD_DIR}"

	else

		mkdir -p "${BUILD_DIR}"

	fi

	# enter build dir
	cd "${BUILD_DIR}" || exit

	# install prereqs for build
	
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi


	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"
	
	# clone and checkout desired commit
        git clone -b "$branch" "$git_url" "${git_dir}"
        cd "${git_dir}"
        
	# get latest base release
	# This is used because upstream does tends to use release tags
	release_tag=$(git describe --abbrev=0 --tags)
	git checkout $release_tag 1> /dev/null
	
	# cleanup for pkg version naming
	pkgver=$(sed "s|[-|a-z]||g" <<<"$release_tag")

        # Alter pkg suffix based on commit
        pkgsuffix="git+bsos${pkgrev}"

	#################################################
	# Prepare build (upstream-specific)
	#################################################

	echo -e "\nRemove 3rdparty code"
	rm -fr "$git_dir/3rdparty"
	rm -fr "$git_dir/fps2bios"
	rm -fr "$git_dir/tools"
	
	echo "Remove non free plugins"
	# remove also deprecated plugins
	for plugin in CDVDiso CDVDisoEFP CDVDlinuz CDVDolio CDVDpeops dev9ghzdrk \
	PeopsSPU2 SSSPSXPAD USBqemu xpad zerogs zerospu2
	do
		rm -fr "$git_dir/plugins/$plugin"
	done

	echo "Remove remaining non free file. TODO UPSTREAM"
	rm -rf $git_dir/unfree
	rm -rf $git_dir/plugins/GSdx/baseclasses
	rm -f  $git_dir/plugins/zzogl-pg/opengl/Win32/aviUtil.h
	rm -f  $git_dir/common/src/Utilities/x86/MemcpyFast.cpp
	
	# To save 66% of the package size
	# rm -rf  $git_dir/.git
	
	# copy in debian folder
	cp -r "$scriptdir/debian" "${git_dir}/debian"

	#################################################
	# Build platform
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create the tarball from latest tarball creation script
	# use latest revision designated at the top of this script

	# create source tarball
	tar -cvzf "${pkgname}_${pkgver}.orig.tar.gz" "${src_dir}"

	# enter source dir
	cd "${git_dir}"


	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}"

	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}"

	fi


	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	#  build within i386 environment
	ARCH=i386 DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

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
	
	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"
	
	echo -e "Showing contents of: ${BUILD_DIR}: \n"
	ls "${BUILD_DIR}" | grep $pkgver

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${BUILD_DIR}" ]]; then
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}


			# Only move the old changelog if transfer occurs to keep final changelog 
			# out of the picture until a confirmed build is made. Remove if upstream has their own.
			cp "${git_dir}/debian/changelog" "${scriptdir}/debian"

		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi


}

# start main
main
