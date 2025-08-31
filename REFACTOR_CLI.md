# fx-buildsh v2 CLI Refactor Plan

## Context & Motivation

**Origin:** While working on taskdb boxy template integration, we discovered fx-buildsh's current flag-based CLI (`-i`, `-s`) was awkward and didn't follow BashFX3 architecture patterns.

**Goals:** Transform fx-buildsh from a simple build script into a proper BashFX3-compliant CLI tool with full lifecycle management.

## v1 → v2 Migration

### Current v1 Commands (Flag-Based)
```bash
./build.sh -i MODULE POS      # Insert module at position  
./build.sh -s POS1 POS2       # Swap two positions
./build.sh -r                 # Rename/remap files  
./build.sh -l                 # List modules
./build.sh -c                 # Clean build
./build.sh -v                 # Verbose
./build.sh -o FILE            # Output file
./build.sh -p DIR             # Parts directory  
./build.sh -m FILE            # Build map file
./build.sh --help             # Help
```

### New v2 Commands (BashFX3 Subcommands)
```bash
# === CORE BUILD OPERATIONS ===
./build.sh build [OPTIONS]           # Assemble from modules (default)
./build.sh insert MODULE POSITION    # Insert with automatic renumbering  
./build.sh swap POS1 POS2            # Swap module positions
./build.sh list                      # List discovered modules
./build.sh remap                     # Sync filenames to build.map (destructive)

# === TOOLING & META ===  
./build.sh version                   # Show version via FX3 meta hack
./build.sh -v, --version             # Version aliases
./build.sh logo                      # Generate/show ASCII logo
./build.sh help [TOPIC]             # Help system

# === SAFETY & RECOVERY ===
./build.sh restore                   # List quarantined files
./build.sh restore FILE             # Restore specific file from quarantine
./build.sh restore --all            # Restore all quarantined files  
./build.sh restore --purge          # Delete quarantined files permanently

# === DISTRIBUTION & DEPLOYMENT ===
./build.sh install                   # Install to XDG+ paths (rewindable)
./build.sh deploy [OPTIONS]         # Deploy with org/namespace
./build.sh uninstall                # Remove installation (rewindable)

# === GLOBAL OPTIONS ===
-q, --quiet                          # Suppress logo and non-essential output
-o, --output FILE                    # Output filename
-p, --parts DIR                     # Parts directory  
-m, --map FILE                      # Build map file
```

## Key Architecture Changes

### 1. BashFX3 Compliance
- **`main()`** - Entry point, orchestrates lifecycle
- **`options()`** - Parse global flags into `opt_*` variables
- **`dispatch()`** - Route subcommands to `do_*` functions  
- **`do_insert()`, `do_swap()`** - Command implementations
- **`usage()`** - Master help system
- **`version()`** - FX3 meta comment hack
- **`logo()`** - Startup banner (silenceable with `-q`)

### 2. Quarantine System (Safety Improvement)
**Problem:** Current `remap` deletes conflicting files, causing data loss.

**Solution:** Quarantine instead of delete:
```bash
# Before remap:
parts/
  01_header.sh           # ✅ Mapped correctly
  old_backup_03.sh       # 🚫 Contains numbers, conflicts with mapping
  test_module.sh         # ✅ No numbers, safe

# After remap:  
parts/
  01_header.sh           # ✅ Stays
  test_module.sh         # ✅ Stays (no numbers = ignored)
parts/.invalid/
  old_backup_03.sh       # 🏥 Quarantined safely
```

**Recovery workflow:**
```bash
./build.sh remap                    # Quarantines conflicts
./build.sh restore --list           # See what was quarantined
./build.sh restore old_backup_03.sh # Restore if needed
./build.sh restore --purge          # Delete permanently when ready
```

### 3. XDG+ Installation System
**Lib-to-Bin Pattern:**
```bash
# Deploy structure:
~/.local/lib/fx/buildsh/build.sh     # Source in lib  
~/.local/bin/fx/build                # Symlink in bin (no .sh)

# With custom org/namespace:
./build.sh deploy --target=build.sh --org=tools --namespace=builder
# Creates: ~/.local/lib/tools/builder/build.sh → ~/.local/bin/tools/builder
```

**Rewindable Installation:**
- Track installed files in `~/.local/data/fx/install.registry`
- `install` creates symlinks + registry entries
- `uninstall` removes everything via registry
- Version upgrades replace existing installs cleanly

### 4. Enhanced Meta Features

**Version System (FX3 Meta Hack):**
```bash
#!/usr/bin/env bash
# build.sh - Enhanced modular build system  
# version: 2.0.0
# author: BashFX Build System
# license: MIT
```

**Logo System:**
```bash
./build.sh                          # Shows logo on startup
./build.sh -q                       # Suppresses logo  
./build.sh logo                     # Manage logo explicitly
./build.sh logo --generate          # Generate new ASCII art
```

## File Safety Rules

### Insert Module Rules
- **Must have NO numbers anywhere in filename**
- Examples:
  - ✅ `boxy.sh`, `logging.sh`, `auth_handler.sh`
  - ❌ `03_boxy.sh`, `boxy_v2.sh`, `log2file.sh`

### Managed Module Rules  
- **Must follow `NN_name.sh` pattern**
- Examples:
  - ✅ `01_header.sh`, `02_core.sh`, `15_footer.sh`
  - ❌ `header.sh`, `2_core.sh`, `footer_01.sh`

### Remap Behavior
- **Only processes files containing numbers**
- **Quarantines conflicts to `.invalid/` directory**
- **Ignores files without numbers** (safe for insert workflow)

## Migration Strategy

### Phase 1: Core Architecture
1. Implement BashFX3 main/options/dispatch pattern
2. Convert existing functionality to `do_*` functions
3. Maintain backward compatibility with flags during transition

### Phase 2: Safety Features  
1. Implement quarantine system for remap
2. Add restore command for recovery
3. Enhanced validation and error handling

### Phase 3: Advanced Features
1. Version system with meta comment parsing
2. Logo generation and startup banner
3. XDG+ installation and deployment system

### Phase 4: Polish & Documentation
1. Comprehensive help system
2. Command-specific help (`insert --help`)
3. Migration guide for v1 users

## Breaking Changes

### Removed Commands
- All single-letter flags become subcommands or options
- `./build.sh -r` → `./build.sh remap`  
- `./build.sh -l` → `./build.sh list`

### Behavioral Changes
- **Remap no longer deletes** - quarantines instead
- **Logo displays by default** - use `-q` to suppress
- **Help system restructured** - `help TOPIC` pattern

### New Requirements
- **BashFX3 architecture** - proper function structure
- **XDG+ compliance** - for installation features
- **Quarantine directory** - `.invalid/` for safety

## Success Criteria

1. **✅ Full BashFX3 compliance** - passes architecture validator
2. **✅ No data loss** - quarantine system prevents accidents  
3. **✅ Better UX** - natural subcommands vs cryptic flags
4. **✅ Professional tooling** - version, logo, install features
5. **✅ Extensible** - easy to add new commands and features

---

**Status:** Design Complete, Ready for Implementation  
**Next Steps:** Begin Phase 1 - Core Architecture Implementation