---
description: Ask Google Gemini (agy) to perform a principal architectural review of the current NixOS implementation plan.
allowed-tools: Bash(*)
---
# Requesting Gemini Architectural Review

Please execute the local `agy` tool to review the current implementation plan.

Run this bash command:
!agy "You are a Principal NixOS Architect. Review the following implementation plan and highlight any potential Nix architecture errors, package conflicts, or system-level edge cases. Be extremely critical: $(cat implementation_plan.md)"

## Next Steps
1. Display Gemini's feedback and warnings.
2. Suggest actionable improvements to the implementation plan based on Gemini's architectural review.
