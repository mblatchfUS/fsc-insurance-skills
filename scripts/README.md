# FSC Insurance Build Scripts

Reusable shell scripts for validating and building FSC Insurance products.

## Prerequisites

- Salesforce CLI v2 (`sf`)
- Python 3 (for JSON parsing)
- Authenticated to target org via `sf org login web`

## Scripts

### `check-pricing-pipeline.sh`

Validates that an org has the full pricing pipeline infrastructure.

**Usage:**
```bash
./check-pricing-pipeline.sh <org-alias>
```

**Checks:**
- ✅ runSalesforcePricing standard action
- ✅ ExpressionSetDefinition framework (pricing procedures)
- ✅ CalculationMatrix framework (decision tables)
- ⚠️  PricingProcessExecution history (evidence of pricing runs)
- ✅ Standard Pricebook
- ✅ TransactionProcessingTypes
- ❌ enablePCMConfigRules setting (main blocker if disabled)

**Example:**
```bash
./check-pricing-pipeline.sh DigInsTrialOrgMay2026

🔍 Checking pricing pipeline for org: DigInsTrialOrgMay2026

1️⃣  Checking runSalesforcePricing standard action...
✅ Found

2️⃣  Checking ExpressionSetDefinition framework...
✅ 12 pricing procedures found

...

7️⃣  Checking enablePCMConfigRules setting...
❌ Disabled (MAIN BLOCKER for pricing)
```

---

### `discover-org-ids.sh`

Discovers org-specific record IDs that vary between orgs.

**Usage:**
```bash
source <(./discover-org-ids.sh <org-alias>)
```

**Exports:**
- `STANDARD_PRICEBOOK_ID`
- `ROOT_PRODUCT_RT_ID`
- `COVERAGE_RT_ID`
- `BUNDLE_PRODUCT_PRT_ID`
- `BUNDLE_CLASS_PRT_ID`
- `INSURANCE_CATALOG_ID`
- `ADVANCED_TPT_ID`
- `DEFAULT_RECIPE_ID`

**Example:**
```bash
source <(./discover-org-ids.sh DigInsTrialOrgMay2026)
echo $ROOT_PRODUCT_RT_ID
# Output: 012fn000001YrXXAAA

# Use in subsequent commands:
sf data create record --sobject Product2 \
  --values "Name='My Product' RecordTypeId=$ROOT_PRODUCT_RT_ID" \
  --target-org DigInsTrialOrgMay2026
```

---

## Making Scripts Executable

```bash
chmod +x scripts/*.sh
```

## Tips

1. **Always discover IDs at runtime** — never hardcode org-specific IDs in scripts
2. **Source discover-org-ids.sh** before running product creation scripts
3. **Run check-pricing-pipeline.sh** first to validate org readiness
4. **Check enablePCMConfigRules** — if disabled, pricing will return $0
