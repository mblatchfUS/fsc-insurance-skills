#!/bin/bash
# Discover org-specific IDs needed for insurance product builds
# Usage: ./discover-org-ids.sh <org-alias>
# Outputs shell variable exports you can source

set -e

ORG_ALIAS="${1:-}"

if [ -z "$ORG_ALIAS" ]; then
  echo "Usage: $0 <org-alias>"
  echo "Example: $0 DigInsTrialOrgMay2026"
  exit 1
fi

echo "# Discovered org IDs for: $ORG_ALIAS" >&2
echo "# Source this output to set env vars:" >&2
echo "# source <(./discover-org-ids.sh MyOrgAlias)" >&2
echo "" >&2

# 1. Standard Pricebook
STD_PB_ID=$(sf data query --query "SELECT Id FROM Pricebook2 WHERE IsStandard=true LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export STANDARD_PRICEBOOK_ID='$STD_PB_ID'"

# 2. Root Product RecordType
ROOT_RT_ID=$(sf data query --query "SELECT Id, DeveloperName FROM RecordType WHERE SobjectType='Product2' AND (DeveloperName='Commercial' OR DeveloperName='Root_Product' OR DeveloperName='root_product') LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export ROOT_PRODUCT_RT_ID='$ROOT_RT_ID'"

# 3. Coverage RecordType
COVERAGE_RT_ID=$(sf data query --query "SELECT Id FROM RecordType WHERE SobjectType='Product2' AND DeveloperName='Coverage' LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export COVERAGE_RT_ID='$COVERAGE_RT_ID'"

# 4. ProductRelationshipType for Bundle to Product
BUNDLE_PRODUCT_PRT_ID=$(sf data query --query "SELECT Id FROM ProductRelationshipType WHERE Name='Bundle to Product' OR Name='Bundle to product' LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export BUNDLE_PRODUCT_PRT_ID='$BUNDLE_PRODUCT_PRT_ID'"

# 5. ProductRelationshipType for Bundle to Product Classification
BUNDLE_CLASS_PRT_ID=$(sf data query --query "SELECT Id FROM ProductRelationshipType WHERE Name='Bundle to Product Classification Component' LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export BUNDLE_CLASS_PRT_ID='$BUNDLE_CLASS_PRT_ID'"

# 6. Insurance Catalog
INSURANCE_CATALOG_ID=$(sf data query --query "SELECT Id FROM ProductCatalog WHERE Name='Insurance' OR Name='Insurance Catalog' LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export INSURANCE_CATALOG_ID='$INSURANCE_CATALOG_ID'"

# 7. Default TransactionProcessingType (AdvancedTransaction)
ADVANCED_TPT_ID=$(sf data query --query "SELECT Id FROM TransactionProcessingType WHERE Name='Advanced Transaction' OR Name='AdvancedTransaction' LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export ADVANCED_TPT_ID='$ADVANCED_TPT_ID'"

# 8. Default Pricing Recipe
DEFAULT_RECIPE_ID=$(sf data query --query "SELECT Id FROM PricingRecipe WHERE Name='NGPDefaultRecipe' OR IsDefault=true LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print(r[0]['Id'] if r else '')")
echo "export DEFAULT_RECIPE_ID='$DEFAULT_RECIPE_ID'"

echo "" >&2
echo "✅ Org IDs discovered. Source this output to use in scripts." >&2
