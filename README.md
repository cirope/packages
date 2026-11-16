# Hullop packages

Hullop's apt and dnf repositories, so your system's usual upgrade keeps
our tools up to date. Today they serve [Trk](https://github.com/cirope/trk-cli)'s
command-line client, `trk`, for amd64 and arm64.

## Debian, Ubuntu and derivatives

```sh
curl -fsSL https://cirope.github.io/packages/hullop.gpg | sudo tee /usr/share/keyrings/hullop.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hullop.gpg] https://cirope.github.io/packages/apt stable main" | sudo tee /etc/apt/sources.list.d/hullop.list
sudo apt update && sudo apt install trk
```

`sudo apt update && sudo apt upgrade` brings each new release.

## Fedora, RHEL, CentOS Stream

```sh
sudo curl -fsSLo /etc/yum.repos.d/hullop.repo https://cirope.github.io/packages/rpm/hullop.repo
sudo dnf install trk
```

`sudo dnf upgrade` brings each new release. On openSUSE, add the same file
with `sudo zypper addrepo https://cirope.github.io/packages/rpm/hullop.repo`
and `sudo zypper install trk`.

## How it works

Every package and the repository metadata are signed with Hullop's key
(`hullop.asc`, `hullop.gpg`). When trk-cli publishes a release, its
workflow starts [publish](.github/workflows/publish.yml), which downloads
the release's packages, builds the repositories with
[scripts/build.sh](scripts/build.sh) and deploys them to GitHub Pages.
Only the newest release is served.

[scripts/test.sh](scripts/test.sh) (Docker and `gh`) builds them with a
throwaway key and installs trk from them with apt and dnf; the
[check](.github/workflows/check.yml) workflow runs it on every push.
