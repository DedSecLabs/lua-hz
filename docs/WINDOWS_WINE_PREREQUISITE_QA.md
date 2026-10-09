# Windows and Wine prerequisite QA

Prepared October 8, 2026. Native Windows results are pending; this document does not claim a fresh Windows test was run.

| Environment | Initial state | Goal |
|---|---|---|
| Clean Windows 10/11, 64-bit | GTA SA 1.0 US + stock SA-MP; no LuaHZ prerequisite pack | Identify what the game/OS already provides and what is genuinely missing |
| Existing Windows gaming setup | Record existing DirectX helper and VC++ x86 versions | Verify LuaHZ can use existing compatible components without duplicate installs |
| Fresh Wine prefix on Linux | Required game files with default prefix DLLs | Identify which compatible implementations work and which Microsoft helpers are needed |
| Existing tested Wine prefix | Current 0.2.7 setup | Preserve the comparison baseline |

## Procedure

1. Record OS/runner version, architecture, game/client hashes and supplied prerequisite versions.
2. Test stock SA-MP connection and login audio before adding LuaHZ.
3. Add only the pinned ASI Loader, CLEO, R5 SAMPFUNCS, MoonLoader and LuaHZ libraries/assets.
4. Attempt startup before installing additional runtime packages. Capture exact loader or module errors; record whether the default environment resolves D3DX9_25, D3DX9_43, VCRUNTIME140 and UCRT imports.
5. Install a missing dependency from its official source and repeat the same startup. Preserve before/after results rather than relying solely on file existence.
6. Exercise UI textures, all menu pages, HUD, keybind dispatch, dialogs, incoming server events and login audio.
7. Document the supported versions and conditional installer instructions once the results establish them.

On 64-bit Windows the relevant mod/game binaries are still x86. Do not conclude that an installed x64 VC++ package supplies their x86 dependencies.

## Official links

- [DirectX End-User Runtimes, June 2010](https://www.microsoft.com/en-us/download/details.aspx?id=8109)
- [Supported Visual C++ Redistributables](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)
- [Current VC++ x86 download](https://aka.ms/vc14/vc_redist.x86.exe)
- [Winetricks](https://github.com/Winetricks/winetricks)
- [FYP's English MoonLoader documentation](https://gtaforums.com/topic/890987-moonloader/)

## Release wording until tested

The required runtime DLLs must be available. Users who already have compatible components need no extra installation. Native Windows clean-install validation is pending. Windows and Linux/Wine setup instructions will be separate.
