---
name: creating-insurance-product
description: Creates a Salesforce FSC Insurance product bundle with working end-to-end pricing (product structure + configurator + pricing procedure + Quote Record Page). Use when someone wants to create a new insurance product, line of business, or coverage structure in an FSC Insurance org.
compatibility: Salesforce CLI (sf) v2+, FSC Insurance / Digital Insurance orgs
metadata:
  version: "4.0"
  reference_working_org: Gartner/Celent 2026 (Commercial Property — multi-level rollup pricing)
  reference_pattern: CPPerilCoveragesPricingProcedure + CPBaseCoveragesPricingProcedure
  reference_trial_org: DigInsTrialOrgMay2026 (fresh trial — end-to-end build validated through v4)
---

## Build principles

These rules apply to every insurance product / pricing build. Get them wrong and the work won't transfer to other FSC orgs.

1. **Build only on standard Salesforce sObjects and fields.** No custom (`__c`) fields on standard objects unless absolutely required. `__c` suffixes inside CalculationMatrix column names and pricing-procedure variable names are fine — those are metadata-internal labels, not real custom fields. Stylistically match what the working reference org uses.
2. **No managed-package namespaces.** Especially **no `vlocity_*`** — that's the legacy package being phased out.
3. **Field-shape varies by org schema version.** Check what the target org actually has via `sf sobject describe` before assuming a field exists. Examples encountered in fresh orgs vs. mature orgs:
   - `Product2.ProductPurpose` exists in some orgs (e.g., AJG-Clements with extra packages) but **NOT in stock FSC Insurance orgs (Gartner/Celent, fresh trials)**. Don't set it.
   - `AttributePicklist.Code` field doesn't exist in some orgs — drop it from creates.
   - `AttributePicklistValue.IsDefault` is required in newer schema versions — always set it (true on exactly one value, false on others).
   - `ProductSellingModelOption.IsDefault` is required in newer schema versions — set true.
4. **Verify the target org first** with `scripts/check-pricing-pipeline.sh <alias>` before deploying anything. Look for: `runSalesforcePricing` standard action exposed, ExpressionSetDefinition framework queryable, CalculationMatrix framework queryable, PricingProcessExecution queryable, Standard Pricebook present.
5. **Never compare against AJG-Clements as a baseline.** That org is an internal demo with many added packages and `__c` fields; field counts and managed-Apex inventory there are noise. Compare against **Gartner/Celent 2026** for "what working FSC Insurance pricing looks like" or against a fresh trial org for "what stock FSC ships."
6. **Org IDs are never portable.** RecordType IDs, ProductRelationshipType IDs, AttributeDefinition IDs, ProductClassification IDs are **all unique per org**. Always discover them at runtime via `scripts/discover-org-ids.sh`, never hardcode in scripts. Use environment variable defaults so a single script can target any org.

---

## Overview

Insurance products in FSC Digital Insurance follow a bundle hierarchy:

```
Root Bundle (root product RecordType)
├── Standard Coverages Group (ProductComponentGroup)
│   ├── Built-in Coverage A (Coverage RT) — required, default
│   ├── Built-in Coverage B (Coverage RT) — required, default
│   └── Built-in Coverage C (Coverage RT) — required, default
├── Optional Coverages Group (ProductComponentGroup)
│   ├── Optional Coverage A (Coverage RT) — optional (ConfigureDuringSale=Allowed required on root)
│   └── Optional Coverage B (Coverage RT) — optional
└── Insured Item Group (ProductComponentGroup)
    └── → ProductClassification (e.g. Vehicle)
```

The root product RecordType is named differently in different orgs — `Commercial` in some, `Root_Product` in newer trials. Discover via `RecordType` SOQL on Product2.

All records are created via `sf data create record`. The reference scripts in this project are idempotent against env vars discovered at runtime — see "Build script convention" below.

---

## Master Build Sequence

The build has **two phases**: API-scriptable steps and UI-only steps. The order below is the correct dependency order. Steps marked **(UI)** cannot be done via API.

### Phase 1: Org Infrastructure (one-time per org)

These steps prepare the org's platform features. Do them once per fresh org, not per product.

| Step | Method | Description |
|------|--------|-------------|
| 1.1 | **(UI)** | Enable Quotes: Setup → Quotes Settings → Enable Quotes |
| 1.2 | **(UI)** | Enable Revenue Settings: Setup → Revenue Settings → Configure Products at Runtime |
| 1.3 | **(UI)** | Enable Constraint Rules Engine: Setup → Revenue Settings → Set Up Configuration Rules and Constraints with Constraint Rules Engine |
| 1.4 | **API** | Deploy `ConstraintEngineNodeStatus__c` custom field on QuoteLineItem (LongTextArea, length 5000) |
| 1.5 | **API** | Create TransactionProcessingType record (e.g., `AdvancedTransaction` with `RuleEngine=AdvancedConfigurator`) |
| 1.6 | **(UI)** | Assign permission sets: `Product Configurator`, `Product Configuration Constraints Designer` to the user |
| 1.7 | **(UI)** | Set up Product Discovery Settings: Setup → Product Discovery → set Default Catalog. Do NOT enable the Pricing Procedure toggle here (it requires a SalesTransactionContext-based procedure, not InsuranceContext) |
| 1.8 | **API** | Deploy Quote Record Page flexipage with `transactionLineTable` component and `dipAutoStatusIndicator` |
| 1.9 | **(UI)** | Set up Stage Management and DIP custom components — see the **`deploying-dip-stage-management`** skill for full details. Includes: enabling Stage Management, creating stage definitions, configuring transitions and transition rules, deploying DIP LWC components |

