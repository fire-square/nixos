{ lib, config, pkgs, ... }:

with lib; {
  options.services.fs-minecraft = {
    enable = mkEnableOption "Whether to enable minecraft servers.";
  };

  config = mkIf config.services.fs-minecraft.enable {
    containers = {
      mf-db = let mysql = pkgs.unstable.mariadb_109; in
        {
          autoStart = true;
          privateNetwork = true;
          hostAddress = "10.172.72.1";
          localAddress = "10.172.72.2";
          extraFlags = [ "--bind /var/lib/mineflake/db:/var/lib/postgresql/14" ];
          ephemeral = true;
          config = { config, pkgs, ... }: {
            services.postgresql = {
              enable = true;
              enableTCPIP = true;
              authentication = ''
                host all all 10.172.72.1/24 password
              '';
              ensureUsers = [
                {
                  name = "luckperms";
                  ensurePermissions = {
                    "DATABASE luckperms" = "ALL PRIVILEGES";
                  };
                }
              ];
              ensureDatabases = [
                "luckperms"
              ];
            };
            networking.firewall.enable = false;
            system.stateVersion = "22.05";
          };
        };
    };

    age.secrets.minecraft.file = ../../secrets/minecraft.age;

    minecraft =
      let
        server-icon = pkgs.fetchurl {
          url = "https://static.ipfsqr.ru/ipfs/bafybeibjkfvmmdzkvap7c7be5r2zwuxr7dbl3r23huk5nxywnjtqem5uqq/server-icon.png";
          sha256 = "0dyxha9gmzqn1mdzvkfw0133h5wvawr1fw3s7x06r792zz6k1dr8";
        };

        common-base = {
          permissions = {
            enable = true;
            groups = {
              default = {
                permissions = [ ] ++ (map
                  (perm: {
                    permission = perm;
                    value = true;
                  }) [
                  # Chatty
                  # Allow local and global chats
                  "chatty.chat.local"
                  "chatty.chat.global"
                  # Allow /msg command
                  "chatty.command.msg"
                  # Allow use styles in messages
                  "chatty.style.italic"
                  "chatty.style.reset"
                  "chatty.style.bold"
                  "chatty.style.colors"

                  # CoreProtect
                  "coreprotect.inspect" # Allow /co i

                  # InventoryRollbackPlus
                  # Allow saves
                  "inventoryrollbackplus.deathsave"
                  "inventoryrollbackplus.joinsave"
                  "inventoryrollbackplus.leavesave"
                  "inventoryrollbackplus.worldchangesave"

                  # TabTPS
                  "tabtps.ping"
                  "tabtps.defaultdisplay"

                  # SkinsRestorer
                  "skinsrestorer.command"
                  "skinsrestorer.command.set"
                  "skinsrestorer.command.set.url"
                  "skinsrestorer.command.clear"
                  "skinsrestorer.command.update"
                ]) ++ (map
                  (perm: {
                    permission = perm;
                    value = false;
                  }) [
                  # InventoryRollbackPlus
                  "inventoryrollbackplus.version"
                  "inventoryrollbackplus.help"
                ]);
              };
              superadmin = {
                permissions = [
                  {
                    permission = "*";
                    value = true;
                  }
                  {
                    permission = "authme.bypassbungeesend";
                    value = false;
                  }
                ];
              };
            };
          };
          properties.enable = true;
          properties.online-mode = false;
          properties.spawn-protection = 0;
          secretsFile = config.age.secrets.minecraft.path;
          server-icon = server-icon;
          maxMemory = "1024M";
          CPUQuota = 10;
        };

        common-configs = {
          "plugins/LuckPerms/config.yml".data = {
            storage-method = "PostgreSQL";
            data = {
              address = "10.172.72.2";
              database = "luckperms";
              username = "luckperms";
              password = "#LUCKPERMS_DB_PASSWORD#";
            };
            split-storage.methods = {
              user = "PostgreSQL";
              track = "PostgreSQL";
              uuid = "PostgreSQL";
              log = "PostgreSQL";
            };
          };
          "spigot.yml".data = {
            settings.bungeecord = true;
          };
        };

        common-plugins = with pkgs.mineflake; [ skinsrestorer ];

        authme-whitelist = [
          "/login"
          "/register"
          "/l"
          "/reg"
          "/2fa"
        ];
      in
      {
        enable = true;

        default.hostAddress = "10.172.72.1";

        servers = {
          proxy = {
            useDefault = false;
            hostAddress = "10.172.72.1";
            localAddress = "10.172.72.3";
            forwardPorts = [ 25565 ];
            maxMemory = "512M";
            CPUQuota = 10;
            bungeecord = {
              enable = true;
              online_mode = false;
              ip_forward = true;
              listeners = [
                {
                  host = "0.0.0.0:25565";
                  priorities = [ "lobby" ];
                  force_default_server = true;
                  proxy_protocol = true;
                }
              ];
              servers = {
                lobby.address = "10.172.72.4";
                main.address = "10.172.72.5";
              };
            };
            plugins = with pkgs.mineflake; [ authmebungee skinsrestorer ];
            configs = {
              "plugins/AuthMeBungee/config.yml".data = {
                authServers = [ "lobby" ];
                allServersAreAuthServers = false;
                serverSwitch = {
                  requiresAuth = true;
                  kickMessage = "Авторизуйтесь!";
                };
                autoLogin = true;
                sendOnLogout = true;
                unloggedUserServer = "lobby";
                commands = {
                  requireAuth = true;
                  whitelist = authme-whitelist;
                };
              };
            };
            server-icon = server-icon;
            package = pkgs.mineflake.waterfall;
          };

          lobby = common-base // {
            localAddress = "10.172.72.4";
            hostdir = "/tank/mc/lobby";
            configs = common-configs // {
              "plugins/AuthMe/config.yml".data = {
                DataSource.mySQLtotpKey = "totpnew";
                settings = {
                  useWelcomeMessage = false;
                  removeJoinMessage = true;
                  removeLeaveMessage = true;
                  messagesLanguage = "ru";
                  sessions = {
                    enabled = true;
                    timeout = 60;
                  };
                  restrictions = {
                    maxRegPerIp = 6;
                    maxLoginPerIp = 3;
                    maxJoinPerIp = 3;
                    allowCommands = authme-whitelist;
                  };
                };
                Hooks = {
                  sendPlayerTo = "main";
                  bungeecord = true;
                  multiverse = false;
                };
                BackupSystem.ActivateBackup = true;
              };
              "plugins/AuthMe/messages/messages_ru.yml" = {
                type = "yaml";
                data = importJSON ./authme/messages.json;
              };
            };
            plugins = (with pkgs.mineflake; [ authme ]) ++ common-plugins;
          };

          main = common-base // {
            localAddress = "10.172.72.5";
            hostdir = "/tank/mc/main";
            maxMemory = "4096M";
            configs = common-configs // {
              "plugins/Chatty/config.yml".data = {
                general.locale = "ru";
                chats = {
                  local = {
                    format = "<{#f3e5ab}{player}&r> {message}";
                    range = 300;
                  };
                  global = {
                    format = "<{player}> {message}";
                    range = -2;
                  };
                  notify.enable = false;
                };
                pm.format = {
                  recipient = "{#baacc7}[{sender-name} > {recipient-name}] {message}";
                  sender = "{#baacc7}[{sender-name} > {recipient-name}] {message}";
                };
                notifications = {
                  chat.enable = false;
                  title.enable = false;
                };
              };
              "plugins/Chatty/locale/ru.yml" = {
                type = "yaml";
                data = importJSON ./chatty/locale.json;
              };
            };
            plugins = (with pkgs.mineflake; [ coreprotect inventoryrollbackplus chatty tabtps ]) ++ common-plugins;
          };
        };
      };

    systemd.services.mf-db-prepare = {
      requiredBy = [ "container@mf-db.service" ];
      wantedBy = [ "container@mf-db.service" ];
      script = "mkdir -p /var/lib/mineflake/db";
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
    };
  };
}