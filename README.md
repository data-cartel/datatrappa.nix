# Data Trappa Cluster Starter

Nix Flake to Spark up with Kafka

## Pre-requisites

Nix is a tool for reproducible declarative builds and deployments. Direnv is an extension for your shell for automatically loading and unloading environment settings when you enter or leave certain directories. Set up these two bad boys and all the other dependencies will be automagically become available to you every time you `cd` into the project.

1. Install Nix using the [Determinate Nix installer](https://github.com/DeterminateSystems/nix-installer) `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
2. Install direnv `nix -v profile install nixpkgs#direnv`
3. Configure [direnv shell hook](https://github.com/direnv/direnv/blob/master/docs/hook.md)
4. Run `direnv allow` inside of the directory with the cloned repo to install all the tools (first run will take a while)
