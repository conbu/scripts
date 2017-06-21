#!/bin/bash -eu

# This script is for downloading logs saved in Sakura Object Storage.
# Log file name convention is assumed to be "log_${date}_${number}.gz", such as "log_2017030906_0.gz".
# The grep option is used to extract logs based on date ("-e 20170401").

echo -n "Type output/bucket directory: "
read OUTPUT
echo -n "Type grep option (e.g. '-e 20170101 -e 20170102'): "
read GREPOPT

echo
echo "Settings: OUTPUT/BUCKET='${OUTPUT}' GREPOPT='${GREPOPT}'"
echo

echo "Execute s3cmd configuration:"
echo "1. Set "Access Key", "Secret Key" from Access Key info in object storage page (priviledge with r/w is recommended)"
echo "2. Leave settings other than below empty"
echo "  - 'Test access with supplied credentials?' as n"
echo "  - 'Save settings?' as y"
echo

echo "------------------------------- s3cmd configure start ------------------------------"
s3cmd --configure
echo "------------------------------- s3cmd configure end ------------------------------"
echo "Editing ~/.s3cfg"
sed -i -e "s/signature_v2 = False/signature_v2 = True/" ~/.s3cfg
sed -i -e "s/host_base = .*/host_base = b.sakurastorage.jp/" ~/.s3cfg
sed -i -e "s/host_bucket = .*/host_bucket = %(bucket)s.b.sakurastorage.jp/" ~/.s3cfg
echo

echo -n "Testing s3cmd: "
set +e
s3cmd du s3://${OUTPUT} 1>/dev/null
RESULT=$?
case $RESULT in
  0)
    echo "OK"
    ;;
  *)
    echo "NG"
    echo "Existing"
    exit 1
    ;;
esac
set -e

echo "Making directory"
mkdir -p ./${OUTPUT}

echo "cd to output directory"
cd ${OUTPUT}

echo "Downloading objects (grep ${GREPOPT})"
s3cmd ls s3://${OUTPUT} | grep ${GREPOPT} | awk '{print $4}' | xargs -I@ s3cmd get @

echo "object downloaded to ./${OUTPUT}"
