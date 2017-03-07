#!/bin/bash -e

secrets_url="taskcluster/secrets/v1/secret/repo:github.com/mozilla-releng/OpenCloudConfig:updatetooltoolrepo"
curl -s -N ${secrets_url} | jq -r '.secret.tooltool.upload.internal' > ./.tooltool.token
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] tooltool token downloaded"

curl -O https://raw.githubusercontent.com/mozilla/build-tooltool/master/tooltool.py
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] tooltool client downloaded"

for manifest in $(ls ./OpenCloudConfig/userdata/Manifest/gecko-*.json); do
  echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] processing Manifest ${manifest}"

  jq -r '.Components[] | select(.ComponentType == "ExeInstall") | .ComponentName' ${manifest} | while read ComponentName; do
    echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] processing ExeInstall ${ComponentName}"

    filename=./${ComponentName}.exe
    www_url=$(jq --arg ComponentName ${ComponentName} -r '.Components[] | select(.ComponentType == "ExeInstall" and .ComponentName == $ComponentName) | .Url' ${manifest})
    curl -o ${filename} ${www_url}
    echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] ${ComponentName}.exe downloaded"

    sha512=$(sha512sum ${filename} | { read sha _; echo $sha; })
    tt_url="https://api.pub.build.mozilla.org/tooltool/sha512/${sha512}"
    if curl --header "Authorization: Bearer $(cat ./.tooltool.token)" --output /dev/null --silent --head --fail ${tt_url}; then
      echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] ${ComponentName} found in tooltool: ${tt_url}"
    elif grep -q ${sha512} ./manifest.tt; then
      echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] ${ComponentName} found in manifest.tt (SHA 512: ${sha512})"
    else
      python ./tooltool.py add --visibility internal ${filename}
      echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] ${ComponentName} added to manifest.tt (SHA 512: ${sha512})"
    fi
  done
done

if [ -f ./manifest.tt ] && grep -q "sha512" ./manifest.tt; then
  python ./tooltool.py upload --url https://api.pub.build.mozilla.org/tooltool --authentication-file=./.tooltool.token --message "Bug 1342892 - OCC installers"
  echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] installers uploaded to tooltool"
  rm ./manifest.tt
fi
shred -u ./.tooltool.token