#!/usr/bin/env bash
# build.sh - Assemble script from numbered modular parts (enhanced with build.map)

set -euo pipefail

# Colors for output
readonly green=$'\033[32m';
readonly blue=$'\033[34m';
readonly yellow=$'\033[33m';
readonly red=$'\033[31m';
readonly x=$'\033[38;5;244m';

# Configuration
PARTS_DIR="parts";
OUTPUT_FILE="padlock.sh";
BUILD_MAP="parts/build.map";
USE_BUILD_MAP=false;

# Read build map if it exists
declare -A build_map_targets=()
read_build_map() {
    if [[ ! -f "$BUILD_MAP" ]]; then
        return 1
    fi
    
    printf "%sReading build map: %s%s\n" "$blue" "$BUILD_MAP" "$x"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Parse: NN : target_filename.sh
        if [[ "$line" =~ ^([0-9]+)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local target="${BASH_REMATCH[2]// /}"  # Remove spaces
            build_map_targets["$num"]="$target"
            printf "  %s%s%s → %s\n" "$green" "$num" "$x" "$target"
        fi
    done < "$BUILD_MAP"
    
    if [[ ${#build_map_targets[@]} -gt 0 ]]; then
        USE_BUILD_MAP=true
        return 0
    else
        printf "%sWARN:%s No valid mappings found in %s\n" "$yellow" "$x" "$BUILD_MAP"
        return 1
    fi
}

# Rename files according to build map
rename_from_build_map() {
    if [[ "$USE_BUILD_MAP" != true ]]; then
        return 0
    fi
    
    printf "\n%sRenaming files according to build map...%s\n" "$yellow" "$x"
    
    # 1. Get all .sh files in parts directory
    local all_files=()
    while IFS= read -r -d '' file; do
        all_files+=("$(basename "$file")")
    done < <(find "$PARTS_DIR" -name "*.sh" -print0)

    # 2. Get all target filenames from build.map
    local target_files=()
    for target in "${build_map_targets[@]}"; do
        target_files+=("$target")
    done

    # 3. Create a list of unprocessed files by filtering out correct ones
    local unprocessed_files=()
    local correct_files=()
    for file in "${all_files[@]}"; do
        local is_target=false
        for target in "${target_files[@]}"; do
            if [[ "$file" == "$target" ]]; then
                is_target=true
                correct_files+=("$file")
                break
            fi
        done
        if [[ "$is_target" == false ]]; then
            unprocessed_files+=("$file")
        fi
    done

    if [[ ${#correct_files[@]} -gt 0 ]]; then
        printf "  Found %d correctly named file(s): %s\n" "${#correct_files[@]}" "${correct_files[*]}"
    fi
    if [[ ${#unprocessed_files[@]} -gt 0 ]]; then
        printf "  Found %d unprocessed file(s) to rename: %s\n" "${#unprocessed_files[@]}" "${unprocessed_files[*]}"
    fi

    # 4. Process the unprocessed files
    for file in "${unprocessed_files[@]}"; do
        # Extract number from filename.
        local num
        if ! num=$(echo "$file" | grep -oE '[0-9]+'); then
            printf "  %sWARN:%s Could not extract number from '%s', skipping.\n" "$yellow" "$x" "$file"
            continue
        fi
        
        # We might get multiple numbers, take the first one.
        num=$(echo "$num" | head -n1)
        # Format to 2 digits (e.g., 3 -> 03)
        printf -v num "%02d" "$num"

        if [[ -n "${build_map_targets[$num]}" ]]; then
            local target="${build_map_targets[$num]}"
            local source_path="$PARTS_DIR/$file"
            local target_path="$PARTS_DIR/$target"
            printf "  %s✓%s Renaming %s → %s\n" "$green" "$x" "$file" "$target"
            mv "$source_path" "$target_path"
        else
            printf "  %sWARN:%s No target in build.map for number '%s' (from file '%s'), skipping.\n" "$yellow" "$x" "$num" "$file"
        fi
    done

    # 5. Cleanup: Get a fresh list of files and remove any not in the build map targets.
    printf "\n%sCleaning up artifacts...%s\n" "$yellow" "$x"
    local final_files=()
    while IFS= read -r -d '' file; do
        final_files+=("$(basename "$file")")
    done < <(find "$PARTS_DIR" -name "*.sh" -print0)

    for file in "${final_files[@]}"; do
        local is_target=false
        for target in "${target_files[@]}"; do
            if [[ "$file" == "$target" ]]; then
                is_target=true
                break
            fi
        done
        if [[ "$is_target" == false ]]; then
            # As a safeguard, only remove files with numbers in them
            if [[ "$file" =~ [0-9] ]]; then
                printf "  %s🗑%s  Removing artifact: %s\n" "$red" "$x" "$file"
                rm -f "$PARTS_DIR/$file"
            fi
        fi
    done
    
    printf "\n%s✓ Rename complete!%s\n" "$green" "$x"
}

# Resolve module path (simple name vs full path)
resolve_module_path() {
    local module="$1"
    if [[ "$module" == *"/"* ]]; then
        echo "$module"  # Has path separators - use as-is
    else
        echo "$PARTS_DIR/$module.sh"  # Simple name - add default path/extension
    fi
}

# Validate insert parameters
validate_insert() {
    local source_file="$1"
    local position="$2"
    
    # Validate position is numeric
    if ! [[ "$position" =~ ^[0-9]+$ ]]; then
        printf "%sERROR:%s Position must be numeric (got: %s)\n" "$red" "$x" "$position" >&2
        return 1
    fi
    
    # Extract filename for validation
    local basename_only=$(basename "$source_file" .sh)
    
    # Filename cannot start with number
    if [[ "$basename_only" =~ ^[0-9] ]]; then
        printf "%sERROR:%s Module filename cannot start with a number\n" "$red" "$x" >&2
        printf "       File: %s\n" "$source_file" >&2
        printf "       Use descriptive names like 'boxy', 'logging', 'utils'\n" >&2
        return 1
    fi
    
    # Check source file exists
    if [[ ! -f "$source_file" ]]; then
        printf "%sERROR:%s Source file not found: %s\n" "$red" "$x" "$source_file" >&2
        return 1
    fi
    
    # Verify parts directory exists
    if [[ ! -d "$PARTS_DIR" ]]; then
        printf "%sERROR:%s Parts directory not found: %s\n" "$red" "$x" "$PARTS_DIR" >&2
        return 1
    fi
    
    return 0
}

# Renumber existing files at position and higher
renumber_files() {
    local position="$1"
    
    printf "%sRenumbering existing files from position %02d...\n%s" "$yellow" "$position" "$x"
    
    # Get list of files to renumber (in reverse order to avoid conflicts)
    local files_to_rename=()
    for file in "$PARTS_DIR"/*.sh; do
        [[ -f "$file" ]] || continue
        local basename_file=$(basename "$file")
        if [[ "$basename_file" =~ ^([0-9]+)_ ]]; then
            local file_num="${BASH_REMATCH[1]}"
            # Remove leading zeros for comparison
            local file_num_int=$((10#$file_num))
            local position_int=$((10#$position))
            if [[ $file_num_int -ge $position_int ]]; then
                files_to_rename+=("$file")
            fi
        fi
    done
    
    # Sort in reverse order to avoid conflicts
    IFS=$'\n' files_to_rename=($(sort -r <<<"${files_to_rename[*]}"))
    
    # Rename files
    for file in "${files_to_rename[@]}"; do
        local basename_file=$(basename "$file")
        if [[ "$basename_file" =~ ^([0-9]+)_(.+)$ ]]; then
            local old_num="${BASH_REMATCH[1]}"
            local suffix="${BASH_REMATCH[2]}"
            local new_num=$((10#$old_num + 1))
            local new_file="$PARTS_DIR/$(printf '%02d_%s' $new_num $suffix)"
            
            printf "  %s%02d_%s%s → %s%02d_%s%s\n" "$green" "$((10#$old_num))" "$suffix" "$x" "$green" "$new_num" "$suffix" "$x"
            mv "$file" "$new_file" || {
                printf "%sERROR:%s Failed to rename %s\n" "$red" "$x" "$file" >&2
                return 1
            }
        fi
    done
    
    return 0
}

# Update build map with new numbering
update_build_map() {
    local position="$1"
    local new_module_name="$2"
    
    if [[ ! -f "$BUILD_MAP" ]]; then
        printf "%sCreating new build map: %s\n%s" "$blue" "$BUILD_MAP" "$x"
        cat > "$BUILD_MAP" << EOF
# Build Map - Generated by build.sh insert
# Format: NN : target_filename.sh
EOF
    fi
    
    printf "%sUpdating build map...\n%s" "$yellow" "$x"
    
    # Read existing map into array
    declare -A map_entries=()
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        if [[ "$line" =~ ^([0-9]+)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local target="${BASH_REMATCH[2]// /}"
            map_entries["$num"]="$target"
        fi
    done < "$BUILD_MAP"
    
    # Update entries >= position
    declare -A new_map=()
    for num in "${!map_entries[@]}"; do
        local num_int=$((10#$num))
        local pos_int=$((10#$position))
        if [[ $num_int -ge $pos_int ]]; then
            local new_num=$((num_int + 1))
            new_map["$(printf '%02d' $new_num)"]="${map_entries[$num]}"
        else
            new_map["$num"]="${map_entries[$num]}"
        fi
    done
    
    # Add new entry
    new_map["$(printf '%02d' $((10#$position)))"]="$(printf '%02d_%s.sh' $((10#$position)) $new_module_name)"
    
    # Write updated map
    {
        echo "# Build Map - Updated by build.sh insert"
        echo "# Format: NN : target_filename.sh"
        echo
        for num in $(printf '%s\n' "${!new_map[@]}" | sort -n); do
            printf '%s : %s\n' "$num" "${new_map[$num]}"
        done
    } > "$BUILD_MAP"
    
    printf "  %sUpdated %s with new numbering\n%s" "$green" "$BUILD_MAP" "$x"
    return 0
}

# Main insert function
insert_module() {
    local module="$1"
    local position="$2"
    
    printf "%sInserting module at position %02d...\n%s" "$blue" "$((10#$position))" "$x"
    
    # Resolve source path
    local source_file
    source_file=$(resolve_module_path "$module")
    
    # Validate inputs
    validate_insert "$source_file" "$position" || return 1
    
    # Extract module name for target file
    local module_name=$(basename "$source_file" .sh)
    local target_file="$PARTS_DIR/$(printf '%02d_%s.sh' $((10#$position)) $module_name)"
    
    # Check if target position already exists
    if [[ -f "$target_file" ]]; then
        printf "%sWARN:%s Position %02d already exists, will be renumbered\n" "$yellow" "$x" "$((10#$position))"
    fi
    
    # Renumber existing files
    renumber_files "$position" || return 1
    
    # Copy/move source to target position
    printf "%sCopying %s → %s\n%s" "$green" "$source_file" "$target_file" "$x"
    cp "$source_file" "$target_file" || {
        printf "%sERROR:%s Failed to copy module to target position\n" "$red" "$x" >&2
        return 1
    }
    
    # Update build map
    update_build_map "$position" "$module_name" || return 1
    
    printf "\n%s✓ Insert complete!%s Module '%s' inserted at position %02d\n" "$green" "$x" "$module_name" "$((10#$position))"
    printf "%s  Next:%s Run './build.sh' to build with new module\n" "$blue" "$x"
    
    return 0
}

# Validate swap parameters
validate_swap() {
    local pos1="$1"
    local pos2="$2"
    
    # Validate both positions are numeric
    if ! [[ "$pos1" =~ ^[0-9]+$ ]]; then
        printf "%sERROR:%s Position 1 must be numeric (got: %s)\n" "$red" "$x" "$pos1" >&2
        return 1
    fi
    if ! [[ "$pos2" =~ ^[0-9]+$ ]]; then
        printf "%sERROR:%s Position 2 must be numeric (got: %s)\n" "$red" "$x" "$pos2" >&2
        return 1
    fi
    
    # Can't swap same position
    if [[ "$pos1" == "$pos2" ]]; then
        printf "%sERROR:%s Cannot swap position with itself (%s)\n" "$red" "$x" "$pos1" >&2
        return 1
    fi
    
    # Verify parts directory exists
    if [[ ! -d "$PARTS_DIR" ]]; then
        printf "%sERROR:%s Parts directory not found: %s\n" "$red" "$x" "$PARTS_DIR" >&2
        return 1
    fi
    
    return 0
}

# Find module at specific position
find_module_at_position() {
    local position="$1"
    local pos_formatted=$(printf '%02d' $((10#$position)))
    
    for file in "$PARTS_DIR"/${pos_formatted}_*.sh; do
        if [[ -f "$file" ]]; then
            echo "$(basename "$file")"
            return 0
        fi
    done
    
    return 1
}

# Update build map for swap
update_build_map_swap() {
    local pos1="$1"
    local pos2="$2"
    local module1="$3"
    local module2="$4"
    
    if [[ ! -f "$BUILD_MAP" ]]; then
        printf "%sCreating new build map: %s\n%s" "$blue" "$BUILD_MAP" "$x"
        cat > "$BUILD_MAP" << EOF
# Build Map - Generated by build.sh swap
# Format: NN : target_filename.sh
EOF
    fi
    
    printf "%sUpdating build map for swap...\n%s" "$yellow" "$x"
    
    # Read existing map into array
    declare -A map_entries=()
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        if [[ "$line" =~ ^([0-9]+)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local target="${BASH_REMATCH[2]// /}"
            map_entries["$num"]="$target"
        fi
    done < "$BUILD_MAP"
    
    # Swap the entries
    map_entries["$(printf '%02d' $((10#$pos1)))"]="$module2"
    map_entries["$(printf '%02d' $((10#$pos2)))"]="$module1"
    
    # Write updated map
    {
        echo "# Build Map - Updated by build.sh swap"
        echo "# Format: NN : target_filename.sh"
        echo
        for num in $(printf '%s\n' "${!map_entries[@]}" | sort -n); do
            printf '%s : %s\n' "$num" "${map_entries[$num]}"
        done
    } > "$BUILD_MAP"
    
    printf "  %sUpdated %s with swapped positions\n%s" "$green" "$BUILD_MAP" "$x"
    return 0
}

# Main swap function  
swap_positions() {
    local pos1="$1"
    local pos2="$2"
    
    printf "%sSwapping positions %02d ↔ %02d...\n%s" "$blue" "$((10#$pos1))" "$((10#$pos2))" "$x"
    
    # Validate inputs
    validate_swap "$pos1" "$pos2" || return 1
    
    # Find modules at both positions
    local module1 module2
    module1=$(find_module_at_position "$pos1")
    if [[ $? -ne 0 ]]; then
        printf "%sERROR:%s No module found at position %02d\n" "$red" "$x" "$((10#$pos1))" >&2
        return 1
    fi
    
    module2=$(find_module_at_position "$pos2")  
    if [[ $? -ne 0 ]]; then
        printf "%sERROR:%s No module found at position %02d\n" "$red" "$x" "$((10#$pos2))" >&2
        return 1
    fi
    
    local file1="$PARTS_DIR/$module1"
    local file2="$PARTS_DIR/$module2"
    
    printf "%s%s%s ↔ %s%s%s\n" "$green" "$module1" "$x" "$green" "$module2" "$x"
    
    # Extract module names (without position prefix)
    local name1=$(echo "$module1" | sed 's/^[0-9]*_//')
    local name2=$(echo "$module2" | sed 's/^[0-9]*_//')
    
    # Create new filenames with swapped positions
    local new_file1="$PARTS_DIR/$(printf '%02d_%s' $((10#$pos2)) $name1)"
    local new_file2="$PARTS_DIR/$(printf '%02d_%s' $((10#$pos1)) $name2)"
    
    # Perform the swap using temp file
    local temp_file=$(mktemp)
    
    printf "%sPerforming swap...\n%s" "$yellow" "$x"
    
    mv "$file1" "$temp_file" || {
        printf "%sERROR:%s Failed to create temporary file\n" "$red" "$x" >&2
        rm -f "$temp_file"
        return 1
    }
    
    mv "$file2" "$new_file1" || {
        printf "%sERROR:%s Failed to move %s\n" "$red" "$x" "$file2" >&2
        mv "$temp_file" "$file1"  # Restore original
        rm -f "$temp_file"
        return 1
    }
    
    mv "$temp_file" "$new_file2" || {
        printf "%sERROR:%s Failed to move temp file\n" "$red" "$x" >&2
        # Try to restore both files
        mv "$new_file1" "$file2" 2>/dev/null
        mv "$temp_file" "$file1" 2>/dev/null
        return 1
    }
    
    # Update build map
    update_build_map_swap "$pos1" "$pos2" "$(basename "$new_file1")" "$(basename "$new_file2")" || return 1
    
    printf "\n%s✓ Swap complete!%s Positions %02d and %02d have been swapped\n" "$green" "$x" "$((10#$pos1))" "$((10#$pos2))"
    printf "%s  Next:%s Run './build.sh' to build with swapped modules\n" "$blue" "$x"
    
    return 0
}

main() {
    printf "%sBuilding script from numbered modular parts%s\n" "$blue" "$x";
    printf "Parts directory: %s\n" "$PARTS_DIR";
    printf "Output file: %s\n\n" "$OUTPUT_FILE";
    
    # Try to read build map
    if read_build_map; then
        printf "\n%sUsing build map for file discovery%s\n" "$green" "$x"
    else
        printf "%sNo build map found, using auto-discovery%s\n" "$yellow" "$x"
    fi
    
    # Verify parts directory exists
    if [[ ! -d "$PARTS_DIR" ]]; then
        printf "%sERROR:%s Parts directory '%s' not found\n" "$red" "$x" "$PARTS_DIR" >&2
        exit 1;
    fi
    
    # Auto-discover numbered modules in order
    local modules=()
    if [[ "$USE_BUILD_MAP" == true ]]; then
        # Use build map for discovery
        for num in $(printf '%s\n' "${!build_map_targets[@]}" | sort -n); do
            local target="${build_map_targets[$num]}"
            if [[ -f "$PARTS_DIR/$target" ]]; then
                modules+=("$target")
            else
                printf "%sERROR:%s Mapped file not found: %s\n" "$red" "$x" "$target" >&2
                exit 1
            fi
        done
    else
        # Original auto-discovery logic
        while IFS= read -r -d '' file; do
            local basename_file
            basename_file=$(basename "$file")
            # Check if file matches pattern: N+_*.sh (where N+ is 1+ digits)
            if [[ "$basename_file" =~ ^[0-9]+_.*\.sh$ ]]; then
                modules+=("$basename_file")
            fi
        done < <(find "$PARTS_DIR" -name "[0-9]*_*.sh" -print0 | sort -z)
    fi
    
    # Verify we found modules
    if [[ ${#modules[@]} -eq 0 ]]; then
        printf "%sERROR:%s No numbered modules found in %s\n" "$red" "$x" "$PARTS_DIR" >&2
        if [[ "$USE_BUILD_MAP" != true ]]; then
            printf "Expected pattern: NN_name.sh (e.g., 01_header.sh, 02_colors.sh)\n" >&2
        fi
        exit 1
    fi
    
    printf "%sDiscovered %d modules:%s\n" "$green" "${#modules[@]}" "$x"
    for module in "${modules[@]}"; do
        local module_path="$PARTS_DIR/$module"
        if [[ -f "$module_path" ]]; then
            printf "%s✓%s %s\n" "$green" "$x" "$module"
        else
            printf "%s✗%s %s (missing)\n" "$red" "$x" "$module"
            exit 1
        fi
    done
    
    printf "\n%sAssembling modules in numeric order...%s\n" "$yellow" "$x"
    
    # Create header with generation info
    cat > "$OUTPUT_FILE" <<-EOF
			#!/usr/bin/env bash
			# Generated by build.sh on $(date)
			# Auto-assembled from numbered modules: ${modules[*]}
		EOF
    
    # Assemble modules in numeric order
    local first_module=true
    for module in "${modules[@]}"; do
        local module_path="$PARTS_DIR/$module"
        printf "  Adding: %s\n" "$module"
        
        # Add module separator comment
        echo "# === $module ===" >> "$OUTPUT_FILE"
        
        # Handle shebang: only include from first module
        if [[ "$first_module" == true ]]; then
            # Include everything from first module including shebang
            cat "$module_path" >> "$OUTPUT_FILE"
            first_module=false
        else
            # Skip shebang line from subsequent modules
            if head -1 "$module_path" | grep -q "^#!/"; then
                tail -n +2 "$module_path" >> "$OUTPUT_FILE"
            else
                # No shebang to skip
                cat "$module_path" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Add spacing between modules
        echo "" >> "$OUTPUT_FILE"
    done
    
    # Make executable
    chmod +x "$OUTPUT_FILE"
    
    printf "\n%s✓ Successfully assembled:%s %s\n" "$green" "$x" "$OUTPUT_FILE"
    
    # Quick syntax check
    printf "%sPerforming syntax check...%s\n" "$yellow" "$x"
    if bash -n "$OUTPUT_FILE"; then
        printf "%s✓ Syntax check passed%s\n" "$green" "$x"
    else
        printf "%s✗ Syntax errors detected%s\n" "$red" "$x" >&2
        exit 1
    fi
    
    # Show file info
    local line_count word_count
    line_count=$(wc -l < "$OUTPUT_FILE")
    word_count=$(wc -w < "$OUTPUT_FILE")
    
    printf "\n%sGenerated script info:%s\n" "$blue" "$x"
    printf "  Modules: %d\n" "${#modules[@]}"
    printf "  Lines: %s\n" "$line_count"
    printf "  Words: %s\n" "$word_count"
    printf "  Size: %s bytes\n" "$(wc -c < "$OUTPUT_FILE")"
    
    printf "\n%sReady for testing:%s\n" "$blue" "$x"
    printf "  Basic test: ./%s --help\n" "$OUTPUT_FILE"
    printf "  Syntax: bash -n %s\n" "$OUTPUT_FILE"
    
    printf "\n%s✓ Build complete!%s\n" "$green" "$x"
}

# Help function  
usage() {
    cat << EOF
build.sh - Assemble script from numbered modular parts (enhanced)

USAGE:
  ./build.sh [OPTIONS]

OPTIONS:
  -h, --help    Show this help
  -i MODULE POS Insert module at position (renumbers existing files)
  -s POS1 POS2  Swap two module positions
  -o FILE       Output file (default: padlock.sh)
  -p DIR        Parts directory (default: parts)
  -m FILE       Build map file (default: build.map)
  -r            Rename mode: rename source files according to build map
  -v            Verbose mode
  -c            Clean (remove output file before building)
  -l            List discovered modules and exit

EXAMPLES:
  ./build.sh                           # Build with defaults
  ./build.sh -i boxy 03                # Insert parts/boxy.sh at position 03
  ./build.sh -s 03 07                  # Swap positions 03 and 07
  ./build.sh -i ../utils/logging.sh 07 # Insert external file at position 07
  ./build.sh -o padlock.sh             # Custom output name
  ./build.sh -p modules -o script      # Custom parts dir and output
  ./build.sh -r                        # Rename source files using build.map
  ./build.sh -c                        # Clean build
  ./build.sh -l                        # List modules only

BUILD MAP:
  If build.map exists, it will be used to map source files to target names.
  Format: NN : target_filename.sh
  
  Example build.map:
    01 : 01_header.sh
    02 : 02_config.sh
    03 : 03_stderr.sh

INSERT MODE (-i):
  Inserts a module at the specified position, renumbering existing files.
  
  MODULE can be:
    - Simple name: looks for parts/MODULE.sh (e.g., 'boxy' → 'parts/boxy.sh')
    - Full path: uses exact path (e.g., '../common/logging.sh')
  
  All existing files at position POS and higher are renumbered by +1.
  The build.map is automatically updated.

SWAP MODE (-s):
  Swaps two modules at their current positions without affecting other files.
  
  Both positions must exist and contain modules.
  Only the two specified modules change positions - no cascade renumbering.
  The build.map is automatically updated with swapped positions.

RENAME MODE (-r):
  Renames downloaded artifacts (e.g., padlock_part_01.sh) to proper 
  numbered format (e.g., 01_header.sh) according to build.map.

MODULE NAMING:
  Modules must follow pattern: NN_name.sh
  Where NN is 2+ digit number (e.g., 01, 02, 99, 100)
EOF
}

# Parse arguments
list_only=false
rename_only=false
insert_mode=false
insert_module=""
insert_position=""
swap_mode=false
swap_pos1=""
swap_pos2=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        (-h|--help)
            usage
            exit 0
            ;;
        (-o)
            [[ $# -ge 2 ]] || { echo "ERROR: -o requires an argument" >&2; exit 1; }
            OUTPUT_FILE="$2"
            shift 2
            ;;
        (-p)
            [[ $# -ge 2 ]] || { echo "ERROR: -p requires an argument" >&2; exit 1; }
            PARTS_DIR="$2"
            shift 2
            ;;
        (-m)
            [[ $# -ge 2 ]] || { echo "ERROR: -m requires an argument" >&2; exit 1; }
            BUILD_MAP="$2"
            shift 2
            ;;
        (-i)
            [[ $# -ge 3 ]] || { echo "ERROR: -i requires MODULE and POSITION arguments" >&2; exit 1; }
            insert_mode=true
            insert_module="$2"
            insert_position="$3"
            shift 3
            ;;
        (-s)
            [[ $# -ge 3 ]] || { echo "ERROR: -s requires two POSITION arguments" >&2; exit 1; }
            swap_mode=true
            swap_pos1="$2"
            swap_pos2="$3"
            shift 3
            ;;
        (-r)
            rename_only=true
            shift
            ;;
        (-c)
            if [[ -f "$OUTPUT_FILE" ]]; then
                printf "%sCleaning:%s Removing existing %s\n" "$yellow" "$x" "$OUTPUT_FILE"
                rm -f "$OUTPUT_FILE"
            fi
            shift
            ;;
        (-l)
            list_only=true
            shift
            ;;
        (-v)
            set -x
            shift
            ;;
        (*)
            printf "%sERROR:%s Unknown option: %s\n" "$red" "$x" "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Insert mode: insert module and exit
if [[ "$insert_mode" == true ]]; then
    insert_module "$insert_module" "$insert_position"
    exit $?
fi

# Swap mode: swap two positions and exit
if [[ "$swap_mode" == true ]]; then
    swap_positions "$swap_pos1" "$swap_pos2"
    exit $?
fi

# Rename mode: just rename files and exit
if [[ "$rename_only" == true ]]; then
    if read_build_map; then
        rename_from_build_map
        printf "\n%s✓ Rename complete!%s\n" "$green" "$x"
    else
        printf "%sERROR:%s No valid build map found\n" "$red" "$x" >&2
        exit 1
    fi
    exit 0
fi

# List mode: just show discovered modules
if [[ "$list_only" == true ]]; then
    printf "%sDiscovering numbered modules in %s:%s\n\n" "$blue" "$PARTS_DIR" "$x"
    
    read_build_map || true  # Don't fail if no build map
    
    if [[ ! -d "$PARTS_DIR" ]]; then
        printf "%sERROR:%s Directory '%s' not found\n" "$red" "$x" "$PARTS_DIR" >&2
        exit 1
    fi
    
    modules=()
    if [[ "$USE_BUILD_MAP" == true ]]; then
        for num in $(printf '%s\n' "${!build_map_targets[@]}" | sort -n); do
            target="${build_map_targets[$num]}"
            if [[ -f "$PARTS_DIR/$target" ]]; then
                modules+=("$target")
            fi
        done
    else
        while IFS= read -r -d '' file; do
            local basename_file
            basename_file=$(basename "$file")
            if [[ "$basename_file" =~ ^[0-9]+_.*\.sh$ ]]; then
                modules+=("$basename_file")
            fi
        done < <(find "$PARTS_DIR" -name "[0-9]*_*.sh" -print0 | sort -z)
    fi
    
    if [[ ${#modules[@]} -eq 0 ]]; then
        printf "%sNo numbered modules found%s\n" "$yellow" "$x"
        printf "Expected pattern: NN_name.sh\n"
        exit 1
    fi
    
    printf "%sFound %d modules:%s\n" "$green" "${#modules[@]}" "$x"
    for i in "${!modules[@]}"; do
        printf "%3d. %s\n" $((i+1)) "${modules[$i]}"
    done
    
    exit 0
fi

main "$@"
