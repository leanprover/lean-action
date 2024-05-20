import Lake
open Lake DSL

package «standalone» where
  -- add package configuration options here

lean_lib «Standalone» where
  -- add library configuration options here

@[default_target]
lean_exe «standalone» where
  root := `Main
