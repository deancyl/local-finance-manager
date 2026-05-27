# Windows Build Optimization

This document describes optimizations for Windows builds of the Finance App.

## DLL Configuration

### Required DLLs

1. **SQLite DLLs**
   - `sqlite3.dll` - SQLite database engine
   - For SQLCipher: `sqlcipher.dll`

2. **Visual C++ Runtime**
   - `vcruntime140.dll`
   - `msvcp140.dll`

3. **Flutter Engine DLLs**
   - `flutter_windows.dll`

### DLL Placement

```
build/windows/x64/runner/Release/
├── finance_app.exe
├── flutter_windows.dll
├── sqlite3.dll
└── data/
```

## Build Configuration

### CMake Settings

```cmake
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(CMAKE_BUILD_TYPE STREQUAL "Release")
  add_compile_options(/O2 /GL)
  add_link_options(/LTCG)
endif()
```

## Performance Optimization

### Compiler Flags

- `/O2` - Optimize for speed
- `/GL` - Whole program optimization
- `/Gy` - Enable function-level linking

### Linker Flags

- `/LTCG` - Link-time code generation
- `/OPT:REF` - Eliminate unreferenced functions
- `/OPT:ICF` - Merge identical sections

## Distribution

### Installer Creation

Use Inno Setup or NSIS to create Windows installer.

### Code Signing

```powershell
signtool sign /f certificate.pfx /p password finance_app.exe
```

## Troubleshooting

### Missing DLL Errors

1. Check all DLLs are in the same directory as the .exe
2. Use Dependency Walker to identify missing dependencies
3. Ensure Visual C++ Redistributable is installed

---

*Document generated: 2026-05-27*