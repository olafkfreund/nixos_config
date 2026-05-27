# Hardware Profiles

## The problem

GPU support is the messiest part of any Linux host config: drivers, kernel
modules, acceleration stacks, user groups, and environment variables all have to
agree. Three hosts with three different GPU vendors should not each reinvent
this.

## The solution

GPU stacks are abstracted into reusable **hardware profiles** under
`hosts/common/hardware-profiles/`:

| Profile | File | Used by |
| --- | --- | --- |
| AMD | `amd-gpu.nix` | p620 (Radeon RX 7900, ROCm) |
| NVIDIA | `nvidia-gpu.nix` | p510, razer |
| Intel integrated | `intel-integrated.nix` | hybrid-graphics hosts |

A host's `variables.nix` imports the right profile and inherits its `gpu`,
`acceleration`, `videoDrivers`, extra user groups, and environment variables:

```nix
# hosts/p620/variables.nix
hardwareProfile = import ../common/hardware-profiles/amd-gpu.nix;
# …
gpu          = hardwareProfile.gpu;
acceleration = hardwareProfile.acceleration;
userGroups   = baseUserGroups ++ (hardwareProfile.extraGroups or [ ]);
```

## Why this matters per host

### p620 (AMD)

Radeon RX 7900 with the `amdgpu` driver and **ROCm** acceleration — this is what
makes p620 viable as the local Ollama inference host. The profile adds the
`render`/`video` groups and the ROCm environment so the GPU is usable from
containers and CLI tools.

### p510 (NVIDIA)

Intel Xeon paired with an NVIDIA card. The profile pulls in the proprietary
driver and the bits needed for **hardware transcoding** in Plex.

### razer (NVIDIA + Intel)

Hybrid Optimus graphics: the Intel iGPU drives the panel for battery life, the
NVIDIA dGPU is available on demand. The profile handles the dual-driver setup;
the laptop profile adds power management on top.

## Source

The exact contents of each profile — driver lists, groups, env vars — are in
the generated [Host Manifests](../reference/hosts/index.md) under
`hosts/common/`.
