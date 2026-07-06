![스크린샷 2024-12-10 오후 11 03 55](https://github.com/user-attachments/assets/51caea7e-1bb9-4aa8-8422-14f8f41ec9d3)

# UEG (Unreal-Engine-Generate-for-Mac)

> Project status: **Archived / Discontinued**

UEG was a small macOS utility created to make Unreal Engine project file generation easier, especially for users who wanted a simple alternative to running terminal commands manually.

However, this project is now discontinued because JetBrains Rider on macOS can open Unreal Engine projects directly through the `.uproject` file. For the main workflow this tool was designed to solve, generating separate solution or project files is no longer necessary.

## Why development stopped

Originally, this tool existed to make the “Generate project files” workflow more accessible on macOS.

At the time, manually generating project files through Unreal Engine scripts or terminal commands could be inconvenient. But Rider now supports opening `.uproject` files directly, which makes this utility unnecessary for most Unreal Engine C++ workflows on macOS.

Recommended workflow:

```text
Open JetBrains Rider
→ Open the Unreal Engine .uproject file directly
→ Work from Rider without generating a separate .sln or Xcode project manually
```

## Legacy usage

This repository remains public as a legacy/reference project.

You may still use it if you specifically need manual project file generation behavior, but it is no longer actively maintained and future Unreal Engine or macOS compatibility is not guaranteed.

## Supported IDEs

- JetBrains Rider: open the `.uproject` file directly.
- Xcode: use Unreal Engine’s built-in project generation workflow if needed.

## Supported Unreal Engine Versions

Previously tested with:

- Unreal Engine 5.0 to 5.5
- GitHub Unreal Engine source builds / custom engine builds

Compatibility with newer Unreal Engine versions is not guaranteed.

## Supported macOS Versions

Previously tested with:

- Minimum: macOS 11 Big Sur
- Recommended: macOS 12 Monterey or later

Compatibility with newer macOS versions is not guaranteed.

## License

MIT License
