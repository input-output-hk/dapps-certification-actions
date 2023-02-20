{ name, std, lib, helperFlakeInput, nixpkgsFlake, ... }@args:
{
  inputs = {
    repo-ref = ''
      "${name}": {
        ref: string // Flake reference in URL format
        ghAccessToken?: string | null // GitHub access token for private repos
      }
    '';
  };

  output = { ... }: {
    failure.${name}.failure = true;
  };
  job = { repo-ref }: std.chain args [
    (std.escapeNames [ ] [ ])

    std.singleTask

    {
      config.packages = std.data-merge.append [
        "${nixpkgsFlake}#gnutar"
        "${nixpkgsFlake}#gzip"
        "${nixpkgsFlake}#bash"
        (helperFlakeInput "generate-flake")
      ];

      config.console = "pipe";
    }

    std.postFact

    std.nix.install

    (std.script "bash" ''
      set -eEuo pipefail

      gh_access_token_arg=${
        if repo-ref.value.${name}.ghAccessToken != null
        then "'--gh-access-token ${lib.escapeShellArg repo-ref.value.${name}.ghAccessToken}'"
        else ""}

      generate-flake ${lib.escapeShellArg repo-ref.value.${name}.ref} flake $gh_access_token_arg
      tar czf /local/cicero/post-fact/success/artifact flake
      echo ${lib.escapeShellArg (builtins.toJSON {
        ${name} = {
          success = true;
          ghAccessToken = repo-ref.value.${name}.ghAccessToken;
        };
      })} > /local/cicero/post-fact/success/fact
    '')
  ];
}
