{ pkgs, lib, ... }:
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    xdg.configFile."aerospace/aerospace.toml".text = ''
      config-version = 2
      start-at-login = true
      auto-reload-config = true

      # ZMK Window層で操作できる1-10を維持
      persistent-workspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

      on-focused-monitor-changed = []
      focus-follows-mouse.enabled = false

      # monitor名に依存せずmain/secondaryで割り当てる
      # 1台だけの場合はすべてmainに載る
      [workspace-to-monitor-force-assignment]
      1 = 'main'
      2 = 'main'
      3 = 'main'
      4 = 'main'
      5 = 'main'
      6 = ['secondary', 'main']
      7 = ['secondary', 'main']
      8 = ['secondary', 'main']
      9 = ['secondary', 'main']
      10 = ['secondary', 'main']

      [mode.main.binding]
      # Workspace切り替え（ZMK Window層 右手上段=1-5 左手上段=6-10）
      alt-1 = "workspace 1"
      alt-2 = "workspace 2"
      alt-3 = "workspace 3"
      alt-4 = "workspace 4"
      alt-5 = "workspace 5"
      alt-6 = "workspace 6"
      alt-7 = "workspace 7"
      alt-8 = "workspace 8"
      alt-9 = "workspace 9"
      alt-0 = "workspace 10"

      # フォーカス中のwindowをworkspaceへ移動してfocusも追従（ZMK Window層 +右親指Shift）
      alt-shift-1 = "move-node-to-workspace --focus-follows-window 1"
      alt-shift-2 = "move-node-to-workspace --focus-follows-window 2"
      alt-shift-3 = "move-node-to-workspace --focus-follows-window 3"
      alt-shift-4 = "move-node-to-workspace --focus-follows-window 4"
      alt-shift-5 = "move-node-to-workspace --focus-follows-window 5"
      alt-shift-6 = "move-node-to-workspace --focus-follows-window 6"
      alt-shift-7 = "move-node-to-workspace --focus-follows-window 7"
      alt-shift-8 = "move-node-to-workspace --focus-follows-window 8"
      alt-shift-9 = "move-node-to-workspace --focus-follows-window 9"
      alt-shift-0 = "move-node-to-workspace --focus-follows-window 10"

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

      # Windowを別monitorへ移動してfocusも追従
      # workspaceはmonitorへ固定しているのでworkspace単位では動かさない
      alt-shift-comma = "move-node-to-monitor --focus-follows-window --wrap-around prev"
      alt-shift-period = "move-node-to-monitor --focus-follows-window --wrap-around next"

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
      if.app-id = "at.studio.AsideBrowser"
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
