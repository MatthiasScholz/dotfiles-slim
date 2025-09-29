# Dotfiles

This is to describe the bare-bones development system I use. Supports Intel and Silicon Macs.

## Tasks

- [x] Add default browser
- [x] Support neo2 keyboard layout
- [x] Add ~/bin into PATH - used by direnv: tfswitch
- [x] Deal with project specific communication tooling: mattermost, ms-teams, zoom
- [x] Unfree: Beeper, logseq, draw.io, notion, notion-calendar, spotify
- [x] Decide for shell fish or zsh -> zsh
- [x] Add opt/homebrew/bin/ to PATH
- [ ] Support touchid for cli
- [ ] gossm need file '/Users/matthias/.aws/credentials_temporary'
- [ ] Configure Terraform Provider Cache environment variable
- [ ] Add Docker and colima
- [ ] Add statusbar
- [ ] Add doomemcs configuration, dotenc, ispell
- [ ] raycast plugins
- [ ] logseq plugins
- [ ] restish configuration
- [ ] import old (before fleek) starship configuration
- [ ] Support for installing [Insta360 Link Software](https://www.insta360.com/de/download/insta360-link)
- [x] Support installing none packaged applications via `go install -> e.g. check templates -> k8s`

## Install Nix

On OSX: [Determinate Systems Installer](https://github.com/DeterminateSystems/nix-installer).


### Upgrades

The nix service itself is not managed by nix-darwin and needs to be upgrade independently (manually?).

``` sh
sudo determinate-nixd upgrade
```

### Binary Caches

For `devenv` binary cache support add the cache manually because nix-darwin is not managing the nix installer

```sh
# /private/etc/nix/nix.custom.conf
extra-substituters = https://devenv.cachix.org
extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=
```

## Bootstrap

### Darwin/Linux

`nix run nix-darwin -- switch --flake github:matthiasscholz/dotfiles-slim`

## Update

### Darwin

`rebuild`

### Github Access

In order to avoid rate limiting by the Github API when pulling changes
a Github Access Token is used. It is stored in `~/.config/nix/nix.conf`
using `access-token = github.com=<github_personal_access_token_name_nix>`.

### Troubleshoot

#### Extract Installation Path

Use to configure MacOSX permissions.

``` sh
# Example: getting zoom installation path
nix eval nixpkgs#zoom-us.outPath --impure
```


## References

- [source](https://github.com/evantravers/dotfiles)
- [nix-darwin references, high amount of modules and Neo2](https://github.com/Cu3PO42/gleaming-glacier/tree/master)
- [example configuration: PATH, doomemcs][https://gist.github.com/bsag/552a68a198df04ddbc9ddb7b16b170bf]
- [tutorial setting up nix on mac](https://blog.dbalan.in/blog/2024/03/25/boostrap-a-macos-machine-with-nix/index.html)
- [fix: profile.lock: no such file or directory](https://github.com/nix-community/home-manager/issues/3734)
