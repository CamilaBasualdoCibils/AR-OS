{ pkgs, ... }:
{
  # Streaming is sandbox infrastructure, kept independent from ARUI so the
  # boot framebuffer and future Monado frame producers can share it.
  environment.systemPackages = [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
  ];
}
