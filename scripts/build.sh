#!/usr/bin/env bash
# Builds Hullop's signed apt and dnf repositories from a directory of
# .deb and .rpm packages. The publish workflow runs it and serves the result
# on GitHub Pages; scripts/test.sh runs it against real package managers.
#
#   KEY=<signing key> scripts/build.sh <packages dir> <site dir> <site url>
#
# KEY names the signing key in gpg's keyring. Needs apt-ftparchive
# (apt-utils), createrepo_c, rpmsign (rpm) and gpg. Only the packages given
# are served: a package manager installs and upgrades to the newest anyway.
set -euo pipefail

if [ $# -ne 3 ] || [ -z "${KEY:-}" ]; then
	echo "usage: KEY=<signing key> $0 <packages dir> <site dir> <site url>" >&2
	exit 2
fi
pkgs=$(cd "$1" && pwd)
site=$2
url=${3%/}

shopt -s nullglob
debs=("$pkgs"/*.deb)
rpms=("$pkgs"/*.rpm)
if [ ${#debs[@]} -eq 0 ] || [ ${#rpms[@]} -eq 0 ]; then
	echo "$0: no .deb or no .rpm in $pkgs" >&2
	exit 1
fi

sign() { gpg --batch --yes --local-user "$KEY" "$@"; }

rm -rf "$site"
mkdir -p "$site/apt/pool" "$site/rpm"
site=$(cd "$site" && pwd)

# The public key, armored (dnf, zypper) and binary (apt's signed-by).
gpg --batch --export --armor "$KEY" >"$site/hullop.asc"
gpg --batch --export "$KEY" >"$site/hullop.gpg"

# Each product's install script, pointed at this site.
root=$(cd "$(dirname "$0")/.." && pwd)
for script in "$root"/*/install.sh; do
	product=$(basename "$(dirname "$script")")
	mkdir -p "$site/$product"
	sed "s|@URL@|$url|g" "$script" >"$site/$product/install.sh"
done

# apt: one suite, "stable", one component, "main".
cp "${debs[@]}" "$site/apt/pool/"
(
	cd "$site/apt"
	for arch in amd64 arm64; do
		dir=dists/stable/main/binary-$arch
		mkdir -p "$dir"
		apt-ftparchive --arch "$arch" packages pool >"$dir/Packages"
		gzip -9kn "$dir/Packages"
	done
	apt-ftparchive \
		-o APT::FTPArchive::Release::Origin=Hullop \
		-o APT::FTPArchive::Release::Label=Hullop \
		-o APT::FTPArchive::Release::Suite=stable \
		-o APT::FTPArchive::Release::Codename=stable \
		-o APT::FTPArchive::Release::Architectures="amd64 arm64" \
		-o APT::FTPArchive::Release::Components=main \
		release dists/stable >Release.tmp
	mv Release.tmp dists/stable/Release
	sign --clearsign --output dists/stable/InRelease dists/stable/Release
	sign --armor --detach-sign --output dists/stable/Release.gpg dists/stable/Release
)

# dnf and zypper: each package signed, and the metadata.
cp "${rpms[@]}" "$site/rpm/"
rpmsign --define "_gpg_name $KEY" --define "__gpg $(command -v gpg)" --addsign "$site"/rpm/*.rpm >/dev/null
createrepo_c --quiet "$site/rpm"
sign --armor --detach-sign --output "$site/rpm/repodata/repomd.xml.asc" "$site/rpm/repodata/repomd.xml"
cat >"$site/rpm/hullop.repo" <<EOF
[hullop]
name=Hullop
baseurl=$url/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$url/hullop.asc
EOF

# People who open the site, or a repository's folder, in a browser get the
# install instructions.
for dir in "$site" "$site/apt" "$site/rpm"; do
	cat >"$dir/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Hullop packages</title>
<meta http-equiv="refresh" content="0; url=https://github.com/cirope/packages#readme">
<p>Install instructions: <a href="https://github.com/cirope/packages#readme">github.com/cirope/packages</a>.</p>
HTML
done
