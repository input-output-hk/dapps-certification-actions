{ name, std, nixpkgsFlake, lib, ... }@args: {
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
    (std.escapeNames [] [])

    std.singleTask

    {
      resources.memory = 1024;
      config.packages = std.data-merge.append [ "${nixpkgsFlake}#nomad" "${nixpkgsFlake}#bind" ];
    }

    (std.wrapScript "bash" (inner: ''
      export CICERO_API_URL="http://cicero.service.consul:$(dig +short cicero.service.consul SRV | cut -d ' ' -f 3)"
      ${lib.escapeShellArgs inner}
    ''))

    std.postFact

    (std.script "bash" ''
      echo ${lib.escapeShellArg (builtins.toJSON { ${name}.failed = true; })} > /local/cicero/post-fact/failure/fact
      (
      echo ${lib.escapeShellArg (builtins.toJSON spec)} > job.json
      cat job.json
      nomad run job.json
      ) 2>&1 | tee /local/cicero/post-fact/failure/artifact
    '')
  ];
}
