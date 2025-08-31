# build.sh Refactoring Plan

## Executive Summary
validate.sh identified 24 mega functions and significant code reuse opportunities in build.sh. This plan addresses the most critical refactoring needs while maintaining functionality.

## Priority 1: Critical Mega Functions

### 1. do_deploy() - 301 lines (CRITICAL)
**Problem**: Monolithic deployment function handling too many responsibilities
**Solution**: Break into logical components:
```bash
do_deploy() {
    _parse_deploy_options "$@"
    _validate_deploy_environment
    _prepare_deploy_directories  
    _handle_deploy_conflicts
    _execute_deployment
    _create_deploy_wrappers
    _update_deploy_registry
    _show_deploy_summary
}
```

### 2. do_build() - 160 lines
**Problem**: Handles discovery, validation, assembly, and output in one function
**Solution**: Extract sub-functions:
```bash
do_build() {
    _configure_build_environment
    _discover_modules
    _validate_modules
    _assemble_output
    _perform_syntax_check
    _show_build_summary
}
```

### 3. options() - 113 lines  
**Problem**: Giant case statement handling all option parsing
**Solution**: Group by functional area:
```bash
options() {
    case "$1" in
        build|insert|swap|list|remap|restore) _parse_build_options "$@" ;;
        install|uninstall|deploy) _parse_install_options "$@" ;;
        test|status|version|logo) _parse_utility_options "$@" ;;
        *) _parse_general_options "$@" ;;
    esac
}
```

## Priority 2: Code Reuse Opportunities

### 1. Message Helper Functions (96 total patterns)
Create standardized messaging functions:
```bash
error_msg() { printf "%sERROR:%s %s\n" "$red" "$x" "$*" >&2; }
success_msg() { printf "%s✓%s %s\n" "$green" "$x" "$*"; }
info_msg() { printf "%sINFO:%s %s\n" "$blue" "$x" "$*"; }
warn_msg() { printf "%sWARN:%s %s\n" "$yellow" "$x" "$*"; }
```

### 2. Directory Operations Helper
Consolidate directory creation patterns:
```bash
ensure_directory() {
    local dir="$1"
    local description="${2:-directory}"
    if ! mkdir -p "$dir" 2>/dev/null; then
        error_msg "Cannot create $description: $dir"
        return 1
    fi
}
```

### 3. XDG Directory Parser
Extract repeated XDG directory parsing:
```bash
parse_xdg_output() {
    local xdg_dirs="$1"
    echo "$xdg_dirs" | grep "^$2=" | cut -d= -f2-
}
```

## Priority 3: Medium Functions (30-50 lines)

### Functions to Consider Breaking Down:
- `usage_general()`: 120 lines - Split by command categories
- `do_uninstall()`: 121 lines - Extract validation and cleanup logic
- `show_full_status()`: 114 lines - Split display sections

## Implementation Strategy

### Phase 1: Helper Functions (Low Risk)
1. Add message helper functions
2. Add directory helper functions  
3. Add XDG parsing helpers
4. Update existing code to use helpers

### Phase 2: Function Extraction (Medium Risk)  
1. Extract sub-functions from do_deploy()
2. Extract sub-functions from do_build()
3. Extract option parsing helpers

### Phase 3: Major Restructuring (Higher Risk)
1. Refactor options() function
2. Split usage functions by category
3. Consider modular architecture

## Validation Integration

The updated validate.sh now automatically:
- Detects mega functions (>50 lines)
- Identifies code reuse opportunities  
- Works with both ixhand.sh and build.sh
- Provides specific metrics for improvement tracking

## Benefits

### Immediate Benefits:
- Reduced code duplication
- Improved error message consistency
- Better maintainability

### Long-term Benefits:
- Easier testing of individual components
- Reduced cognitive load for developers
- More modular, reusable code

## Risk Assessment

### Low Risk Refactors:
- Helper function introduction
- Message consolidation
- Directory operation helpers

### Higher Risk Refactors:
- Major function splitting
- Option parsing restructure
- Core workflow changes

## Testing Strategy

After each refactoring phase:
1. Run `./validate.sh` to ensure compliance
2. Run `./build.sh test` for functional validation
3. Test all primary workflows (build, install, deploy)
4. Verify no regression in functionality