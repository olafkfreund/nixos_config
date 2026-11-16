# freund-tabs

`herdr-app do mod.clone '{"name":"tabs","as":"freund-tabs"}'` on herdr-app 0.1.16, plus herdr-gitlab's tab-bar
edit (rem-aster/herdr-gitlab `install.py`, `wire_tabs`): `enabled` gains `"gitlab"`, and a `panelButton("gitlab",
...)` follows the Changes button. On an app bump: re-clone `tabs` and re-apply those two edits.

- `render` passes `issues` and `plans` to `syncPanel` as restorable panels (they have their own buttons).
