# The capability catalog: every skill, MCP server, plugin and tool the agents
# can use, one attrset per entry. r1hn projects it into every client (Claude
# Code, Codex, agy) and every account directory; see docs/agent-platforms.md.
#
# Fields (types: harness-core nix/capabilities.nix):
#   kind     skill | mcp | plugin | tool
#   tier     baseline (everywhere) | catalog (listed, suggested, enabled per
#            project) | off (listed only). The owner overrides it without a
#            rebuild: `r1hn capability enable|disable ID [--project DIR]`
#   hosts    [ "all" ] | [ "mac" ] | [ "linux" ]; MCP uses mcp.remote elsewhere
#   clients  default all of claude codex antigravity dsh
#   detect   files / contains signals for `r1hn capability suggest`
#   mcp.local / mcp.remote  { command args } or { url }; env holds references
#            only (env:NAME, file:PATH, op://...), never values
#
# Skills come from programs.agent-skills sources (agent-skills.nix) unless an
# entry sets source. Skills found there but not listed here are added as
# tier = "off" so they stay discoverable. Files in ./adopted (written by
# `r1hn capability adopt NAME --write`) are merged in.
#
# Prefer nixpkgs packages for MCP servers. A pinned npx/uvx command is used
# only where no package exists and is marked "pinned runner".
{
  pkgs,
  lib,
  inputs,
  homeDir,
  discovered ? { },
}:
let
  skill =
    tier: tags: description: extra:
    {
      kind = "skill";
      inherit tier tags description;
    }
    // extra;
  baseline = skill "baseline";
  catalog = skill "catalog";

  tool = description: package: {
    kind = "tool";
    tier = "baseline";
    tags = [ "tool" ];
    inherit description;
    source = "nixpkgs#${package.pname or package.name}";
    packages = [ package ];
  };

  swift.files = [
    "Package.swift"
    "*.xcodeproj"
    "*.xcworkspace"
  ];
  web = {
    files = [
      "next.config.*"
      "vite.config.*"
      "tailwind.config.*"
      "components.json"
    ];
    contains."package.json" = [
      "\"react\""
      "\"next\""
      "\"vue\""
      "\"svelte\""
    ];
  };
  aside = "${homeDir}/.local/bin/aside";

  curated = {
    # Baseline skills: small, used in most sessions.
    agent-browser = baseline [ "browser" ] "Isolated browser automation (agent-browser CLI)" {
      fallback = null;
    };
    aside = baseline [
      "browser"
      "mac"
    ] "The owner's logged-in Aside browser; other hosts reach it with --host" { fallback = "agent-browser"; };
    find-skills = baseline [ "meta" ] "Find a skill before writing one" { };
    pdf = baseline [ "docs" ] "Read, fill and create PDF files" { };
    xlsx = baseline [ "docs" ] "Read and write spreadsheets" { };
    gh-fix-ci = baseline [ "github" ] "Fix failing GitHub Actions checks with gh" { };
    security-best-practices = baseline [ "security" ] "Secure-by-default coding review" { };
    session-handoff = baseline [ "session" ] "Hand unfinished work over between sessions and accounts" { };
    session-documentation = baseline [ "session" ] "Write a session up into the project's docs" { };
    orchestration = baseline [ "agents" ] "Split work across agents and integrate it" { };
    youtube-transcript = baseline [ "media" ] "Fetch YouTube subtitles or audio as text (yt-dlp, whisper)" { };
    x-research = baseline [ "research" ] "Research recent discussion on X" { };
    post-review = baseline [ "review" ] "Review and clean up after implementing" { };
    r1hn-capabilities = baseline [
      "meta"
      "tool"
    ] "List, suggest and enable capabilities; ask the owner first" { };

    # Swift and Apple platforms.
    swift-dev-toolkit = catalog [ "swift" ] "Swift and SwiftUI development workflow" { detect = swift; };
    ios-device-build = catalog [ "swift" ] "Build, install and run an iOS app on a device" { detect = swift; };
    app-store-screenshots = catalog [ "swift" "design" ] "App Store screenshot generation" {
      detect = swift;
    };
    codex-app-screenshots = catalog [ "swift" "design" ] "App Store mockups through the ChatGPT web UI" { };
    swiftui-pro = catalog [ "swift" ] "SwiftUI review and modern API guidance (twostraws)" { detect = swift; };

    # Frontend and design.
    vercel-react-best-practices = catalog [ "web" ] "React and Next.js performance rules" { detect = web; };
    frontend-design = catalog [ "web" "design" ] "Distinctive frontend design" { detect = web; };
    baseline-ui = catalog [ "web" "design" ] "Opinionated UI baseline against generic AI UI" {
      detect = web;
    };
    web-design-guidelines = catalog [ "web" "design" ] "Review UI against web interface guidelines" {
      detect = web;
    };
    taste-skill = catalog [ "web" "design" ] "design-taste-frontend: contextual anti-slop frontend" {
      detect = web;
    };
    output-skill = catalog [ "agents" ] "full-output-enforcement: no truncated code output" { };
    image-to-code-skill = catalog [ "web" "design" ] "Image first, then implement it" { };
    unslop = catalog [ "web" "design" ] "Audit and redesign AI-looking UI" { detect = web; };
    design-capture = catalog [ "design" "vault" ] "Capture a site's design tokens into the vault" { };
    brandkit = catalog [ "design" "media" ] "Brand identity image generation" { };
    imagegen-frontend-web = catalog [ "design" "media" ] "Reference images for web UI" { };
    imagegen-frontend-mobile = catalog [ "design" "media" ] "Reference images for mobile UI" { };

    # Media.
    remotion-best-practices = catalog [ "media" "web" ] "Video in React with Remotion" {
      detect.contains."package.json" = [ "\"remotion\"" ];
    };
    video-editing = catalog [ "media" ] "Edit video with ffmpeg" {
      detect.files = [
        "*.mp4"
        "*.mov"
      ];
    };
    text-to-lottie = catalog [ "media" ] "Author Lottie animations" { detect.files = [ "*.lottie" ]; };

    # Writing and research.
    typst-author = catalog [ "docs" "academic" ] "Write Typst documents" { detect.files = [ "*.typ" ]; };
    touying-author = catalog [ "docs" "academic" ] "Typst slides with Touying" {
      detect.contains."main.typ" = [ "touying" ];
    };
    x-article-publisher = catalog [ "publishing" ] "Prepare or publish X Articles" { };
    masao-research = catalog [ "research" ] "Follow one AI explainer channel across platforms" { };
    notebooklm-skill = catalog [ "research" ] "Query NotebookLM notebooks" { };
    last30days = catalog [ "research" ] "Recent discussion across Reddit, X, YouTube and HN" { };
    exa-search = catalog [ "research" ] "Exa neural web and code search (needs an Exa key)" {
      source = "${pkgs.exa-agent-skills}/share/skills/exa-agent-skills/exa-search";
    };
    knowledge-extract = catalog [ "vault" ] "Save what a session learned into the vault" {
      detect.files = [ "20_Knowledge" ];
    };
    forms-archive = catalog [ "docs" ] "Archive every page of a Microsoft Forms form" { };

    # Python and ML (huggingface/skills).
    hf-cli = catalog [ "ml" ] "Hugging Face Hub CLI" {
      detect.files = [
        "pyproject.toml"
        "*.ipynb"
      ];
    };
    huggingface-datasets = catalog [ "ml" ] "Find and use Hugging Face datasets" { detect.files = [ "*.ipynb" ]; };
    huggingface-papers = catalog [ "ml" "academic" ] "Read and find papers on Hugging Face" { };
    trl-training = catalog [ "ml" ] "Fine-tune models with TRL" {
      detect.contains."pyproject.toml" = [
        "trl"
        "transformers"
      ];
    };
    transformers-js = catalog [ "ml" "web" ] "Run models in JavaScript with Transformers.js" {
      detect.contains."package.json" = [ "@huggingface/transformers" ];
    };

    # Process and maintenance.
    property-based-testing = catalog [ "testing" ] "Property-based tests (Trail of Bits)" {
      detect.contains = {
        "Cargo.toml" = [ "proptest" ];
        "pyproject.toml" = [ "hypothesis" ];
        "package.json" = [ "fast-check" ];
      };
    };
    skill-builder = catalog [ "meta" ] "Write a new skill" { detect.files = [ "SKILL.md" ]; };
    skill-auditor = catalog [ "meta" ] "Audit skills and the skill portfolio" { detect.files = [ "SKILL.md" ]; };
    idea-to-ship = catalog [ "workflow" ] "From idea to shipped change" { };
    project-init = catalog [ "workflow" ] "Set a project up for this agent workflow" { };
    indexion-workspace = catalog [ "workflow" ] "Explore related repositories with indexion" { };
    i-have-adhd = catalog [ "style" ] "Next action first in replies" { };
    op-api-keys = catalog [ "security" ] "Read API keys through the 1Password CLI" { };
    orca-cli = catalog [ "orca" ] "Drive Orca worktrees and terminals" { };
    orca-computer-use = catalog [
      "orca"
      "mac"
    ] "Orca computer use" { };
    workfolio = catalog [
      "work"
    ] "Workfolio time, overtime, invoices and income through its MCP tools" { };

    # MCP servers. Context7 and DeepWiki cost a few tool schemas each.
    context7 = {
      kind = "mcp";
      tier = "baseline";
      tags = [ "docs" ];
      description = "Current library documentation (Context7; an API key is optional)";
      source = "nixpkgs#context7-mcp";
      mcp.local.command = lib.getExe pkgs.context7-mcp;
    };
    deepwiki = {
      kind = "mcp";
      tier = "baseline";
      tags = [ "docs" ];
      description = "Questions about public GitHub repositories (DeepWiki, no key)";
      source = "https://mcp.deepwiki.com/mcp";
      mcp.local.url = "https://mcp.deepwiki.com/mcp";
    };
    # Runs from the Workfolio checkout (bun install done there). The URL and
    # the group's token come from r1hn's [env.<group>], never from this file.
    workfolio-mcp = {
      kind = "mcp";
      tier = "catalog";
      tags = [ "work" ];
      description = "Workfolio over its API, scoped to the session group's token";
      source = "workfolio mcp/ (private repository checkout)";
      mcp.local = {
        command = lib.getExe pkgs.bun;
        args = [
          "run"
          "${homeDir}/Develop/github.com/r1cA18/workfolio/mcp/index.ts"
        ];
        env = {
          WORKFOLIO_URL = "env:WORKFOLIO_URL";
          WORKFOLIO_TOKEN = "env:WORKFOLIO_TOKEN";
          WORKFOLIO_MCP_TOOLS = "env:WORKFOLIO_MCP_TOOLS";
        };
      };
    };
    olympus = {
      kind = "mcp";
      tier = "baseline";
      tags = [ "personal" ];
      description = "Olympus life management, served from the Linux server";
      source = "olympus apps/mcp";
      hosts = [ "linux" ];
      mcp.local = {
        command = lib.getExe pkgs.bun;
        args = [
          "run"
          "/home/r1ca18/Develop/github.com/r1cA18/olympus/apps/mcp/src/index.ts"
        ];
      };
      mcp.remote = {
        command = "/usr/bin/ssh";
        args = [
          "-T"
          "homelab"
          "/home/r1ca18/.nix-profile/bin/bun"
          "run"
          "/home/r1ca18/Develop/github.com/r1cA18/olympus/apps/mcp/src/index.ts"
        ];
      };
    };
    aside-mcp = {
      kind = "mcp";
      tier = "baseline";
      tags = [
        "browser"
        "mac"
      ];
      description = "Aside browser agent and repl over MCP; remote hosts reach the Mac";
      source = "Aside CLI (self-updating, ~/.local/bin/aside)";
      hosts = [ "mac" ];
      fallback = "agent-browser";
      mcp.local = {
        command = aside;
        args = [ "mcp" ];
      };
      mcp.remote = {
        command = aside;
        args = [
          "mcp"
          "--host"
          "remote"
        ];
      };
    };
    aside-computer-use = {
      kind = "mcp";
      tier = "catalog";
      tags = [
        "mac"
        "computer-use"
      ];
      description = "Native app control through Aside Computer Use";
      source = "Aside CLI";
      hosts = [ "mac" ];
      mcp.local = {
        command = aside;
        args = [
          "mcp"
          "--computer-use"
        ];
      };
    };
    playwright = {
      kind = "mcp";
      tier = "catalog";
      tags = [
        "browser"
        "web"
      ];
      description = "Playwright browser control over MCP";
      source = "nixpkgs#playwright-mcp";
      detect = web;
      mcp.local.command = lib.getExe pkgs.playwright-mcp;
    };
    chrome-devtools = {
      kind = "mcp";
      tier = "catalog";
      tags = [
        "browser"
        "web"
        "pinned runner"
      ];
      description = "Chrome DevTools: performance traces, console and network";
      source = "npm chrome-devtools-mcp 1.13.0 (pinned runner; not in nixpkgs)";
      detect = web;
      mcp.local = {
        command = lib.getExe' pkgs.nodejs "npx";
        args = [
          "-y"
          "chrome-devtools-mcp@1.13.0"
        ];
      };
    };
    mcp-nixos = {
      kind = "mcp";
      tier = "catalog";
      tags = [ "nix" ];
      description = "NixOS, Home Manager and nix-darwin options and packages";
      source = "nixpkgs#mcp-nixos";
      detect.files = [
        "flake.nix"
        "*.nix"
      ];
      mcp.local.command = lib.getExe pkgs.mcp-nixos;
    };
    sosumi = {
      kind = "mcp";
      tier = "catalog";
      tags = [ "swift" ];
      description = "Apple developer documentation and HIG as Markdown (sosumi.ai)";
      source = "https://sosumi.ai/mcp";
      detect = swift;
      mcp.local.url = "https://sosumi.ai/mcp";
    };
    serena = {
      kind = "mcp";
      tier = "catalog";
      tags = [
        "code"
        "pinned runner"
      ];
      description = "Symbol-level code navigation through language servers";
      source = "github:oraios/serena v2.1.0 (pinned runner; not in nixpkgs)";
      mcp.local = {
        command = lib.getExe' pkgs.uv "uvx";
        args = [
          "--from"
          "git+https://github.com/oraios/serena@v2.1.0"
          "serena"
          "start-mcp-server"
        ];
      };
    };
    github = {
      kind = "mcp";
      tier = "off";
      tags = [ "github" ];
      description = "GitHub MCP server; gh covers most of it at no schema cost";
      source = "nixpkgs#github-mcp-server";
      mcp.local = {
        command = lib.getExe pkgs.github-mcp-server;
        args = [ "stdio" ];
        env.GITHUB_PERSONAL_ACCESS_TOKEN = "env:GH_TOKEN";
      };
    };
    fetch = {
      kind = "mcp";
      tier = "catalog";
      tags = [ "web" ];
      description = "Fetch a URL as Markdown, for clients without a fetch tool";
      source = "nixpkgs#mcp-server-fetch";
      clients = [
        "codex"
        "antigravity"
        "dsh"
      ];
      mcp.local.command = lib.getExe pkgs.mcp-server-fetch;
    };

    # Plugins, as each client names them.
    claude-codex = {
      kind = "plugin";
      tier = "baseline";
      tags = [ "agents" ];
      description = "Ask Codex from Claude Code";
      source = "github:openai/codex-plugin-cc";
      clients = [ "claude" ];
      plugin.claude = {
        name = "codex@openai-codex";
        marketplace = "openai-codex";
        source = {
          source = "github";
          repo = "openai/codex-plugin-cc";
        };
      };
    };
    claude-antigravity = {
      kind = "plugin";
      tier = "baseline";
      tags = [ "agents" ];
      description = "Ask Antigravity from Claude Code";
      source = "github:yuting0624/antigravity-for-claude-code";
      clients = [ "claude" ];
      plugin.claude = {
        name = "antigravity@antigravity-for-claude-code";
        marketplace = "antigravity-for-claude-code";
        source = {
          source = "github";
          repo = "yuting0624/antigravity-for-claude-code";
        };
      };
    };
  }
  // codexPlugins
  // tools;

  # Codex plugins enabled today. The advisor's marketplace is a flake input
  # (codex.nix also runs `codex plugin add` for it in the default directory).
  codexPlugin = name: description: {
    kind = "plugin";
    tier = "baseline";
    tags = [ "codex" ];
    inherit description;
    source = name;
    clients = [ "codex" ];
    plugin.codex.name = name;
  };
  codexPlugins = {
    codex-claude-advisor = codexPlugin "claude-code-advisor@claude-plugin-codex" "Ask local Claude Code from Codex" // {
      source = "github:yanchuk/claude-plugin-codex";
      plugin.codex = {
        name = "claude-code-advisor@claude-plugin-codex";
        marketplace = "claude-plugin-codex";
        source = {
          source_type = "local";
          source = "${inputs.claude-plugin-codex}";
        };
      };
    };
    codex-google-calendar = codexPlugin "google-calendar@openai-curated" "Google Calendar in Codex";
    codex-github = codexPlugin "github@openai-curated" "GitHub in Codex";
    codex-browser-use = codexPlugin "browser-use@openai-bundled" "Browser use in Codex";
    codex-browser = codexPlugin "browser@openai-bundled" "Codex browser";
    codex-chrome = codexPlugin "chrome@openai-bundled" "Chrome in Codex";
    codex-documents = codexPlugin "documents@openai-primary-runtime" "Documents in Codex";
    codex-pdf = codexPlugin "pdf@openai-primary-runtime" "PDF in Codex";
    codex-spreadsheets = codexPlugin "spreadsheets@openai-primary-runtime" "Spreadsheets in Codex";
    codex-presentations = codexPlugin "presentations@openai-primary-runtime" "Presentations in Codex";
  };

  # Tools on PATH: no context cost. The r1hn-capabilities skill names them.
  tools = {
    yt-dlp = tool "Download video, audio and subtitles" pkgs.yt-dlp;
    ffmpeg = tool "Convert and cut audio and video" pkgs.ffmpeg;
    markitdown = tool "Any document to Markdown" pkgs.markitdown;
    pandoc = tool "Convert between document formats" pkgs.pandoc;
    duckdb = tool "SQL over CSV, Parquet and JSON" pkgs.duckdb;
    sqlite = tool "SQLite shell" pkgs.sqlite;
    ast-grep = tool "Structural code search and rewrite" pkgs.ast-grep;
    ripgrep = tool "Fast text search" pkgs.ripgrep;
    jq = tool "JSON processing" pkgs.jq;
    mermaid-cli = tool "Render Mermaid diagrams (mmdc)" pkgs.mermaid-cli;
    d2 = tool "Render D2 diagrams" pkgs.d2;
    gh = tool "GitHub CLI" pkgs.gh;
    whisper-cpp = tool "Local speech to text" pkgs.whisper-cpp;
  };

  adoptedDir = ./adopted;
  adopted = lib.foldl' (acc: file: acc // import (adoptedDir + "/${file}")) { } (
    builtins.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir adoptedDir))
  );

  # Skills the sources provide that nobody classified yet.
  undecided = lib.mapAttrs (_: found: {
    kind = "skill";
    tier = "off";
    tags = [ "unclassified" ];
    description = "Found in source ${found.source}; not classified yet";
  }) (removeAttrs discovered (builtins.attrNames curated));
in
undecided // curated // adopted
