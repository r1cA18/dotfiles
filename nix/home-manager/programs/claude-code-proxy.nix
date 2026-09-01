{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  proxy = inputs.claude-code-proxy.packages.${pkgs.stdenv.hostPlatform.system}.default;
  proxyBin = lib.getExe proxy;
  serviceName = "claude-code-proxy";
  launchdLabel = "com.r1ca18.${serviceName}";
  healthUrl = "http://127.0.0.1:18765/healthz";
  stateDir = "${config.home.homeDirectory}/.local/state/${serviceName}";

  proxyService = pkgs.writeShellApplication {
    name = "claude-code-proxy-service";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      install -d -m 700 "${stateDir}"
      export CCP_BIND_ADDRESS="127.0.0.1"
      export PORT="18765"
      exec ${proxyBin} serve --no-monitor
    '';
  };

  clproxy = pkgs.writeShellApplication {
    name = "clproxy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];
    text = ''
      health_url=${lib.escapeShellArg healthUrl}
      launchd_label=${lib.escapeShellArg launchdLabel}
      service_name=${lib.escapeShellArg serviceName}
      log_file="${stateDir}/service.log"
      export CCP_BIND_ADDRESS="127.0.0.1"
      export PORT="18765"

      is_healthy() {
        local response
        response="$(curl -fsS --connect-timeout 1 --max-time 2 "$health_url" 2>/dev/null)" || return 1
        [[ "$response" == *'"ok":true'* ]]
      }

      wait_for_health() {
        local attempt
        for ((attempt = 0; attempt < 100; attempt++)); do
          if is_healthy; then
            return 0
          fi
          sleep 0.1
        done
        return 1
      }

      start_service() {
        if is_healthy; then
          echo "claude-code-proxy is already running at $health_url"
          return 0
        fi

        case "$(uname -s)" in
          Darwin)
            local target="gui/$UID/$launchd_label"
            if ! /bin/launchctl print "$target" >/dev/null 2>&1; then
              echo "LaunchAgent is not loaded. Apply the Home Manager configuration first." >&2
              return 1
            fi
            /bin/launchctl kickstart -k "$target"
            ;;
          Linux)
            systemctl --user restart "$service_name.service"
            ;;
          *)
            echo "Unsupported platform. Use: clproxy foreground" >&2
            return 1
            ;;
        esac

        if ! wait_for_health; then
          echo "claude-code-proxy did not become ready. Check: clproxy logs" >&2
          return 1
        fi
        echo "claude-code-proxy is ready at $health_url"
      }

      stop_service() {
        case "$(uname -s)" in
          Darwin)
            local target="gui/$UID/$launchd_label"
            if ! /bin/launchctl print "$target" >/dev/null 2>&1; then
              echo "claude-code-proxy LaunchAgent is not loaded"
              return 0
            fi
            if ! /bin/launchctl kill SIGTERM "$target" 2>/dev/null; then
              echo "claude-code-proxy is not running"
              return 0
            fi
            ;;
          Linux)
            if ! systemctl --user is-active --quiet "$service_name.service"; then
              echo "claude-code-proxy is not running"
              return 0
            fi
            systemctl --user stop "$service_name.service"
            ;;
          *)
            echo "Unsupported platform" >&2
            return 1
            ;;
        esac

        local attempt
        for ((attempt = 0; attempt < 50; attempt++)); do
          if ! is_healthy; then
            echo "claude-code-proxy stopped"
            return 0
          fi
          sleep 0.1
        done
        echo "claude-code-proxy did not stop cleanly" >&2
        return 1
      }

      show_status() {
        ${proxyBin} --version
        if is_healthy; then
          echo "Service: running at $health_url"
        else
          echo "Service: stopped"
        fi

        if ${proxyBin} codex auth status; then
          return 0
        fi
        return 1
      }

      usage() {
        cat <<'EOF'
      Usage: clproxy <command>

      Commands:
        foreground       Run the proxy with its monitor in this terminal
        start            Start the on-demand user service
        stop             Stop the user service
        status           Show service and Codex authentication status
        models [--full]  Show the current model catalog
        auth <action>    Run Codex auth login, device, status, or logout
        logs             Follow the background service log
        version          Show the proxy version
      EOF
      }

      command="''${1:-}"
      if [[ $# -gt 0 ]]; then
        shift
      fi

      case "$command" in
        foreground)
          if is_healthy; then
            echo "claude-code-proxy is already running. Stop it with: clproxy stop" >&2
            exit 1
          fi
          exec ${proxyBin} serve "$@"
          ;;
        start)
          start_service
          ;;
        stop)
          stop_service
          ;;
        status)
          show_status
          ;;
        models)
          exec ${proxyBin} models "$@"
          ;;
        auth)
          exec ${proxyBin} codex auth "$@"
          ;;
        logs)
          install -d -m 700 "${stateDir}"
          touch "$log_file"
          exec tail -n 100 -f "$log_file"
          ;;
        version)
          exec ${proxyBin} --version
          ;;
        help|-h|--help|"")
          usage
          ;;
        *)
          echo "Unknown command: $command" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
  };

  clgpt = pkgs.writeShellApplication {
    name = "clgpt";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      health_url=${lib.escapeShellArg healthUrl}
      claude_bin="$HOME/.local/bin/claude"

      if [[ ! -x "$claude_bin" ]]; then
        echo "Claude Code was not found at $claude_bin" >&2
        exit 1
      fi

      if ! ${proxyBin} codex auth status >/dev/null; then
        echo "Codex authentication is required. Run: clproxy auth login" >&2
        exit 1
      fi

      health_response="$(curl -fsS --connect-timeout 1 --max-time 2 "$health_url" 2>/dev/null || true)"
      if [[ "$health_response" != *'"ok":true'* ]]; then
        ${lib.getExe clproxy} start
      fi

      export ANTHROPIC_BASE_URL="http://127.0.0.1:18765"
      export ANTHROPIC_AUTH_TOKEN="unused"
      export ANTHROPIC_MODEL="''${CLGPT_MODEL:-gpt-5.6-sol[1m]}"
      export ANTHROPIC_SMALL_FAST_MODEL="''${CLGPT_FAST_MODEL:-gpt-5.6-luna[1m]}"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="272000"
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
      export CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK="1"

      exec "$claude_bin" "$@"
    '';
  };
in
{
  home = {
    packages = [
      proxy
      clproxy
      clgpt
    ];

    activation.prepareClaudeCodeProxyState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/install -d -m 700 "$HOME/.local/state/${serviceName}"
    '';
  };

  launchd.agents.${serviceName} = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = launchdLabel;
      ProgramArguments = [ (lib.getExe proxyService) ];
      ProcessType = "Background";
      RunAtLoad = false;
      StandardErrorPath = "${stateDir}/service.log";
      StandardOutPath = "${stateDir}/service.log";
    };
  };

  systemd.user.services.${serviceName} = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Claude Code protocol proxy for ChatGPT/Codex";
    Service = {
      ExecStart = lib.getExe proxyService;
      Restart = "on-failure";
      RestartSec = 2;
      StandardError = "append:%h/.local/state/${serviceName}/service.log";
      StandardOutput = "append:%h/.local/state/${serviceName}/service.log";
    };
  };
}
