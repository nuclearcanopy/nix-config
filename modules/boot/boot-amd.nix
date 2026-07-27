{ lib, ... }:

{
  # Boot config for AMD CPU hosts. amd_pstate=active is the AMD scaling driver;
  # tmpfs sizing and uvcvideo/btusb/intel_sgx blacklist are general kuraokami-flavored
  # choices that happen to live alongside. Hardening kernel params are separate.
  nixos.modules.boot-amd = {
    boot = {
      # Override the shared hardening-base ptrace_scope=2 (root-only ptrace) back
      # to 0 (classic same-uid ptrace: gdb -p / strace attach on own processes).
      # kuraokami only; nidhoggr keeps the stricter =2. mkForce beats the base.
      kernel.sysctl."kernel.yama.ptrace_scope" = lib.mkForce 0;

      loader = {
        systemd-boot.enable = true;
        timeout = 1;
        efi.canTouchEfiVariables = true;
      };

      tmp = {
        useTmpfs = true;
        tmpfsSize = "8G";
      };

      kernelParams = [
        "amd_pstate=active"
        # Suspend: s2idle keeps the RX 7900 XTX (Navi 31) out of D3cold during
        # sleep. Deep S3 forces a GPU MODE1 reset on every resume, during which
        # the DCN 3.2 display pipe intermittently fails to reprogram
        # ("REG_WAIT timeout - dcn32_program_compbuf_size"): outputs get torn
        # down/up and waybar's layer-shell surface comes back dead, needing a
        # manual restart. s2idle skips the reset+reprogram entirely. Costs a
        # couple watts more while asleep, irrelevant on an always-plugged desktop.
        "mem_sleep_default=s2idle"
      ];

      blacklistedKernelModules = [
        "uvcvideo"
        "btusb" "bluetooth"
        "intel_sgx"
      ];

      extraModprobeConfig = ''
        options snd_usb_audio use_vmalloc=1
      '';
    };
  };
}