**Salesforce docs:**
- Enable Product Configurator: https://help.salesforce.com/s/articleView?id=ind.product_configurator_enable_product_configurator.htm&type=5
- Set Up Constraint Rules Engine: https://help.salesforce.com/s/articleView?id=ind.insurance_product_configurator_set_up_advanced_configurator.htm&type=5
- Product Configurator Permission Sets: https://help.salesforce.com/s/articleView?id=ind.product_configurator_product_configurator_permissions.htm&type=5
- Define Rules Engine with TPTs: https://help.salesforce.com/s/articleView?id=ind.product_configurator_specify_which_rule_engine_to_use.htm&type=5
- Configure Product Discovery: https://help.salesforce.com/s/articleView?id=ind.qocal_set_up_product_discovery.htm&type=5
- Page Layouts and Record Pages: https://help.salesforce.com/s/articleView?id=ind.insurance_admin_set_up_page_layouts.htm&type=5

#### Step 1.4 detail — Deploy ConstraintEngineNodeStatus__c field

This field is required by Product Configurator's Constraint Rules Engine for internal processing. Deploy via metadata API:

```xml
<!-- force-app/main/default/objects/QuoteLineItem/fields/ConstraintEngineNodeStatus__c.field-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ConstraintEngineNodeStatus__c</fullName>
    <label>Constraint Engine Node Status</label>
    <type>LongTextArea</type>
    <length>5000</length>
    <visibleLines>3</visibleLines>
</CustomField>
```

Deploy with: `sf project deploy start --source-dir force-app/main/default/objects/QuoteLineItem/fields/`

#### Step 1.5 detail — Create TransactionProcessingType

```bash
sf data create record \
  --sobject TransactionProcessingType \
  --values "Name='Advanced Transaction' DeveloperName='AdvancedTransaction' RuleEngine='AdvancedConfigurator'" \
  --target-org "$TARGET_ORG" --json
```

The `RuleEngine` field only appears after Step 1.3 (enabling Constraint Rules Engine).

#### Step 1.8 detail — Deploy Quote Record Page

The Quote Record Page must include the `runtime_revenue_foundation:transactionLineTable` component to display line items with pricing fields (NetUnitPrice, NetTotalPrice, etc.) and enable Configure/Reprice actions. The Gartner reference page also includes `dipAutoStatusIndicator` and a "Configure Quote" tab with `industries_insurance_groupbenefits:viewQuoteLineItemGrid`.

Key `displayFields` for the transactionLineTable:
```xml
<valueListItems><value>QuoteLineItem.Product2.Name[Product2]</value></valueListItems>
<valueListItems><value>QuoteLineItem.ProductInstanceIdentifier</value></valueListItems>
<valueListItems><value>QuoteLineItem.TotalPrice</value></valueListItems>
<valueListItems><value>QuoteLineItem.TotalPriceWithTax</value></valueListItems>
<valueListItems><value>QuoteLineItem.TotalTaxAmount</value></valueListItems>
<valueListItems><value>QuoteLineItem.NetTotalPrice</value></valueListItems>
<valueListItems><value>QuoteLineItem.NetUnitPrice</value></valueListItems>
<valueListItems><value>QuoteLineItem.ProratedFeeAmount</value></valueListItems>
<valueListItems><value>QuoteLineItem.ProratedTaxAmount</value></valueListItems>
```

Deploy with: `sf project deploy start --source-dir force-app/main/default/flexipages/`

### Phase 2: Product Structure (per product, API-scriptable)

| Step | Method | Description |
|------|--------|-------------|
| 2.0 | **API** | (If needed) Create ProductClassification (e.g., Vehicle) |
| 2.1 | **API** | Create root bundle Product2 |
| 2.2 | **API** | Create coverage child Product2 records |
| 2.3 | **API** | Create ProductComponentGroups |
| 2.4 | **API** | Link coverages via ProductRelatedComponent |
| 2.5 | **API** | Link insured item classification via ProductRelatedComponent |
| 2.6 | **API** | Add ProductSellingModelOption |
| 2.7 | **API** | Add all products to Standard Price Book (PricebookEntry with `UnitPrice=0`) |
| 2.8 | **API** | Link root product to Insurance Product Catalog (ProductCategoryProduct) |
| 2.9 | **API** | Create product attributes (AttributeDefinition + AttributePicklist + values) |
| 2.10 | **API** | Mark pricing-required attributes as `IsRequired=true` on AttributeDefinition |
| 2.11 | **API** | Set default picklist values (`IsDefault=true` on one AttributePicklistValue per picklist) |

