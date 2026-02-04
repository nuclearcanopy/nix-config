{ ... }:

{
  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
      
      logo = {
        source = toString ./arceus_bw.txt;
        padding = {
          top = 1;
          bottom = 0;
          left = 2;
        };
      };

      display = {
        separator = " ";
        key = {
          width = 8;
        };
      };

      modules = [
        "break"
        "break"
        {
          type = "os";
          key = " SYS";
          keyColor = "15";
        }
        {
          type = "kernel";
          key = " KNL";
          keyColor = "15";
        }
        {
          type = "packages";
          format = "{} (nixpkgs)";
          key = " PKG";
          keyColor = "15";
        }
        {
          type = "shell";
          key = " SHL";
          keyColor = "15";
        }
        {
          type = "terminal";
          key = " TRM";
          keyColor = "15";
        }
        {
          type = "wm";
          key = " WMG";
          keyColor = "15";
        }
        {
          type = "uptime";
          key = " UPT";
          keyColor = "15";
        }
        {
          type = "gpu";
          key = "󰢮 GPU";
          keyColor = "15";
        }
        {
          type = "cpu";
          key = " CPU";
          keyColor = "15";
        }
        {
          type = "disk";
          key = "󰉉 SSD";
          folders = "/";
          keyColor = "15";
          percent = {
            type = [ "num" ];
          };
        }
      ];
    };
  };
}
