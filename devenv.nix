{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = [
    pkgs.cacert
    pkgs.git
    pkgs.biome
    pkgs.chromium
    pkgs.unzip
  ];

  scripts.webtoepub-browser-mcp = {
    description = "Run Chrome DevTools MCP with the project's Chromium and a dedicated profile";
    exec = ''
      export PATH="${pkgs.nodejs_24}/bin:$PATH"
      browser_profile=${lib.escapeShellArg "${config.devenv.state}/agent-chromium"}
      browser_profile="''${WEBTOEPUB_BROWSER_PROFILE:-$browser_profile}"
      exec ${pkgs.nodejs_24}/bin/npx --yes chrome-devtools-mcp@1.12.0 \
        --executablePath=${pkgs.chromium}/bin/chromium \
        --userDataDir="$browser_profile" \
        --filesystemRoot=${lib.escapeShellArg config.devenv.root} \
        --categoryExtensions \
        --no-usage-statistics \
        --no-performance-crux \
        "$@"
    '';
  };

  files.".codex/config.toml".toml = {
    model = "gpt-6.1-sol";
    model_reasoning_effort = "medium";
    agents = {
      default_subagent_model = "gpt-6-luna";
      default_subagent_reasoning_effort = "high";
    };
    mcp_servers.webtoepub_browser = {
      command = "${config.scripts.webtoepub-browser-mcp.scriptPackage}/bin/webtoepub-browser-mcp";
      cwd = config.devenv.root;
      startup_timeout_sec = 120;
      tool_timeout_sec = 120;
      env_vars = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_RUNTIME_DIR"
        "DBUS_SESSION_BUS_ADDRESS"
        "XAUTHORITY"
      ];
    };
  };

  languages.javascript = {
    enable = true;
    lsp.enable = true;
    nodejs.enable = true;
    npm.enable = true;
  };

  languages.typescript = {
    enable = true;
  };

  devcontainer = {
    enable = true;
    settings.customization.zed.extensions = [
      "nix"
    ];
  };
}