**PricebookEntry critical note:** Revenue Cloud's Browse Catalog requires PricebookEntry to have `ProductSellingModelId` set. This field is **create-only** (not updateable). If you create a PBE without it, you must delete and recreate it. Deleting a PBE requires first deleting any QuoteLineItem records that reference it.

### Phase 3: Context Definition & Mapping (per product, UI-only)

This phase wires the pricing procedure's input/output variables to the platform's context engine. **All steps in this phase require the UI** — Context Definitions are not API-accessible.

| Step | Method | Description |
|------|--------|-------------|
| 3.1 | **(UI)** | Extend InsuranceContext: Setup → Context Definitions → Standard Definitions → InsuranceContext → Extend. Name it (e.g., `PDInsuranceContext`) |
| 3.2 | **(UI)** | Add Context Attributes on the SalesTransactionItem node for every procedure variable (inputs, outputs, intermediates). Type=INPUTOUTPUT, DataType per variable |
| 3.3 | **(UI)** | Add `ConstraintEngineNodeStatus` attribute: Type=INPUTOUTPUT, DataType=STRING on SalesTransactionItem node |
| 3.4 | **(UI)** | Generate tags: Edit Attribute Tags → Generate All Tags → Retain and Regenerate |
| 3.5 | **(UI)** | Map data in QuoteEntitiesMapping: map `ConstraintEngineNodeStatus` to `ConstraintEngineNodeStatus__c` on QuoteLineItem. Verify `TransactionType` on SalesTransaction is mapped to `TransactionType` on Quote |
| 3.6 | **(UI)** | For any custom product attributes that need hydration from QuoteLineItem fields: map them in QuoteEntitiesMapping → SalesTransactionItem → Input Mapping. Use "Generate Mapping" for bulk auto-mapping |
| 3.7 | **(UI)** | Activate the context definition. **Wait several minutes** — activation is asynchronous |

**Salesforce docs:**
- Set Up Context Definitions (ConstraintEngineNodeStatus mapping): https://help.salesforce.com/s/articleView?id=ind.product_configurator_set_up_constraint_engine_context_definitions.htm&type=5
- Set Up Constraint Rules Engine (full end-to-end): https://help.salesforce.com/s/articleView?id=ind.insurance_product_configurator_set_up_advanced_configurator.htm&type=5

**Critical: intermediate calculation variables do NOT need field mappings.** A Context Attribute needs a field mapping only if its value should be hydrated from the source record (e.g., `Country` reading from `QuoteLineItem.Country__c`). Variables like `PDBasePremium__c` that exist purely in the runtime context should be declared as Context Attributes but NOT mapped. This is how Gartner/Celent's CP procedure works.

### Phase 4: Decision Tables / Matrices (per product, API-scriptable)

| Step | Method | Description |
|------|--------|-------------|
| 4.1 | **(UI)** | Create Decision Table via UI: Setup → Decision Tables → New. Set Application Usage=Pricing, Type=Advanced. API creation fails with UNKNOWN_EXCEPTION |
| 4.2 | **API** | Populate source sObject data (if using a custom sObject-backed DT) |
| 4.3 | **API** | Refresh Decision Table via `refreshDecisionTable` invocable action |
| 4.4 | **(UI)** | Register DT in Pricing Recipe: Setup → Pricing Recipe → Price Adjustment Matrix tab → add the DT |

**Decision Table critical notes:**
- NEVER mark source-object text fields as `<required>true</required>` — the DT refresh introspection throws an NPE on required text fields. Use Validation Rules instead.
- After refresh, wait for `LastSyncDate` to advance on the DecisionTable record — don't rely on `RefreshStatus=Completed`.
- DTs must be registered in the Pricing Recipe before they appear in the procedure builder's PAM step picker.

#### Step 4.3 detail — Refresh Decision Table

```bash
sf org display --target-org "$TARGET_ORG" --json | python3 -c "
import sys, json, urllib.request
d = json.load(sys.stdin)
token = d['result']['accessToken']
instance = d['result']['instanceUrl']
payload = json.dumps({'inputs': [{'DecisionTableApiName': '<DT_API_NAME>', 'isDecisionTableIncremental': False}]}).encode()
req = urllib.request.Request(
    instance + '/services/data/v66.0/actions/standard/refreshDecisionTable',
    data=payload, method='POST',
    headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}
)
result = json.loads(urllib.request.urlopen(req).read())
print('Refresh status:', result[0]['outputValues']['Status'])
"
```

### Phase 5: Pricing Procedure (per product, API-scriptable)

| Step | Method | Description |
|------|--------|-------------|
| 5.1 | **API** | Create ExpressionSetDefinition (ESD) via Tooling API |
| 5.2 | **API** | Create ExpressionSetDefinitionVersion (ESDV) via Tooling API. Set `contextDefinitions` to the custom context (e.g., `PDInsuranceContext`) |
| 5.3 | **API** | Activate ESDV (PATCH Metadata with `status: 'Active'`) |

See Step 10 section below for full Tooling API code examples.

### Phase 6: Procedure Plan Definition (UI-only)

