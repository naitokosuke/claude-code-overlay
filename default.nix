{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  zlib,
  writableTmpDirAsHomeHook,
  versionCheckHook,
}: let
  version = "2.0.50";

  sources = {
    x86_64-linux = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/linux-x64/claude";
      hash = "sha256-LDOZ6KIuYHxhrgB7P/4RYzZIzaGV55BWjsdfGc9VCDM=";
    };
    aarch64-linux = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/linux-arm64/claude";
      hash = "sha256-FIjZwijAyX9lHG/LNwU8Xf+obzH3eyMtR+Yb/32lYi4=";
    };
    x86_64-darwin = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/darwin-x64/claude";
      hash = "sha256-PsWeIJ5F+G8PY+CHNhQsIg6Gxeed/6IcqDkuGHy/a84=";
    };
    aarch64-darwin = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/darwin-arm64/claude";
      hash = "sha256-qNBvLdsvCYF+yjl8Ee/dlg5+JWONF8WXYPHP03HQRDA=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation rec {
    pname = "claude";
    inherit version;

    src = fetchurl {
      inherit (source) url hash;
    };

    nativeBuildInputs = [makeWrapper] ++ lib.optionals stdenv.isLinux [autoPatchelfHook];

    buildInputs = lib.optionals stdenv.isLinux [
      stdenv.cc.cc.lib
      zlib
    ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 $src $out/bin/claude

      runHook postInstall
    '';

    # Wrap the binary with environment variables to disable telemetry and auto-updates
    postFixup = ''
      wrapProgram $out/bin/claude \
        --set DISABLE_AUTOUPDATER 1 \
        --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
        --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
        --set DISABLE_TELEMETRY 1
    '';

    dontStrip = true; # to not mess with the bun runtime

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      writableTmpDirAsHomeHook
      versionCheckHook
    ];
    versionCheckKeepEnvironment = ["HOME"];
    versionCheckProgramArg = "--version";

    passthru = {
      updateScript = ./update.ts;
    };

    meta = with lib; {
      inherit version;
      description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
      homepage = "https://claude.ai/code";
      downloadPage = "https://github.com/anthropics/claude-code/releases";
      changelog = "https://github.com/anthropics/claude-code/releases";
      license = licenses.unfree;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "claude";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      maintainers = [];
    };
  }
