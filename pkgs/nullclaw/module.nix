_self:
{ lib, ... }:

# The system service moved to homeManagerModules.nullclaw: upstream's
# `nullclaw service install` runs the gateway as a user service, and so does
# the module now. This stub only explains the move to configs that still set
# services.nullclaw.
{
  imports = [
    (lib.mkRemovedOptionModule [ "services" "nullclaw" ] ''
      NullClaw's gateway is now a user service, like upstream's
      `nullclaw service install`: import inputs.retvel.homeManagerModules.nullclaw
      in the user's Home Manager config and set services.nullclaw there (no
      `user` option). On NixOS, set users.users.<user>.linger = true to start
      it at boot without a login.
    '')
  ];
}