| Step | Method | Description |
|------|--------|-------------|
| 6.1 | **(UI)** | Create Procedure Plan Definition: Setup → Procedure Plan Definitions → New |
| 6.2 | **(UI)** | Configure: Process Type=Insurance, Primary Object=Transaction Processing Type, Context Definition=your custom context |
| 6.3 | **(UI)** | Add Section: Name=any, Section Type=Pricing Procedure, Standard selected |
| 6.4 | **(UI)** | Set Resolution Type=Rule-based, Add Criteria: Resource=Label, Operator=Equals, Output Value=the TransactionProcessingType's MasterLabel (e.g., `Advanced Transaction`) |
| 6.5 | **(UI)** | Assign the pricing procedure to the criteria row |
| 6.6 | **(UI)** | Activate the Procedure Plan Definition |

**Salesforce docs:**
- Assign Pricing Procedure to Quote: https://help.salesforce.com/s/articleView?id=ind.insurance_admin_pricing_procedure_for_product.htm&type=5
- Assign Pricing Procedure to Product: https://help.salesforce.com/s/articleView?id=ind.insurance_admin_pricing_procedure_for_quote.htm&type=5

**Critical:** The criteria Output Value must match the TransactionProcessingType's **MasterLabel** (e.g., `Advanced Transaction`), NOT the DeveloperName. The Procedure Plan section has **Phases** (dropdown with values like "Pricing") — this is the section type, distinct from the resolution type.

### Phase 7: Quote Creation & Testing

| Step | Method | Description |
|------|--------|-------------|
| 7.1 | **API** | Create Quote with `TransactionType` set to the TPT's DeveloperName (e.g., `AdvancedTransaction`) |
| 7.2 | **API** | Create QuoteLineItem(s) linking to PricebookEntry. Browse Catalog's "Add" button may fail with "product doesn't have a price" — workaround: create QuoteLineItem directly via API |
| 7.3 | **(UI)** | Click **Configure** on the line item → set input attribute values (e.g., Country, Deductible, vehicle attributes) |
| 7.4 | **(UI)** | Click **Reprice All** → verify NetUnitPrice is non-zero |

#### Step 7.1 detail — Create Quote via API

```bash
QUOTE_ID=$(sf data create record \
  --sobject Quote \
  --values "Name='Test Quote' OpportunityId='$OPP_ID' Pricebook2Id='$PRICEBOOK_ID' TransactionType='AdvancedTransaction'" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])")
```

#### Step 7.2 detail — Create QuoteLineItem via API (Browse Catalog workaround)

```bash
sf data create record \
  --sobject QuoteLineItem \
  --values "QuoteId='$QUOTE_ID' Product2Id='$PRODUCT_ID' PricebookEntryId='$PBE_ID' Quantity=1 UnitPrice=0" \
  --target-org "$TARGET_ORG" --json
```

---

## Pre-build: verify the target org

Before any deployment, run the pipeline check:

```bash
scripts/check-pricing-pipeline.sh <org-alias>
```

Then discover org-specific IDs:

```bash
eval "$(scripts/discover-org-ids.sh <org-alias>)"
```

---

## Org background note

When comparing orgs, know what each is for:
- **AJG-Clements** — internal demo org, heavily customized. **Do not use as a baseline.** Uses a CUSTOM pricing Apex layer (not standard FSC). Missing `PricingResultTransformer` / zero `PricingProcessExecution` is expected there, not broken.
- **Gartner/Celent 2026** — sandbox copy from Product Management. FSC Insurance properly configured with standard pricing stack. **Use this as the "working pattern" reference.**
- **DigInsTrialOrgMay2026** — fresh trial org where the end-to-end build was validated through v4 of this skill. Everything required was created from scratch.

---

## Key Record Type and Relationship IDs

**These IDs are org-specific.** Discover at runtime.

| Name | Pattern | Used For |
|------|---------|----------|
| Root Product RT | `012*` | Root bundle Product2 (named `Commercial` or `Root_Product` depending on org) |
| Coverage RT | `012*` | Coverage child Product2 records |
| Bundle→Bundle relationship | `0yo*` | ProductRelatedComponent for Coverage children |
| Bundle→Classification relationship | `0yo*` | ProductRelatedComponent for insured item classification |
| Insured-item ProductClassification | `11B*` | Vehicle, Property, etc. — create if missing |
| Annual ProductSellingModel | `0jP*` | ProductSellingModelOption |

---

## Custom Context Definition (when the procedure uses ListGroups)

If your pricing procedure has any **ListGroup**-scoped steps that reference variables NOT in the standard `InsuranceContext__stdctx`, you must extend the standard context to declare those variables as Context Attributes. The platform rejects ESDV creates that reference local Variables inside ListGroup steps with "Specify a valid data type for the X variable" / "Local variables aren't supported when a business element is used in a list group."

This is **not currently scriptable via the public API.** It must be done via **Setup → Context Service → Context Definitions** UI (see Phase 3 in the Master Build Sequence).

### Critical: activation is asynchronous

After clicking Activate, the platform runs a backend process. **Do not immediately try to deploy a procedure that references the new attributes — it will fail with "context not found" or "attribute not declared" errors.** Wait several minutes, then retry.

