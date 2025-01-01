#!/bin/sh

# This is a lazy script to create a .bin for WD NAS build.
# You can give it the PKGARCH= argument
# i.e. PKGARCH=armv7hf contrib/nas/nas-westerndigital-os5.sh

if [ `pwd` != `git rev-parse --show-toplevel` ]
then
  echo "You should run this script from the top-level directory of the git repo"
  exit 1
fi

PKGBRANCH=$(sh -c 'cd RiV-mesh && basename `git name-rev --name-only HEAD`')
PKG=$(sh -c 'cd RiV-mesh && contrib/semver/name.sh')
PKGVERSION=$(sh -c 'cd RiV-mesh && contrib/semver/version.sh --bare')
PKGARCH=${PKGARCH-amd64}
PKGNAME=$ENV_TAG-$PKGARCH-$PKGVERSION
PKGFOLDER=${PKGNAME}/package
PKGREPLACES=mesh

if [ $PKGBRANCH = "master" ]; then
  PKGREPLACES=mesh-develop
fi

GOOS=linux
if [ $PKGARCH = "x86_64" ]; then
  GOARCH=amd64
elif [ $PKGARCH = "armv7" ]; then
  GOARCH=arm
  GOARM=7
elif [ $PKGARCH = "arm64" ]; then
  GOARCH=arm64
else
  echo "Specify PKGARCH=x86_64, armv7 or arm64"
  exit 1
fi

(cd RiV-mesh && GOOS=$GOOS GOARCH=$GOARCH ./build)

echo "Building $PKGNAME"

rm -rf /tmp/${PKGNAME}
mkdir -p /tmp/$PKGFOLDER/bin/
mkdir -p /tmp/$PKGFOLDER/lib/
mkdir -p /tmp/$PKGFOLDER/tmp/
mkdir -p /tmp/$PKGFOLDER/ui/
mkdir -p /tmp/$PKGFOLDER/var/log/
mkdir -p /tmp/$PKGFOLDER/var/lib/mesh

chmod 0775 /tmp/$PKGFOLDER/ -R

echo "coping ui package..."
cp contrib/ui/nas-synology-dsm6.0/package/* /tmp/$PKGFOLDER/ -r
cp contrib/ui/nas-synology-dsm6.0/spk/* /tmp/$PKGNAME/ -r
cp contrib/ui/nas-synology-dsm7.0/package/* /tmp/$PKGFOLDER/ -r
cp contrib/ui/nas-synology-dsm7.0/spk/* /tmp/$PKGNAME/ -r
cp -r -n contrib/ui/mesh-ui/ui/* /tmp/$PKGFOLDER/www/

for res in 16 24 32 48 64 72 256; do
  resolution="${res}x${res}"
  echo "Converting icon for: $resolution"
  convert-im6.q16 -colorspace sRGB logos/riv.png -resize $resolution PNG32:/tmp/$PKGFOLDER/ui/mesh-$res.png  && \
  chmod 644 /tmp/$PKGFOLDER/ui/mesh-$res.png
done

echo "Converting icon for: 64x64"
convert-im6.q16 -colorspace sRGB logos/riv.png -resize 64x64 PNG32:/tmp/$PKGNAME/PACKAGE_ICON.PNG
echo "Converting icon for: 256x256"
convert-im6.q16 -colorspace sRGB logos/riv.png -resize 256x256 PNG32:/tmp/$PKGNAME/PACKAGE_ICON_256.PNG

cat > /tmp/$PKGNAME/INFO << EOF
package="mesh"
displayname="RiV Mesh"
version="$PKGVERSION"
description="RiV-mesh is an implementation of a fully end-to-end encrypted IPv6 network. \
 It is lightweight, self-arranging, supported on multiple platforms and \
 allows pretty much any IPv6-capable application to communicate securely with \
 other RiV-mesh nodes."
maintainer="Riv Chain ltd"
maintainer_url="https://github.com/RiV-chain/RiV-mesh"
support_url="https://github.com/RiV-chain/RiV-mesh"
dsmappname="org.mesh"
arch="$PKGARCH"
dsmuidir="ui"
silent_upgrade="yes"
os_min_ver="7.0-40000"
EOF

echo $PKGVERSION > /tmp/$PKGNAME/VERSION

cp RiV-mesh/mesh /tmp/$PKGFOLDER/bin
cp RiV-mesh/meshctl /tmp/$PKGFOLDER/bin
cp RiV-mesh/LICENSE /tmp/$PKGNAME/

chmod -R 0755 /tmp/$PKGFOLDER/www/assets
chmod -R u+rwX,go+rX,g-w /tmp/$PKGFOLDER
chmod -R 0755 /tmp/$PKGNAME/scripts
chmod -R 0755 /tmp/$PKGNAME/conf

fakeroot ./contrib/nas/tool/synology_pkg_util.sh make_package /tmp/$PKGFOLDER /tmp/$PKGNAME
rm -rf /tmp/$PKGFOLDER/
fakeroot ./contrib/nas/tool/synology_pkg_util.sh make_spk /tmp/$PKGNAME . $PKGNAME.spk

