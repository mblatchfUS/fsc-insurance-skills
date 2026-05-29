#!/bin/bash
# Check if an FSC Insurance org has the full pricing pipeline configured
# Usage: ./check-pricing-pipeline.sh <org-alias>

set -e

ORG_ALIAS="${1:-}"

if [ -z "$ORG_ALIAS" ]; then
  echo "Usage: $0 <org-alias>"
  echo "Example: $0 DigInsTrialOrgMay2026"
  exit 1
fi

echo "🔍 Checking pricing pipeline for org: $ORG_ALIAS"
echo ""

# 1. Check if runSalesforcePricing standard action is exposed
echo "1️⃣  Checking runSalesforcePricing standard action..."
PRICING_ACTION=$(sf data query --query "SELECT Id, Name, MasterLabel FROM FlowActionDefinition WHERE DeveloperName='runSalesforcePricing' LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Found' if d.get('result',{}).get('totalSize',0) > 0 else '❌ Missing')")
echo "$PRICING_ACTION"

# 2. Check ExpressionSetDefinition framework
echo ""
echo "2️⃣  Checking ExpressionSetDefinition framework..."
ESD_COUNT=$(sf data query --query "SELECT COUNT() FROM ExpressionSetDefinition" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('records',[{}])[0].get('expr0',0))")
echo "✅ $ESD_COUNT pricing procedures found"

# 3. Check CalculationMatrix framework
echo ""
echo "3️⃣  Checking CalculationMatrix framework..."
CM_COUNT=$(sf data query --query "SELECT COUNT() FROM CalculationMatrix" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('records',[{}])[0].get('expr0',0))")
echo "✅ $CM_COUNT calculation matrices found"

# 4. Check PricingProcessExecution (evidence of pricing runs)
echo ""
echo "4️⃣  Checking PricingProcessExecution history..."
PPE_COUNT=$(sf data query --query "SELECT COUNT() FROM PricingProcessExecution" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('records',[{}])[0].get('expr0',0))")
if [ "$PPE_COUNT" -gt 0 ]; then
  echo "✅ $PPE_COUNT pricing executions recorded (pricing has run successfully)"
else
  echo "⚠️  No pricing executions yet (pricing may not be configured or has never run)"
fi

# 5. Check Standard Pricebook
echo ""
echo "5️⃣  Checking Standard Pricebook..."
STD_PB=$(sf data query --query "SELECT Id, Name FROM Pricebook2 WHERE IsStandard=true LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print('✅ Found: ' + r[0]['Id'] if r else '❌ Missing')")
echo "$STD_PB"

# 6. Check TransactionProcessingTypes
echo ""
echo "6️⃣  Checking TransactionProcessingTypes..."
TPT_COUNT=$(sf data query --query "SELECT COUNT() FROM TransactionProcessingType" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('records',[{}])[0].get('expr0',0))")
echo "✅ $TPT_COUNT TransactionProcessingTypes found"

# 7. Check enablePCMConfigRules setting
echo ""
echo "7️⃣  Checking enablePCMConfigRules setting..."
PCM_ENABLED=$(sf data query --query "SELECT SettingValue FROM OrganizationSettingsDetail WHERE SettingName='PCMConfigRulesEnabled' LIMIT 1" --target-org "$ORG_ALIAS" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('result',{}).get('records',[]); print('✅ Enabled' if r and r[0].get('SettingValue')=='true' else '❌ Disabled (MAIN BLOCKER for pricing)')")
echo "$PCM_ENABLED"

echo ""
echo "✅ Pipeline check complete for $ORG_ALIAS"
