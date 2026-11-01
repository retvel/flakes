# systemd sandboxing every service module here applies (serviceConfig): no
# privilege gain through setuid, and the clock, kernel logs, cgroups and
# personality protected. It leaves the filesystem, network, devices and kernel
# tunables alone; each module adds what its service can live without.
{
  NoNewPrivileges = true;
  RestrictSUIDSGID = true;
  LockPersonality = true;
  RestrictRealtime = true;
  ProtectClock = true;
  ProtectKernelLogs = true;
  ProtectControlGroups = true;
}
