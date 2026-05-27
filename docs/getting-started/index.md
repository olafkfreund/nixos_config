# Getting Started

New to this repository? Start here.

<div class="grid cards" markdown>

- :material-map: __[Overview](overview.md)__

    ---

    What this configuration is, the design goals, and how the pieces fit
    together at a glance.

- :material-rocket-launch: __[Quick Start](quick-start.md)__

    ---

    Clone, validate, build, and deploy — the commands you will use every day.

- :material-folder-tree: __[Repository Layout](repository-layout.md)__

    ---

    A guided tour of every top-level directory and what belongs where.

</div>

## Mental model in one minute

- __One flake__ (`flake.nix`) defines all three hosts and the dev/CI outputs.
- __One host template__ (`hosts/templates/desktop.nix`) is parameterised by a
  `profile` (`workstation` or `laptop`) and imports the whole module tree.
- __Feature flags__ (`features.*`) turn capabilities on per host instead of
  duplicating service config.
- __Home Manager__ runs as a flake module — user environments are activated by
  the system rebuild, never by a separate `home-manager switch`.
- __Stylix__ drives every colour from a single base16 palette.
- __agenix__ keeps secrets encrypted in git and loads them at runtime.

If you remember nothing else: __hosts are thin, modules are reusable, and
features are the dials you turn.__
