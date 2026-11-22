# Hullop packages

Install Hullop's command-line clients on Linux, and get every new release
with your usual system upgrade. For amd64 and arm64.

- `trk`, for [Trk](https://github.com/cirope/trk-cli)
- `tlm`, for [Tlm](https://github.com/cirope/tlm-cli)

```sh
curl -fsSL https://packages.hullop.com/trk/install.sh | sh
curl -fsSL https://packages.hullop.com/tlm/install.sh | sh
```

Each script adds the repository below that fits your distribution and
installs its client from it. On Alpine and other distributions it installs the
package or the binary from the latest release, checked against its
checksums; on macOS it uses Homebrew. To set things up by hand instead:

## Debian, Ubuntu and derivatives

```sh
curl -fsSL https://packages.hullop.com/hullop.gpg | sudo tee /usr/share/keyrings/hullop.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hullop.gpg] https://packages.hullop.com/apt stable main" | sudo tee /etc/apt/sources.list.d/hullop.list
sudo apt update && sudo apt install trk tlm   # either or both
```

Upgrade with `sudo apt update && sudo apt upgrade`.

## Fedora, RHEL, CentOS Stream

```sh
sudo curl -fsSLo /etc/yum.repos.d/hullop.repo https://packages.hullop.com/rpm/hullop.repo
sudo dnf install trk tlm
```

Upgrade with `sudo dnf upgrade`.

## openSUSE

```sh
sudo zypper addrepo https://packages.hullop.com/rpm/hullop.repo
sudo zypper install trk tlm
```

Upgrade with `sudo zypper update`.

## Uninstall

Remove the packages (`sudo apt remove trk tlm`, `sudo dnf remove trk tlm`
or `sudo zypper remove trk tlm`), and the repository with them:

```sh
# Debian, Ubuntu
sudo rm /etc/apt/sources.list.d/hullop.list /usr/share/keyrings/hullop.gpg

# Fedora, RHEL, CentOS Stream
sudo rm /etc/yum.repos.d/hullop.repo

# openSUSE
sudo zypper removerepo hullop
```

Packages and repositories are signed with Hullop's key, fingerprint
`E2F1 BC77 A550 7DB7 5EFD F801 071E 1CE9 44FA B450`.
