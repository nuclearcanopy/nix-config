{ ... }:
{
  home.file.".config/vkBasalt.conf".text = ''
    effects = smaa:cas
    smaaQuality = ultra
    casSharpness = 0.4
    reshadeTexturePath = /run/current-system/sw/share/vkBasalt/textures
    reshadeIncludePath = /run/current-system/sw/share/vkBasalt/shaders
  '';
}
