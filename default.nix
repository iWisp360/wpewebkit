{
  lib,
  clangStdenv,
  perl,
  python3,
  ruby,
  bison,
  gperf,
  cmake,
  ninja,
  pkg-config,
  gettext,
  gnutls,
  libgcrypt,
  libgpg-error,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libwebp,
  enchant,
  libx11,
  libxkbcommon,
  libavif,
  libepoxy,
  libjxl,
  at-spi2-core,
  cairo,
  expat,
  libxml2,
  libwpe,
  libjpeg,
  libsoup_3,
  libsecret,
  libxslt,
  harfbuzzFull,
  hyphen,
  icu,
  libsysprof-capture,
  libpthread-stubs,
  nettle,
  libtasn1,
  p11-kit,
  libidn,
  libedit,
  readline,
  libGL,
  libGLU,
  libgbm,
  libintl,
  lcms2,
  libmanette,
  geoclue2,
  flite,
  fontconfig,
  freetype,
  openssl,
  openxr-loader,
  sqlite,
  gst_all_1,
  woff2,
  bubblewrap,
  libseccomp,
  libbacktrace,
  systemdLibs,
  xdg-dbus-proxy,
  replaceVars,
  glib,
  unifdef,
  addDriverRunpath,
  enableGeoLocation ? true,
  enableExperimental ? false,
  withLibsecret ? true,
  systemdSupport ? lib.meta.availableOn clangStdenv.hostPlatform systemdLibs,
  testers,
  fetchpatch,
  port ? "wpe",
  fetchurl,
  ...
}:

# https://webkitgtk.org/2024/10/04/webkitgtk-2.46.html recommends building with clang.
clangStdenv.mkDerivation (finalAttrs: {
  pname = "wpewebkit";
  version = "2.50.6";
  name = "wpewebkit-${finalAttrs.version}";

  # https://github.com/NixOS/nixpkgs/issues/153528
  # Can't be linked within a 4GB address space.
  separateDebugInfo = clangStdenv.hostPlatform.isLinux && !clangStdenv.hostPlatform.is32bit;

  src = fetchurl {
    url = "https://wpewebkit.org/releases/wpewebkit-${finalAttrs.version}.tar.xz";
    hash = "sha256-iGT9P2EWNw11Ql+bHvpI6xiMz0LJKunoqvLdUfnyfe8=";
  };

  patches = lib.optionals clangStdenv.hostPlatform.isLinux [
    (replaceVars ./fix-bubblewrap-paths.patch {
      inherit (builtins) storeDir;
      inherit (addDriverRunpath) driverLink;
    })

    # Workaround to fix cross-compilation for RiscV
    # error: ‘toB3Type’ was not declared in this scope
    # See: https://bugs.webkit.org/show_bug.cgi?id=271371
    (fetchpatch {
      url = "https://salsa.debian.org/webkit-team/webkit/-/raw/debian/2.44.1-1/debian/patches/fix-ftbfs-riscv64.patch";
      hash = "sha256-MgaSpXq9l6KCLQdQyel6bQFHG53l3GY277WePpYXdjA=";
      name = "fix_ftbfs_riscv64.patch";
    })
  ];

  nativeBuildInputs = [
    bison
    cmake
    gettext
    gperf
    ninja
    perl
    perl.pkgs.FileCopyRecursive # used by copy-user-interface-resources.pl
    pkg-config
    python3
    ruby
    glib # for gdbus-codegen
    unifdef
  ]
  ++ lib.optionals clangStdenv.hostPlatform.isLinux [
    wayland-scanner
  ];

  buildInputs = [
    at-spi2-core
    cairo # required even when using skia
    enchant
    expat
    flite
    libavif
    libepoxy
    libjxl
    gnutls
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-base
    harfbuzzFull
    hyphen
    icu
    libGL
    libGLU
    libgbm
    libgcrypt
    libgpg-error
    libidn
    libintl
    lcms2
    libpthread-stubs
    libsysprof-capture
    libtasn1
    libwebp
    libxkbcommon
    libxml2
    libxslt
    libbacktrace
    nettle
    p11-kit
    sqlite
    wayland-protocols
    libwpe
    libjpeg
    woff2
  ]
  ++ lib.optionals clangStdenv.hostPlatform.isBigEndian [
    # https://bugs.webkit.org/show_bug.cgi?id=274032
    fontconfig
    freetype
  ]
  ++ lib.optionals clangStdenv.hostPlatform.isDarwin [
    libedit
    readline
  ]
  ++ lib.optionals clangStdenv.hostPlatform.isLinux [
    libseccomp
    libmanette
    wayland
    libx11
  ]
  ++ lib.optionals systemdSupport [
    systemdLibs
  ]
  ++ lib.optionals enableGeoLocation [
    geoclue2
  ]
  ++ lib.optionals enableExperimental [
    # For ENABLE_WEB_RTC
    openssl
    # For ENABLE_WEBXR
    openxr-loader
  ]
  ++ lib.optionals withLibsecret [
    libsecret
  ];

  propagatedBuildInputs = [
    libsoup_3
  ];

  cmakeFlags =
    let
      cmakeBool = x: if x then "ON" else "OFF";
    in
    [
      "-DENABLE_INTROSPECTION=OFF"
      "-DPORT=${lib.toUpper port}"
      "-DUSE_SOUP2=${cmakeBool false}"
      "-DUSE_LIBSECRET=${cmakeBool withLibsecret}"
      "-DUSE_GTK4=OFF"
      "-DENABLE_GTKDOC=OFF"
      "-DENABLE_EXPERIMENTAL_FEATURES=${cmakeBool enableExperimental}"
    ]
    ++ lib.optionals clangStdenv.hostPlatform.isLinux [
      # Have to be explicitly specified when cross.
      # https://github.com/WebKit/WebKit/commit/a84036c6d1d66d723f217a4c29eee76f2039a353
      "-DBWRAP_EXECUTABLE=${lib.getExe bubblewrap}"
      "-DDBUS_PROXY_EXECUTABLE=${lib.getExe xdg-dbus-proxy}"
    ]
    ++ lib.optionals clangStdenv.hostPlatform.isDarwin [
      "-DENABLE_GAMEPAD=OFF"
      "-DENABLE_GTKDOC=OFF"
      "-DENABLE_MINIBROWSER=OFF"
      "-DENABLE_QUARTZ_TARGET=ON"
      "-DENABLE_X11_TARGET=OFF"
      "-DUSE_APPLE_ICU=OFF"
      "-DUSE_OPENGL_OR_ES=OFF"
    ]
    ++ lib.optionals (!systemdSupport) [
      "-DENABLE_JOURNALD_LOG=OFF"
    ];

  postPatch = ''
    patchShebangs .
  '';

  requiredSystemFeatures = [ "big-parallel" ];

  passthru.tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;

  meta = {
    description = "Web content rendering engine, WPE port";
    mainProgram = "WPEWebDriver";
    homepage = "https://wpewebkit.org/";
    license = lib.licenses.bsd2;

    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = [ lib.maintainers.iwisp360 ];
    broken = clangStdenv.hostPlatform.isDarwin;
  };
})
