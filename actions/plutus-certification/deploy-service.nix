{ name, std, actionLib, nixpkgsFlake, lib, ... }@args: {
  inputs.start = ''
    "dapps-certification/ci": start: {
      clone_url: string
      ref: string
      sha: string
    }
  '';

  job = { start }: let
    cfg = start.value."dapps-certification/ci".start;

    spec.job.dapps-certification = {
      type = "service";
      datacenters = [
        "dc1"
        "eu-central-1"
        "us-east-2"
      ];
      namespace = "marlowe";
      group.dapps-certification = {
        network = {
          mode = "host";
          port.http = {};
        };
        task.dapps-certification = {
          driver = "nix";

          resources = {
            memory = 2048;
            cpu = 300;
          };

          config = {
            packages = [
              "git+${cfg.clone_url}?ref=${cfg.ref}&rev=${cfg.sha}#plutus-certification:exe:plutus-certification"
            ];

            command = [ "/bin/bash" "local/run.bash" ];
          };

          template = {
            data = ''
              set -eEuo pipefail

              {| service cicero |}
              exec plutus-certification --port $NOMAD_PORT_http --bind $NOMAD_IP_http --cicero-url {| .Address |}:{| .Port |}
              '';
              # Workaround bug in std.script looking for template vars in the script body
              left_delimiter = "{|";
              right_delimiter = "|}";
            destination = "local/run.bash";
          };
        };
      };
    };
  in std.chain args [
    (name: prev: prev // { ${name} = prev.${name} // { namespace = "marlowe"; }; })

    actionLib.simpleJob

    {
      config.packages = std.data-merge.append [ "${nixpkgsFlake}#nomad" ];
    }

    (std.script "bash" ''
      echo ${lib.escapeShellArg (builtins.toJSON spec)} > job.json
      nomad run job.json
    '')
  ];
}