### Updating the procedure to use the custom context

Once active, set the procedure's `contextDefinitions` field to the developer name of the custom context:

```python
'contextDefinitions': ['PDInsuranceContext'],  # custom — not 'InsuranceContext__stdctx'
```

---

## Step-by-Step (Phase 2 detail)

### Step 2.0 (if needed) — Create a new ProductClassification

```bash
CLASS_ID=$(sf data create record \
  --sobject ProductClassification \
  --values "Name='<Name>' Code='<Code>' Status='Active'" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])")
```

### Step 2.1 — Create root bundle

```bash
ROOT_ID=$(sf data create record \
  --sobject Product2 \
  --values "Name='<Product Name>' \
            ProductCode='<product-code>' \
            Description='<description>' \
            Type='Bundle' \
            RecordTypeId='$RT_COMMERCIAL' \
            IsAssetizable=true \
            Family='Insurance' \
            IsActive=true \
            StockKeepingUnit='<SKU>' \
            ConfigureDuringSale='Allowed'" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])")
```

**Critical:** `ConfigureDuringSale='Allowed'` is required on the root bundle if any coverage will be optional.

**Do NOT set:** `SpecificationType`, `ProductClass` (read-only), `ProductPurpose` (doesn't exist in stock FSC orgs).

### Step 2.2 — Create coverage child products

```bash
COV_ID=$(sf data create record \
  --sobject Product2 \
  --values "Name='<Coverage Name>' \
            ProductCode='<coverage-code>' \
            Description='<description>' \
            Type='Bundle' \
            RecordTypeId='$RT_COVERAGE' \
            IsAssetizable=true \
            IsActive=true" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])")
```

### Step 2.3 — Create ProductComponentGroups

```bash
COVERAGE_GROUP_ID=$(sf data create record \
  --sobject ProductComponentGroup \
  --values "Name='Coverage' ParentProductId='$ROOT_ID' Sequence=1" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])")

VEHICLE_GROUP_ID=$(sf data create record \
  --sobject ProductComponentGroup \
  --values "Name='Vehicle' ParentProductId='$ROOT_ID' Sequence=2" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])")
```

### Step 2.4 — Link coverages via ProductRelatedComponent

Required coverages:
```bash
sf data create record \
  --sobject ProductRelatedComponent \
  --values "ParentProductId='$ROOT_ID' \
            ChildProductId='$COV_ID' \
            ProductComponentGroupId='$COVERAGE_GROUP_ID' \
            ProductRelationshipTypeId='$PRT_BUNDLE' \
            IsComponentRequired=true \
            IsDefaultComponent=true \
            Sequence=1" \
  --target-org "$TARGET_ORG" --json > /dev/null
```

Optional coverages: set `IsComponentRequired=false IsDefaultComponent=false`.

### Step 2.5 — Link insured item classification

```bash
sf data create record \
  --sobject ProductRelatedComponent \
  --values "ParentProductId='$ROOT_ID' \
            ChildProductClassificationId='$VEHICLE_CLASS_ID' \
            ProductComponentGroupId='$VEHICLE_GROUP_ID' \
            ProductRelationshipTypeId='$PRT_CLASSIFICATION' \
            IsComponentRequired=false \
            IsDefaultComponent=false \
            Sequence=1" \
  --target-org "$TARGET_ORG" --json > /dev/null
```

### Step 2.6 — Add ProductSellingModelOption to ALL products

**Every product in the bundle** (root AND all child coverages) needs a `ProductSellingModelOption`. Not just the root. Without it, PricebookEntry creation with `ProductSellingModelId` fails, and the Product Configurator can't add child line items ("Required fields are missing: [Price Book Entry]").

```bash
for PROD_ID in "$ROOT_ID" "$COV1_ID" "$COV2_ID" "$OPT_COV1_ID" "$OPT_COV2_ID"; do
  sf data create record \
    --sobject ProductSellingModelOption \
    --values "Product2Id='$PROD_ID' ProductSellingModelId='$SELLING_MODEL_ANNUAL' IsDefault=true" \
    --target-org "$TARGET_ORG" --json > /dev/null
  echo "  PSMO created for $PROD_ID"
done
```

### Step 2.7 — Add ALL products to Standard Price Book

Every product in the bundle (root + all coverages) must have a PricebookEntry. Include `ProductSellingModelId` — the field is **create-only** and required by Browse Catalog and the Product Configurator.

```bash
PRICEBOOK_ID=$(sf data query \
  --query "SELECT Id FROM Pricebook2 WHERE IsStandard=true" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['records'][0]['Id'])")

for PROD_ID in "$ROOT_ID" "$COV1_ID" "$COV2_ID" "$OPT_COV1_ID" "$OPT_COV2_ID"; do
  sf data create record \
    --sobject PricebookEntry \
    --values "Pricebook2Id='$PRICEBOOK_ID' Product2Id='$PROD_ID' UnitPrice=0 IsActive=true ProductSellingModelId='$SELLING_MODEL_ANNUAL'" \
    --target-org "$TARGET_ORG" --json > /dev/null
  echo "  PBE created for $PROD_ID"
done
```

**Critical notes:**
- `ProductSellingModelId` is create-only (not updateable). If you create a PBE without it, you must delete and recreate.
- PBE creation requires the product to already have a `ProductSellingModelOption` for the referenced selling model (Step 2.6).
- Deleting a PBE requires first deleting any QuoteLineItem records that reference it.

### Step 2.8 — Associate root product to Insurance Product Catalog

```bash
CAT_ID=$(sf data create record \
  --sobject ProductCategory \
  --values "Name='<Product Name>' CatalogId='$CATALOG_ID'" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])")

sf data create record \
  --sobject ProductCategoryProduct \
  --values "ProductId='$ROOT_ID' ProductCategoryId='$CAT_ID'" \
  --target-org "$TARGET_ORG" --json > /dev/null
```

### Step 2.10 — Mark pricing-required attributes as required

Any attribute whose value is needed as input to the pricing procedure's Decision Table lookups should be marked `IsRequired=true` on the `AttributeDefinition`. This makes the Product Configurator enforce that users fill them in before saving.

```bash
# Set IsRequired=true on attributes needed for pricing
for DEV_NAME in <attr_dev_name_1> <attr_dev_name_2> <attr_dev_name_3>; do
  ATTR_ID=$(sf data query \
    --query "SELECT Id FROM AttributeDefinition WHERE DeveloperName='$DEV_NAME'" \
    --target-org "$TARGET_ORG" \
    --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['records'][0]['Id'])")
  sf data update record --sobject AttributeDefinition --record-id "$ATTR_ID" \
    --values "IsRequired=true" --target-org "$TARGET_ORG" --json > /dev/null
  echo "  $DEV_NAME → IsRequired=true"
done
```

**Guidance on what to mark required:**
- Picklist/numeric attributes that feed DT lookups (e.g., country, deductible, limit) → **required**
- Boolean/checkbox attributes with a meaningful default (e.g., an optional coverage toggle defaults to false) → **optional** (the default provides a value for pricing)

### Step 2.11 — Set default picklist values

Set `IsDefault=true` on exactly one `AttributePicklistValue` per required picklist. This pre-populates the field in the Product Configurator so users don't start from blank. The lookup field on AttributePicklistValue is `PicklistId` (not `AttributePicklistId`).

```bash
# Find the picklist ID for an attribute
PICKLIST_ID=$(sf data query \
  --query "SELECT PicklistId FROM AttributeDefinition WHERE DeveloperName='PD_Deductible'" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['records'][0]['PicklistId'])")

# Set default on a specific value (e.g., 1250 for deductible)
DEFAULT_VAL_ID=$(sf data query \
  --query "SELECT Id FROM AttributePicklistValue WHERE PicklistId='$PICKLIST_ID' AND Value='1250'" \
  --target-org "$TARGET_ORG" \
  --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['records'][0]['Id'])")

sf data update record --sobject AttributePicklistValue --record-id "$DEFAULT_VAL_ID" \
  --values "IsDefault=true" --target-org "$TARGET_ORG" --json > /dev/null
```

**Important:** Only one value per picklist should have `IsDefault=true`. If a previous default exists, clear it first with `IsDefault=false` before setting the new one. `IsDefault` is required in newer schema versions — always set it explicitly (true on one, false on all others) at creation time.

---

## Step 5 detail — Pricing Procedure (ExpressionSetDefinitionVersion)

### Step 5.1 — Create the ExpressionSetDefinition

```bash
sf org display --target-org "$TARGET_ORG" --json | python3 -c "
import sys, json, urllib.request
d = json.load(sys.stdin)
token = d['result']['accessToken']
instance = d['result']['instanceUrl']

payload = {
    'allOrNone': True,
    'compositeRequest': [{
        'method': 'POST',
        'url': '/services/data/v66.0/tooling/sobjects/ExpressionSetDefinition',
        'referenceId': 'newESD',
        'body': {
            'FullName': '<ProductName>PricingProcedure',
            'Metadata': {
                'fullName': '<ProductName>PricingProcedure',
                'label': '<ProductName>PricingProcedure',
                'executionScale': 'Low',
                'interfaceSourceType': 'PricingProcedure',
                'processType': 'DefaultPricing',
                'contextDefinitions': ['PDInsuranceContext']
            }
        }
    }]
}

req = urllib.request.Request(
    instance + '/services/data/v66.0/tooling/composite',
    data=json.dumps(payload).encode(), method='POST',
    headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}
)
print(json.loads(urllib.request.urlopen(req).read())['compositeResponse'][0]['body'])
"
```

**Note**: `Metadata.fullName` inside the Metadata object is required in addition to the top-level `FullName`.

### Step 5.2 — Create the ESDV

Clone an existing procedure's Metadata and adapt it:

```python
# Fetch source ESD metadata
source_esd = api('/services/data/v66.0/tooling/sobjects/ExpressionSetDefinition/<SOURCE_ESD_ID>?fields=Metadata')
ver_meta = copy.deepcopy(source_esd['Metadata']['versions'][0])

# Rename for new product
ver_meta['expressionSetDefinition'] = '<ProductName>PricingProcedure'
ver_meta['label'] = '<ProductName>PricingProcedure V1'

# POST to create ESDV
result = api(
    '/services/data/v66.0/tooling/sobjects/ExpressionSetDefinitionVersion',
    method='POST',
    payload={'FullName': '<ProductName>PricingProcedure_V1', 'Metadata': ver_meta}
)
```

### Step 5.3 — Activate ESDV

PATCH the full Metadata blob with `status: 'Active'` (partial PATCH doesn't work on Tooling sObjects).

### Pricing procedure architecture notes

- All active ESDVs run on every pricing request. A procedure self-selects via a root product filter step.
- Prefer filtering on `ItemProductCode` (not `ProductName`) for stability.
- Prefer **composite-key matrices** (FactorGroup__c + FactorKey__c → outputs) over separate matrices per factor.
- Use `AggregationKeyLevel1/2/3` for multi-level rollup pricing.

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `INVALID_FIELD_FOR_INSERT_UPDATE: SpecificationType, ProductClass` | Read-only fields auto-set by RecordType | Remove from Product2 create values |
| `INVALID_FIELD_FOR_INSERT_UPDATE: ParentProductRole, ChildProductRole` | Read-only fields on ProductRelatedComponent | Remove from values |
| `REQUIRED_FIELD_MISSING: ProductRelationshipTypeId` | Not provided on ProductRelatedComponent | Discover via `sf data query --query "SELECT Id, Name FROM ProductRelationshipType"` |
| `Child component must be added by default for a Static Parent Product` | Root product has ConfigureDuringSale=null | Set `ConfigureDuringSale='Allowed'` on root |
| `A product classification component can't be required/included by default` | IsComponentRequired=true on classification | Set both to false |
| `Product doesn't have a price` (Browse Catalog) | PricebookEntry missing `ProductSellingModelId` | Delete PBE (must delete referencing QLIs first), recreate with `ProductSellingModelId` |
| `Required fields are missing: [Price Book Entry]` (Configure) | Child coverage products missing PricebookEntry with `ProductSellingModelId` | Create `ProductSellingModelOption` for each child product first, then create PBE with `ProductSellingModelId` |
| `First add a product selling model option` (PBE create) | PBE with `ProductSellingModelId` requires a `ProductSellingModelOption` on the product | Create `ProductSellingModelOption` for the product before creating PBE |
| `ConstraintEngineNodeStatus field hasn't been added` (Configure button) | Missing custom field and/or context mapping | Deploy `ConstraintEngineNodeStatus__c` (LongTextArea/5000) on QuoteLineItem, add as INPUTOUTPUT/STRING attribute in context def, map in QuoteEntitiesMapping |
| `Cannot invoke java.util.Map.size() because m is null` (Reprice All) | Missing field-level mappings in QuoteEntitiesMapping for custom attributes | Edit context def → QuoteEntitiesMapping → SalesTransactionItem → Input Mapping → Generate Mapping |
| `DefaultContextRuntimeEntity null` (Configure button) | Context definition not properly wired to TransactionProcessingType / Procedure Plan | Ensure TransactionProcessingType exists, Procedure Plan criteria matches TPT label, context def is active |
| `The default procedure must be associated with SalesTransactionContext__stdctx` | Trying to set an InsuranceContext-based procedure as the default in Revenue Settings | Skip this setting — insurance pricing uses Procedure Plan Definitions, not the Revenue Settings default procedure |
| `PremiumValue__c isn't a valid variable name` (ESDV deploy) | Context attribute collision or stale validator state | Delete conflicting ContextAttributes, wait for cache to clear, retry |
| DT refresh NPE on `Entity.getField(String)` | `<required>true</required>` on source sObject text fields | Redeploy field metadata with `<required>false</required>` |

---

## Discovering IDs in a New Org

```bash
# Record Type IDs
sf data query --query "SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType='Product2'" --target-org <alias> --json

# ProductRelationshipType IDs
sf data query --query "SELECT Id, Name FROM ProductRelationshipType" --target-org <alias> --json

# ProductClassification IDs
sf data query --query "SELECT Id, Name FROM ProductClassification" --target-org <alias> --json

# ProductSellingModel IDs
sf data query --query "SELECT Id, Name FROM ProductSellingModel" --target-org <alias> --json

# Product Catalogs
sf data query --query "SELECT Id, Name FROM ProductCatalog" --target-org <alias> --json

# TransactionProcessingType records
sf data query --query "SELECT Id, Name, DeveloperName, RuleEngine FROM TransactionProcessingType" --target-org <alias> --json

# Context Definitions
sf data query --query "SELECT Id, DeveloperName, MasterLabel FROM ContextDefinition" --target-org <alias> --json

# Procedure Plan Definitions
sf data query --query "SELECT Id, DeveloperName, MasterLabel, Status FROM ProcedurePlanDefinition" --target-org <alias> --json
```

---

## Reference Scripts

The reference scripts live under `/Users/mblatchford/Documents/IDEs/ClaudeProjects/AJG AMS Beyontec Replacement/scripts/`:

| Script | Purpose |
|---|---|
| `check-pricing-pipeline.sh` | Pre-build verification of FSC Insurance pricing platform |
| `discover-org-ids.sh` | Discovers org-specific IDs, emits `export` lines for `eval` |
| `create-physical-damage-product.sh` | Builds PD product structure (root + coverages + attributes + selling model + pricebook + catalog) |
| `create-physical-damage-matrices.py` | Creates PD pricing matrix using composite-key pattern |
| `create-physical-damage-pricing-procedure.py` | Creates and activates PD ESD + ESDV |

Run order for a fresh build:

```bash
scripts/check-pricing-pipeline.sh <alias>
eval "$(scripts/discover-org-ids.sh <alias>)"
scripts/create-physical-damage-product.sh <alias>
scripts/create-physical-damage-matrices.py <alias>
scripts/create-physical-damage-pricing-procedure.py <alias>
# Then: UI steps for Context Definition, Procedure Plan, Quote Record Page
```

---

## Lessons Learned (v4)

### 1. Always work from the standard FSC platform, not from custom org content

Distinguish: standard fields (no suffix), `__c` custom fields (config noise), namespaced fields (managed packages — avoid). Comparing field counts alone is misleading.

### 2. The `__c` suffix on procedure variables / matrix columns is metadata-internal

Inside ESDV steps and CalculationMatrixColumn records, names like `FactorGroup__c`, `BasePremium__c` are variable labels, NOT real QuoteLineItem custom fields.

### 3. Org IDs are never portable

Discover at runtime. The root product RecordType is named `Commercial` in mature orgs, `Root_Product` in newer trials.

### 4. Field-shape varies by FSC version / package install

| Field | Behavior |
|-------|----------|
| `Product2.ProductPurpose` | **Does NOT exist** in stock FSC orgs. Don't set it. |
| `AttributePicklistValue.IsDefault` | Required in newer schema. Always set explicitly. |
| `ProductSellingModelOption.IsDefault` | Required in newer schema. Set `true`. |
| `PricebookEntry.ProductSellingModelId` | **Create-only.** Required by Browse Catalog. Set at PBE creation time. |
| `TransactionProcessingType.RuleEngine` | Only visible after enabling Constraint Rules Engine in Revenue Settings. |

### 5. Don't reuse half-installed AttributeDefinitions

Fresh orgs ship with leftover `Deductible` defs. `PicklistId` is read-only after creation — create new defs rather than repairing.

### 6. ProductCodes matter — pricing procedures filter on them

Set ProductCodes deliberately. The pricing procedure filters on `ItemProductCode`, not `ProductName`.

### 7. Pricing procedure pattern: prefer composite-key matrices

Single composite-key matrix (FactorGroup__c + FactorKey__c → outputs) is cleaner than separate matrices per factor.

### 8. ESDV metadata must omit null-valued complex-object fields

Fields like `advancedCondition`, `customElement`, `aggregation` cannot be `null` — omit entirely. Read/write asymmetry: these ARE returned as null on read.

### 9. Context attribute mapping is for hydration, not declaration

A Context Attribute needs a field mapping only if its value should be hydrated from the source record. Intermediate calculation variables exist purely in runtime context — declare but don't map.

### 10. Browse Catalog "Add" may not work — use API as workaround

The Browse Catalog "Add" button fails with "product doesn't have a price" even with correct PricebookEntry + ProductSellingModelId in some trial orgs. Workaround: create QuoteLineItem directly via `sf data create record`. The Configure and Reprice All actions work fine on API-created line items.

### 11. Product Discovery Settings — don't enable the pricing procedure toggle

The Pricing Procedure toggle in Product Discovery Settings requires a procedure using `ProductDiscoveryContext` or `SalesTransactionContext__stdctx`. Insurance pricing procedures use `InsuranceContext__stdctx`. Enabling it with an insurance procedure causes "No products to show" / calculation errors. Leave it off.

### 12. Procedure Plan criteria must match TPT MasterLabel, not DeveloperName

The Procedure Plan Definition criteria's Output Value must match the TransactionProcessingType's **MasterLabel** (e.g., `Advanced Transaction`), not the DeveloperName (`AdvancedTransaction`).

### 13. ConstraintEngineNodeStatus is a platform prerequisite for Configure

Product Configurator's Configure action requires a `ConstraintEngineNodeStatus__c` (LongTextArea/5000) custom field on QuoteLineItem, plus a matching attribute in the context definition mapped in QuoteEntitiesMapping. Without all three pieces, Configure throws an error. This is API-deployable (the field itself) but the context attribute + mapping are UI-only.

### 14. Org-comparison shorthand

```bash
sf sobject describe --sobject Product2 --target-org <alias> --json | python3 -c "import sys,json; print(len(json.load(sys.stdin)['result']['fields']))"
sf data query --query "SELECT COUNT() FROM ExpressionSetDefinitionVersion WHERE Status='Active'" --target-org <alias>
sf data query --query "SELECT Name FROM ProductCatalog" --target-org <alias>
```

- 30–40 Product2 fields = standard FSC. >50 = customized.
- 0 active ESDVs = fresh org. 20+ = pre-built content.
