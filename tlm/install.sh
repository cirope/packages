#!/bin/sh
# Installs tlm, Tlm's command-line client, the best way for this system:
#
#   curl -fsSL @URL@/tlm/install.sh | sh
#
# Debian, Ubuntu, Fedora, RHEL, CentOS Stream and openSUSE get Hullop's
# signed package repository, so the usual system upgrade brings each new
# release. macOS gets Homebrew when it is there. Anywhere else, the release
# binary is checked against the release's checksums and put in
# /usr/local/bin. Running it again upgrades.
set -eu

URL=@URL@
RELEASES=https://github.com/cirope/tlm-cli/releases/latest/download

say() { printf '%s\n' "$*" >&2; }
die() {
	say "tlm install: $*"
	exit 1
}
has() { command -v "$1" >/dev/null 2>&1; }

# fetch <url> <file>
fetch() {
	if has curl; then
		curl -fsSL --proto-redir '=https' -o "$2" "$1"
	elif has wget; then
		wget -q -O "$2" "$1"
	else
		die "needs curl or wget"
	fi
}

# as_root runs a command as root: directly, or through sudo or doas.
as_root() {
	if [ "$(id -u)" = 0 ]; then
		"$@"
	elif has sudo; then
		sudo "$@"
	elif has doas; then
		doas "$@"
	else
		die "needs root, sudo or doas to run: $*"
	fi
}

arch() {
	case $(uname -m) in
	x86_64 | amd64) echo amd64 ;;
	aarch64 | arm64) echo arm64 ;;
	*) die "no tlm build for $(uname -m); see https://github.com/cirope/tlm-cli" ;;
	esac
}

with_apt() {
	say "Adding Hullop's apt repository..."
	tmp=$(mktemp)
	fetch "$URL/hullop.gpg" "$tmp"
	as_root install -m 0644 "$tmp" /usr/share/keyrings/hullop.gpg
	rm -f "$tmp"
	echo "deb [signed-by=/usr/share/keyrings/hullop.gpg] $URL/apt stable main" |
		as_root tee /etc/apt/sources.list.d/hullop.list >/dev/null
	as_root apt-get update -qq -o Dir::Etc::sourcelist=sources.list.d/hullop.list \
		-o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0
	as_root env DEBIAN_FRONTEND=noninteractive apt-get install -qq -y tlm
	upgrade="sudo apt update && sudo apt upgrade"
}

with_dnf() {
	say "Adding Hullop's dnf repository..."
	tmp=$(mktemp)
	fetch "$URL/rpm/hullop.repo" "$tmp"
	as_root install -m 0644 "$tmp" /etc/yum.repos.d/hullop.repo
	rm -f "$tmp"
	as_root "$1" install -q -y tlm
	upgrade="sudo $1 upgrade"
}

with_zypper() {
	say "Adding Hullop's zypper repository..."
	if ! zypper --quiet repos hullop >/dev/null 2>&1; then
		as_root zypper --quiet addrepo "$URL/rpm/hullop.repo"
	fi
	as_root zypper --quiet --gpg-auto-import-keys --non-interactive install tlm
	upgrade="sudo zypper update"
}

with_apk() {
	say "Installing the Alpine package..."
	dir=$(mktemp -d)
	fetch "$RELEASES/tlm_linux_$(arch).apk" "$dir/tlm.apk"
	checked "$dir" "tlm_linux_$(arch).apk" tlm.apk
	as_root apk add --quiet --allow-untrusted "$dir/tlm.apk"
	rm -rf "$dir"
	upgrade="this script again"
}

with_brew() {
	say "Installing with Homebrew..."
	brew install --quiet cirope/tap/tlm
	upgrade="brew upgrade"
}

with_binary() {
	os=$1
	say "Installing the release binary to /usr/local/bin..."
	dir=$(mktemp -d)
	fetch "$RELEASES/tlm_${os}_$(arch).tar.gz" "$dir/tlm.tar.gz"
	checked "$dir" "tlm_${os}_$(arch).tar.gz" tlm.tar.gz
	tar -xzf "$dir/tlm.tar.gz" -C "$dir" tlm
	as_root mkdir -p /usr/local/bin
	as_root install -m 0755 "$dir/tlm" /usr/local/bin/tlm
	rm -rf "$dir"
	upgrade="this script again"
}

# checked <dir> <release file name> <local name>: fails unless the file
# matches the release's checksums.
checked() {
	fetch "$RELEASES/checksums.txt" "$1/checksums.txt"
	want=$(awk -v f="$2" '$2 == f { print $1 }' "$1/checksums.txt")
	[ -n "$want" ] || die "$2 is not in the release's checksums"
	if has sha256sum; then
		got=$(sha256sum "$1/$3" | awk '{ print $1 }')
	elif has shasum; then
		got=$(shasum -a 256 "$1/$3" | awk '{ print $1 }')
	else
		die "needs sha256sum or shasum to check the download"
	fi
	[ "$got" = "$want" ] || die "$2 does not match the release's checksum"
}

main() {
	upgrade=
	case $(uname -s) in
	Darwin)
		if has brew; then with_brew; else with_binary darwin; fi
		;;
	Linux)
		if has apt-get && has dpkg; then
			with_apt
		elif has dnf; then
			with_dnf dnf
		elif has zypper; then
			with_zypper
		elif has yum; then
			with_dnf yum
		elif has apk; then
			with_apk
		else
			with_binary linux
		fi
		;;
	*)
		die "this script is for Linux and macOS; for $(uname -s), see https://github.com/cirope/tlm-cli#install"
		;;
	esac

	has tlm || die "tlm was installed but is not on PATH"
	say ""
	say "Installed $(tlm --version)."
	say "Upgrade with $upgrade. Next: tlm login"
}

# Everything runs only once the whole script has arrived.
main "$@"
