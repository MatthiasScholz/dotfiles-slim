# Shared helpers for the repo's managed LaunchAgents and LaunchDaemons.
#
# Every managed service here repeats two things:
#
#   1. the plist shape — RunAtLoad, KeepAlive, ProcessType, log paths, and the
#      activation that creates the log directory before launchd opens the logs;
#   2. a wrapper that waits (bounded) for agenix to decrypt secret files before
#      exec'ing the program — the files can briefly be missing/dangling at login.
#
# This module owns both, so the start-order race and the plist shape live in one
# place instead of once per daemon. Only the secret file *paths* reach the Nix
# store, never the values.
{ lib, pkgs }:

let
  # A single secret the wrapper must apply before starting. `kind`:
  #   "env"    -> export VAR="$(cat FILE)"   (FILE holds a raw secret value)
  #   "source" -> . FILE                     (FILE holds a shell line, e.g. `export NAME=…`)
  secretStep =
    { kind, file, var ? null }:
    let
      path = lib.escapeShellArg (toString file);
    in
    if kind == "env" then
      assert lib.assertMsg (var != null) "launchd: secret kind \"env\" needs a `var`";
      ''
        wait_for ${path}
        ${var}="$(cat ${path})"
        export ${var}
      ''
    else if kind == "source" then
      ''
        wait_for ${path}
        . ${path}
      ''
    else
      throw "launchd: unknown secret kind '${kind}'";

  # Bounded wait so a service does not start before agenix has decrypted its
  # secret. `wait_for <path>` is a no-op when the file is already readable.
  waitPreamble = waitSeconds: ''
    wait_for() {
      i=0
      while [ ! -r "$1" ] && [ "$i" -lt ${toString waitSeconds} ]; do
        sleep 1
        i=$((i + 1))
      done
    }
  '';
in
rec {
  # Wrap `command` so the given secrets are waited for and applied before it
  # runs. Returns a store path to the wrapper script.
  mkSecretWrapper =
    {
      name,
      command,
      secrets,
      waitSeconds ? 60,
    }:
    pkgs.writeShellScript "${name}-launchd" ''
      ${waitPreamble waitSeconds}
      ${lib.concatMapStrings secretStep secrets}
      exec ${lib.escapeShellArgs command}
    '';

  # A sourceable file that waits for the given secrets and applies them — for
  # Home Manager's `environmentFile`, whose launchd wrapper `source`s the file.
  # Returns a store path.
  mkSecretEnvFile =
    {
      name,
      secrets,
      waitSeconds ? 60,
    }:
    pkgs.writeShellScript "${name}-env" ''
      ${waitPreamble waitSeconds}
      ${lib.concatMapStrings secretStep secrets}
    '';

  # The complete plist for a repo-managed background service, plus a log-dir
  # activation command. Callers wire the pieces into their module system
  # (Home Manager `launchd.agents` or nix-darwin `launchd.daemons`); anything
  # that genuinely varies goes in `extraConfig`.
  mkServiceConfig =
    {
      name,
      command,
      logDir,
      logName ? name,
      secrets ? [ ],
      waitSeconds ? 60,
      description ? null,
      workingDirectory ? null,
      environment ? { },
      extraConfig ? { },
    }:
    let
      programArguments =
        if secrets == [ ] then
          command
        else
          # `toString` because the plist option type is `listOf string`; a raw
          # derivation would fail the option merge.
          [ (toString (mkSecretWrapper { inherit name command secrets waitSeconds; })) ];
    in
    {
      inherit programArguments;
      config = {
        ProgramArguments = programArguments;
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = "${logDir}/${logName}.log";
        StandardErrorPath = "${logDir}/${logName}.err.log";
      }
      // lib.optionalAttrs (description != null) { ServiceDescription = description; }
      // lib.optionalAttrs (workingDirectory != null) { WorkingDirectory = workingDirectory; }
      // lib.optionalAttrs (environment != { }) { EnvironmentVariables = environment; }
      // extraConfig;
      # Wrap in an activation script (e.g. `lib.hm.dag.entryAfter`); launchd
      # opens the log files before the process starts.
      logDirActivation = "mkdir -p ${lib.escapeShellArg logDir}";
    };
}
