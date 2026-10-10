{ ... }:

{
  environment.etc = {
    # ADR 025 (homeserver-nix): two trusted x86_64-linux remote builders so the
    # root nix-daemon builds VM closures straight into the host store (no manual
    # `nix copy`, no per-build sudo). The daemon runs as root, so these aliases
    # must be system-wide (`/etc/ssh/ssh_config.d/*`); root does not read the
    # user's ~/.ssh/config.
    #   - homeserver-builder: native, warm store, preferred (speed-factor 1)
    #   - colima: local fallback (speed-factor 3)
    # colima's SSH port is pinned to 2220 (`colima start --ssh-port 2220`,
    # persisted in ~/.colima/default/colima.yaml) so the entry stays static.
    # Hardening TODO: pin the homeserver host key via base64-ssh-public-host-key
    # (public half lives in the homeserver-nix repo at
    # extra-files/etc/ssh/ssh_host_ed25519_key.pub) instead of
    # StrictHostKeyChecking no.
    "ssh/ssh_config.d/remote-builders.conf".text = ''
      Host homeserver-builder
        HostName homeserver.home
        User root
        IdentityFile /Users/matthias/projects/personal/homeserver-nix/keys/id_proliant_nas
        IdentitiesOnly yes
        BatchMode yes
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        ControlMaster no

      Host colima
        HostName 127.0.0.1
        Port 2220
        User matthias
        IdentityFile /Users/matthias/.colima/_lima/_config/user
        IdentitiesOnly yes
        PreferredAuthentications publickey
        BatchMode yes
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        ControlMaster no
    '';
    # machines-file format: <store> <system> <ssh-key> <max-jobs> <speed-factor> <features>
    # Both `nix-daemon`s are not on the non-interactive SSH PATH, so each URL
    # names it explicitly via remote-program. max-jobs 4 keeps build load on the
    # production homeserver bounded (12 cores); speed-factor makes Nix prefer it.
    "nix/machines".text = ''
      ssh-ng://root@homeserver-builder?remote-program=/run/current-system/sw/bin/nix-daemon x86_64-linux /Users/matthias/projects/personal/homeserver-nix/keys/id_proliant_nas 4 1 big-parallel,benchmark
      ssh-ng://matthias@colima?remote-program=/home/matthias.guest/.nix-profile/bin/nix-daemon x86_64-linux /Users/matthias/.colima/_lima/_config/user 4 3 big-parallel,benchmark
    '';
  };
}
