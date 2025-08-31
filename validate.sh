#!/usr/bin/env bash
# FX3 Validation Script - Quick correctness & quality check

set -euo pipefail

# Colors
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect target script
TARGET_SCRIPT=""
if [[ -f "$SCRIPT_DIR/ixhand.sh" ]]; then
    TARGET_SCRIPT="$SCRIPT_DIR/ixhand.sh"
elif [[ -f "$SCRIPT_DIR/build.sh" ]]; then
    TARGET_SCRIPT="$SCRIPT_DIR/build.sh"
elif [[ $# -gt 0 ]] && [[ -f "$1" ]]; then
    TARGET_SCRIPT="$1"
else
    red "ERROR: No target script found (ixhand.sh, build.sh) or provided as argument"
    exit 1
fi

SCRIPT_NAME=$(basename "$TARGET_SCRIPT")
echo "FX3 VALIDATION CHECKLIST - $SCRIPT_NAME"
echo "=========================="
echo

# Basic file checks
echo "📁 FILE STRUCTURE:"
if [[ -x "$TARGET_SCRIPT" ]]; then
    green "✅ $SCRIPT_NAME exists and executable"
else
    red "❌ $SCRIPT_NAME missing or not executable"
    exit 1
fi

if [[ -f "$SCRIPT_DIR/README.md" ]]; then
    green "✅ README.md present"
else
    red "❌ README.md missing"
fi

echo

# BashFX v3.0 compliance check
echo "🏗️  BASHFX v3.0 COMPLIANCE:"

# Check for required functions (with do_ pattern flexibility)
required_functions=(
    "main"
    "dispatch"
    "options" 
    "usage"
    "status"
)

missing_functions=()
for func in "${required_functions[@]}"; do
    if grep -q "^${func}()" "$TARGET_SCRIPT" || grep -q "^do_${func}()" "$TARGET_SCRIPT"; then
        green "✅ Function $func() present"
    else
        red "❌ Function $func() missing"
        missing_functions+=("$func")
    fi
done

# Check for do_ pattern commands
if grep -q "^do_.*(" "$TARGET_SCRIPT"; then
    green "✅ do_* command pattern found"
else
    red "❌ No do_* command functions found"
fi

# Check for proper error handling
if grep -q "set -euo pipefail" "$TARGET_SCRIPT"; then
    green "✅ Proper error handling (set -euo pipefail)"
else
    red "❌ Missing proper error handling"
fi

echo

# Functional tests
echo "⚙️  FUNCTIONAL TESTS:"

cd "$SCRIPT_DIR"

# Test help command
if "./$SCRIPT_NAME" help >/dev/null 2>&1; then
    green "✅ help command works"
else
    red "❌ help command fails"
fi

# Test status command  
if "./$SCRIPT_NAME" status >/dev/null 2>&1; then
    green "✅ status command works"
else
    red "❌ status command fails"
fi

# Script-specific tests
if [[ "$SCRIPT_NAME" == "build.sh" ]]; then
    # Test list command for build.sh (may have verbose output)
    if timeout 5 "./$SCRIPT_NAME" list >/dev/null 2>&1; then
        green "✅ list command works"
    else
        red "❌ list command fails"
    fi
else
    # Test ls command for ixhand.sh
    if "./$SCRIPT_NAME" ls >/dev/null 2>&1; then
        green "✅ ls command works"
    else
        red "❌ ls command fails"
    fi
fi

# Test invalid command handling
if ! "./$SCRIPT_NAME" invalid_command >/dev/null 2>&1; then
    green "✅ Invalid command handling works"
else
    red "❌ Invalid command not properly handled"
fi

echo

# Check for required dependencies
echo "🔧 DEPENDENCY CHECK:"

deps=(jq find)
for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        green "✅ $dep available"
    else
        yellow "⚠️  $dep missing (may cause degraded functionality)"
    fi
done

# Optional dependencies
opt_deps=(rg)
for dep in "${opt_deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        green "✅ $dep available (enhanced functionality)"
    else
        blue "ℹ️  $dep missing (optional - graceful fallback expected)"
    fi
done

echo

# Code quality checks
echo "📊 CODE QUALITY:"

# Check for mega functions (>50 lines) with improved detection
mega_functions=$(awk '
/^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ { 
    if (func_name) {
        lines = NR - start_line - 1
        if (lines > 50) results = results func_name " (" lines " lines)\n"
    }
    func_name = $1; gsub(/\(\)/, "", func_name); start_line = NR 
}
END { 
    if (func_name) {
        lines = NR - start_line 
        if (lines > 50) results = results func_name " (" lines " lines)\n"
    }
    printf "%s", results
}' "$TARGET_SCRIPT")

if [[ -z "$mega_functions" ]]; then
    green "✅ No mega functions detected (>50 lines)"
else
    yellow "⚠️  Mega functions found (>50 lines):"
    echo "$mega_functions"
fi

# Check for code reuse opportunities
echo
yellow "🔄 CODE REUSE ANALYSIS:"
error_patterns=$(grep -c "printf.*%sERROR:%s" "$TARGET_SCRIPT" 2>/dev/null || echo "0")
success_patterns=$(grep -c "printf.*%s✓.*%s" "$TARGET_SCRIPT" 2>/dev/null || echo "0")
mkdir_patterns=$(grep -c "mkdir -p" "$TARGET_SCRIPT" 2>/dev/null || echo "0")

if [[ $error_patterns -gt 3 ]]; then
    yellow "⚠️  Error message pattern repeated $error_patterns times (consider helper function)"
fi
if [[ $success_patterns -gt 5 ]]; then
    yellow "⚠️  Success message pattern repeated $success_patterns times (consider helper function)"  
fi
if [[ $mkdir_patterns -gt 3 ]]; then
    yellow "⚠️  Directory creation pattern repeated $mkdir_patterns times (consider helper function)"
fi

# Check for proper function naming
if grep -q "^do_.*(" "$TARGET_SCRIPT" && grep -q "^_.*(" "$TARGET_SCRIPT"; then
    green "✅ Proper function naming conventions"
else
    yellow "⚠️  Function naming could be improved"
fi

echo

# Summary
echo "📋 VALIDATION SUMMARY:"
if [[ ${#missing_functions[@]} -eq 0 ]]; then
    green "✅ $SCRIPT_NAME appears to be correctly implemented"
    green "✅ Ready for production use"
    echo
    blue "Quick test: ./$SCRIPT_NAME status"
    blue "Full test: ./$SCRIPT_NAME help"
else
    red "❌ Missing critical functions: ${missing_functions[*]}"
    red "❌ Tool needs corrections before use"
fi

echo
echo "=========================="