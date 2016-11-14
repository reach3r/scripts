#!/bin/bash
#
# Mattermost Team Edition Update Script for WLW.de by Dominik Janczyk
# created April 2016
#
# Description:
# This script downloads Mattermost, attempts a backup of the current installation folder and if successful proceeds with an in-place upgrade to the version specified.
# It takes one argument: the version to which Mattermost should be upgraded in the following format: 1.2.3
# WARNING: This script is not smart, it cannot deal with changes that require a human to make decisions. Check the release notes before attempting the update wether there are manual actions needed for the upgrade (as was the case with version 3)
# Also it does not make a database backup.
#
# REMINDER: Be sure to check and modify the variables in lines 22ff. according to your deployment.
if [[ "$(whoami)" != 'root' ]]; then
    echo "root permissions are needed to run this script successfully! Aborting..."
    exit 1;
fi
if [[ ! "$1" =~ ^[0-9]\.[0-9]\.[0-9]$ ]]; then
    echo "version number $1 not valid! Aborting..."
    exit 1;
fi

MMUSER="mmuser"
MMBASEDIR="/opt"
MMDIR="$MMBASEDIR/mattermost"
MMBACKUPDIR="/var/mattermost/backup"
MMURL="https://releases.mattermost.com/$1/mattermost-team-$1-linux-amd64.tar.gz"
TODAY=$(date +%Y-%m-%d)

WGET=$(which wget)
TAR=$(which tar)

echo "determining whether to use systemctl or service"
if [[ $(which systemctl) == 0 ]]; then
	STARTMATTERMOST="$(which systemctl) start mattermost"
	STOPMATTERMOST="$(which systemctl) stop mattermost"
else
	STARTMATTERMOST="$(which service) mattermost start"
	STOPMATTERMOST="$(which service) mattermost stop"
fi

echo "Downloading Mattermost team version $1"
$WGET -O /tmp/mattermost-$1.tar.gz $MMURL
echo "stopping Mattermost"
$STOPMATTERMOST
echo "backing up current Mattermost Folder"
test -d $MMBACKUPDIR || mkdir -p $MMBACKUPDIR
$TAR -czf $MMBACKUPDIR/mattermost-backup-$TODAY.tar.gz $MMDIR || (echo "backing up current Mattermost installation failed. Aborting..." && exit 1)
echo "backing up current config.json"
cp $MMDIR/config/config.json $MMBACKUPDIR/config.json.pre-$1.bak
echo "unpacking new version"
$TAR -xzf /tmp/mattermost-$1.tar.gz -C $MMBASEDIR --overwrite
echo "bringing back custom config.json"
cp -f $MMBACKUPDIR/config.json.pre-$1.bak $MMDIR/config/config.json
echo "fixing permissions"
chown -R $MMUSER:$MMUSER $MMDIR
echo "starting Mattermost"
$STARTMATTERMOST
if [ $? != 0 ]; then
	echo "something went wrong starting Mattermost after the upgrade. Please examine."
	echo -n "do you want me to roll back? (Y/n): "
	read answer
	if [[ $answer -eq "y" || $answer -eq "yes" || $answer -eq "" ]]; then
		$STOPMATTERMOST && echo "stopped mattermost"
		rm -rf $MMDIR && echo "deleted mattermost directory"
		tar -xzf $MMBACKUPDIR/mattermost-backup-$TODAY.tar.gz -C $MMBASEDIR && echo "unpacked previously made backup"
		$STARTMATTERMOST && echo "starting mattermost"
	else
		exit 1;
	fi
fi
echo "deleting temporary file"
rm /tmp/mattermost-$1.tar.gz
echo "Mattermost successfully updated to version $1!"

exit 0
