#!/usr/bin/env bash
# Builds the repositories with a throwaway key from the latest trk release,
# serves them, and installs trk from them with apt (Debian) and dnf
# (Fedora), each verifying the signatures. Then runs trk/install.sh on
# Ubuntu (as a sudoer), Fedora, openSUSE, Alpine and Arch. Needs Docker
# and gh.
#
#   scripts/test.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
net=hullop-packages-test-$$
cleanup() {
	docker rm -f "$net-site" >/dev/null 2>&1 || true
	docker network rm "$net" >/dev/null 2>&1 || true
	rm -rf "$work"
}
trap cleanup EXIT

mkdir "$work/pkgs"
gh release download --repo cirope/trk-cli --dir "$work/pkgs" \
	--pattern 'trk_linux_*.deb' --pattern 'trk_linux_*.rpm'

docker network create "$net" >/dev/null
url=http://$net-site:8000

echo "== build"
docker run --rm -e DEBIAN_FRONTEND=noninteractive -e OWNER="$(id -u):$(id -g)" -v "$root:/repo:ro" -v "$work:/work" ubuntu:24.04 bash -euc '
	apt-get update -qq >/dev/null
	apt-get install -qq -y apt-utils createrepo-c rpm gpg >/dev/null
	export GNUPGHOME=$(mktemp -d)
	gpg --batch --quiet --passphrase "" --quick-gen-key "Hullop test <test@example.com>" rsa4096 sign never
	KEY=test@example.com /repo/scripts/build.sh /work/pkgs /work/site '"$url"'
	# Root in here; hand the site back so the cleanup can remove it.
	chown -R "$OWNER" /work/site
	chmod -R a+rX /work/site
'

docker run -d --name "$net-site" --network "$net" -v "$work/site:/site:ro" \
	python:3-alpine python -m http.server 8000 --directory /site >/dev/null

echo "== apt (Debian)"
docker run --rm --network "$net" -e DEBIAN_FRONTEND=noninteractive debian:stable-slim bash -euc '
	apt-get update -qq >/dev/null && apt-get install -qq -y curl >/dev/null
	until curl -fsS '"$url"'/hullop.gpg -o /usr/share/keyrings/hullop.gpg; do sleep 1; done
	echo "deb [signed-by=/usr/share/keyrings/hullop.gpg] '"$url"'/apt stable main" >/etc/apt/sources.list.d/hullop.list
	apt-get update -qq >/dev/null
	apt-get install -qq -y trk >/dev/null
	trk --version
'

echo "== dnf (Fedora)"
docker run --rm --network "$net" fedora:latest bash -euc '
	curl -fsS '"$url"'/rpm/hullop.repo -o /etc/yum.repos.d/hullop.repo
	dnf install -q -y trk
	rpm -q --qf "%{NAME} %{VERSION} signed: %{RSAHEADER:pgpsig}\n" trk
	trk --version
'
# install.sh: the package repository where there is one, the release
# binary elsewhere.
installs() {
	echo "== install.sh ($1)"
	docker run --rm --network "$net" ${PLATFORM:+--platform "$PLATFORM"} "$2" sh -euc "$3"'
		trk --version >/dev/null'
}
installs "Ubuntu, as a sudoer" ubuntu:24.04 '
	apt-get update -qq >/dev/null && apt-get install -qq -y curl sudo >/dev/null
	useradd -m dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/dev
	su dev -c "curl -fsSL '"$url"'/trk/install.sh | sh"
	test -f /etc/apt/sources.list.d/hullop.list'
installs Fedora fedora:latest '
	curl -fsSL '"$url"'/trk/install.sh | sh
	test -f /etc/yum.repos.d/hullop.repo'
installs openSUSE opensuse/tumbleweed '
	command -v curl >/dev/null || zypper -q -n install curl >/dev/null
	curl -fsSL '"$url"'/trk/install.sh | sh
	zypper -q repos hullop >/dev/null'
installs "Alpine, with wget" alpine:latest '
	wget -qO- '"$url"'/trk/install.sh | sh
	apk info -e trk >/dev/null'
# Arch publishes amd64 images only.
PLATFORM=linux/amd64 installs "Arch, the binary" archlinux:latest '
	curl -fsSL '"$url"'/trk/install.sh | sh
	test -x /usr/local/bin/trk'
echo "== ok"
