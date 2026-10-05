{ pkgs, lib, ... }:
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    xdg.configFile."aerospace/aerospace.toml".text = ''
      config-version = 2
      start-at-login = true
      auto-reload-config = true

      # 今回使うworkspaceだけを維持
      persistent-workspaces = ["1", "2", "3", "4", "5"]

      on-focused-monitor-changed = []
      focus-follows-mouse.enabled = false

      [workspace-to-monitor-force-assignment]
      # BenQ GW2780 (左/メイン)
      1 = ['^BenQ GW2780$', 'main']
      3 = ['^BenQ GW2780$', 'main']
      5 = ['^BenQ GW2780$', 'main']

      # Pixio PX277P (右/サブ)
      2 = ['^Pixio PX277P$', 'main']
      4 = ['^Pixio PX277P$', 'main']

      [mode.main.binding]
      # Workspace切り替え（ZMK Window層 右手上段）
      alt-1 = "workspace 1"
      alt-2 = "workspace 2"
      alt-3 = "workspace 3"
      alt-4 = "workspace 4"
      alt-5 = "workspace 5"

      # フォーカス中のwindowをworkspaceへ移動してfocusも追従（ZMK Window層 右手下段）
      alt-shift-1 = "move-node-to-workspace --focus-follows-window 1"
      alt-shift-2 = "move-node-to-workspace --focus-follows-window 2"
      alt-shift-3 = "move-node-to-workspace --focus-follows-window 3"
      alt-shift-4 = "move-node-to-workspace --focus-follows-window 4"
      alt-shift-5 = "move-node-to-workspace --focus-follows-window 5"

      # Focus移動
      alt-h = "focus left"
      alt-j = "focus down"
      alt-k = "focus up"
      alt-l = "focus right"

      # Window移動
      alt-shift-h = "move left"
      alt-shift-j = "move down"
      alt-shift-k = "move up"
      alt-shift-l = "move right"

      # Window状態
      alt-f = "fullscreen"
      alt-shift-f = "macos-native-fullscreen"
      alt-space = "layout floating tiling"

      # Monitor間のfocus
      alt-comma = "focus-monitor --wrap-around prev"
      alt-period = "focus-monitor --wrap-around next"

      # Workspaceを別monitorへ移動
      alt-shift-comma = "move-workspace-to-monitor --wrap-around prev"
      alt-shift-period = "move-workspace-to-monitor --wrap-around next"

      # Workspace履歴
      alt-tab = "workspace-back-and-forth"

      # Service mode
      alt-shift-semicolon = "mode service"

      [mode.service.binding]
      esc = "mode main"
      alt-shift-semicolon = "mode main"
      r = ["reload-config", "mode main"]
      f = ["layout floating tiling", "mode main"]
      backspace = ["close", "mode main"]

      # アプリを起動時にworkspaceへ割り当て
      [[on-window-detected]]
      if.app-id = "com.stablyai.orca"
      run = "move-node-to-workspace 1"

      [[on-window-detected]]
      if.app-id = "company.thebrowser.Browser"
      run = "move-node-to-workspace 2"

      [[on-window-detected]]
      if.app-id = "com.openai.chat"
      run = "move-node-to-workspace 4"

      [[on-window-detected]]
      if.app-id = "com.hnc.Discord"
      run = "move-node-to-workspace 4"

      # すべてのアプリを強制 tiling
      [[on-window-detected]]
      if.app-id-regex = ".*"
      run = "layout tiling"
    '';
  };
}
