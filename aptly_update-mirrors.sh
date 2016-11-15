#!/bin/bash
timestamp=`date +%Y%m%d%S`
gpgpassword=
# export http_proxy=
# export https_proxy=

for mirror in `aptly mirror list | grep "*" | sed -e 's!\].*!!g' | sed -e 's!.*\[!!g'`
  do
    echo "updating mirror $mirror"
    aptly mirror update $mirror
    aptly snapshot create $timestamp_$mirror from mirror $mirror
    aptly publish drop $mirror && \
    aptly publish snapshot -passphrase="$gpgpassword" -distribution="$mirror" $timestamp_$mirror && \
    echo "mirror $mirror successfully updated"
  done

# unset http_proxy && unset https_proxy
