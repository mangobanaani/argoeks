#!/usr/bin/env sh
set -eu

# Find module directories (have main.tf under terraform/modules)
modules=$(find terraform/modules -type f -name 'main.tf' -print | sed 's#/main.tf$##' | sort -u)

created_outputs=0
created_readmes=0

for m in $modules; do
  # Ensure outputs.tf exists (do not duplicate existing outputs from main.tf)
  if [ ! -f "$m/outputs.tf" ]; then
    cat > "$m/outputs.tf" <<'EOF'
# outputs.tf
# Standardized outputs placeholder.
# TODO: Move any existing output blocks from main.tf into this file.
EOF
    created_outputs=$((created_outputs+1))
  fi

  # Ensure README.md exists (lightweight template)
  if [ ! -f "$m/README.md" ]; then
    mod_name=$(basename "$m")
    mod_rel=${m#terraform/modules/}
    cat > "$m/README.md" <<'EOF'
# ${mod_name}

Short description of ${mod_name}. Replace this paragraph with a clear summary of what the module does.

## Usage

```hcl
module "${mod_name}" {
  source = "../../modules/${mod_rel}"
  # TODO: add required variables
}
```

## Inputs

- See `variables.tf`. Consider running terraform-docs to render detailed inputs/outputs.

## Outputs

- See `outputs.tf`.

## Notes

- This README was generated as part of the standardization effort on 2026-01-01.
EOF
    created_readmes=$((created_readmes+1))
  fi
done

echo "Created outputs.tf: $created_outputs"
echo "Created README.md: $created_readmes"
