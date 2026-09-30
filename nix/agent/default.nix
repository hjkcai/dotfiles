{
  lib,
  ...
}:
let
  agentsMd = ./AGENTS.md;
  skillRoot = ./skills;
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillRoot)
  );

  # One store symlink per skill, so unmanaged directories next to them stay put.
  linkSkills = prefix:
    lib.listToAttrs (
      map (name: {
        name = "${prefix}/${name}";
        value = {
          source = skillRoot + "/${name}";
        };
      }) skillNames
    );
in
{
  home.file = {
    ".cursor/AGENTS.md".source = agentsMd;
  } // linkSkills ".cursor/skills";

  xdg.configFile = {
    "opencode/AGENTS.md".source = agentsMd;
  } // linkSkills "opencode/skills";
}
