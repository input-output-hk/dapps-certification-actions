{ name, std, lib, nixpkgsFlake, ... }@args:
{
  inputs = {
    certify-path = ''
      "plutus-certification/build-flake": success: string // Nix store path
    '';
  };

  outputs = { ... }: {
    failure.${name}.failure = true;
  };

  job = { certify-path }: std.chain args [
    (std.escapeNames [ ] [ ])

    # postFact needs network access, but would be nice if we could
    # do this for the main task. Perhaps with some nspawn settings?
    # { ${name}.group.${name}.network.mode = "none"; }

    std.singleTask

    { resources.memory = 1024 * 8; }

    {
      config.packages = std.data-merge.append [
        certify-path.value."plutus-certification/build-flake".success
        "${nixpkgsFlake}#util-linux"
      ];
    }

    std.postFact

    (std.script "bash" ''
      set -eEuo pipefail

      unshare --net --setuid=65534 --setgid=65534 certify 3> out.json
      jq '{ ${builtins.toJSON name}: { success: . } }' < out.json > /local/cicero/post-fact/success/fact
    '')
  ];
}
