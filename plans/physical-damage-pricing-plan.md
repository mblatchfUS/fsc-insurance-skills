# Plan: Get PD pricing working end-to-end in DigInsTrialOrgMay2026

## Context

We moved from AJG-Clements (custom Apex layer, not fixable) to **DigInsTrialOrgMay2026** (standard FSC Insurance stack). Configure and Reprice All both execute, but pricing returns **$0** because only `DefaultPricingProcessTypeHandler` fires — the `ProductQualificationProcessTypeHandler` never runs.

## Root cause: `enablePCMConfigRules = false`

**Confirmed via Tooling API comparison:**

| Setting | Trial Org | Gartner (working) |
|---|---|---|
| `enablePCMConfigRules` | **false** | **true** |
| TransactionProcessingTypes | 2 → **now 6** (we deployed 4 missing ones) | 6 |
| PricingProcessExecution records | 0 | 85,973 |
| Apex classes (Insurance/Pricing/Quote) | **0** | **20** |
| BrowseProductsContextDefinition | **missing** | present |
| ProductDiscovery context | **missing** | present |

`enablePCMConfigRules` is the master toggle for the Product Configuration Management rules engine. When `true`, it routes pricing through `ProductQualificationProcessTypeHandler` (which evaluates qualification rules, then invokes product-level pricing procedures). When `false`, only `DefaultPricingProcessTypeHandler` runs, which doesn't invoke product-specific procedures — so pricing always returns $0.

**Deploying the setting via Metadata API fails** with: `There was an error enabling or disabling a setting: OrgPreferences.PCMConfigRulesEnabled`. This is a **provisioned feature toggle**, not just a metadata setting — it requires org-level feature enablement that can't be done via API alone. Likely needs to be toggled in **Setup → Industries → Product and Pricing Configuration → General Settings** (or similar path) — the UI may expose prerequisites or an enable button not available through metadata deploy.

## What we've already fixed

- [x] Deployed 4 missing TransactionProcessingTypes: `AdvancedConfigurator`, `AutoTransactionType`, `CommercialTransactionType`, `StandardConfigurator`
- [x] `PhysicalDamagePricingProcedureV2` (ESDV `9QBfn0000003FiTGAU`) is Active
- [x] `InsuranceDefaultPricingProcedure` (ESDV `9QBfn0000003HcDGAU`) is Active
- [x] Quote `0Q0fn000001VTwPCAW` exists with Physical Damage line item `0QLfn000001bM7RGAU`
- [x] PricebookEntry exists for Physical Damage (`01ufn000002CQ2PAAW`, UnitPrice=1, Active)
- [x] Quote_Level_Procedure_Plan (`1FNfn0000000qoDGAQ`) is Active, Rank=1, bound to PDInsuranceContext
- [x] Product_Level_Procedure_Plan (`1FNfn0000000qppGAA`) exists

## Open issues

### Issue 1: `enablePCMConfigRules` — MAIN BLOCKER
**Status:** Cannot enable via metadata deploy. Need to find UI toggle path in Setup.

**Actions to try (in order):**
1. **Navigate in Setup UI** → search "Product and Pricing Configuration" or "Product Configuration Rules" → look for an enable toggle
2. If not found there, try **Setup → Industries Settings** → look for "Constraint Configuration Rules" or "PCM Config Rules"
3. If the UI shows prerequisites not met, note what it says — those will tell us exactly what's needed
4. Last resort: contact SF support or try creating a new trial org from a different template that ships with this pre-enabled

### Issue 2: Missing Apex layer (0 classes)
**Status:** Likely auto-created when `enablePCMConfigRules` is enabled, OR these are Gartner custom classes that need separate deployment.

The 20 Apex classes in Gartner include both:
- **Platform classes** (e.g., `InsuranceQuoteService`, `InsuranceProductRatingAdapter`, `InsuranceQuotingAdapter`) — likely auto-provisioned
- **Custom classes** (e.g., `PricingResultTransformer`, `CompareQuoteVersionsController`) — deployed by the Gartner team

If enabling PCM doesn't auto-create the platform classes, we may need to deploy them from Gartner.

### Issue 3: "Required fields missing: [Price Book Entry]" error
**Status:** Needs re-test. Data looks correct — PricebookEntry `01ufn000002CQ2PAAW` exists and is active. May be a UX-layer issue in the configurator that resolves itself once pricing actually runs.

### Issue 4: Missing BrowseProductsContextDefinition
**Status:** Needed for Vehicle browse. Can be created by extending `ProductDiscoveryContext__stdctx` (same as Gartner). Lower priority than pricing.

## Next step

**Manual UI action required:** Navigate to Setup in the trial org and find/enable the PCM Config Rules toggle. The URL to open the org:
```
sf org open --target-org DigInsTrialOrgMay2026
```
Then search Setup for "Product and Pricing Configuration" or "Constraint Rules" or "PCM".

## Key record IDs (DigInsTrialOrgMay2026)

| Record | ID |
|---|---|
| Quote | `0Q0fn000001VTwPCAW` |
| QuoteLineItem (PD) | `0QLfn000001bM7RGAU` |
| PricebookEntry (PD) | `01ufn000002CQ2PAAW` |
| Product2 (PD) | `01tfn000004jg7FAAQ` |
| Product2 (Vehicle) | `01tfn000004nk93AAA` |
| ProcedurePlanDef (Quote Level) | `1FNfn0000000qoDGAQ` |
| ProcedurePlanDef (Product Level) | `1FNfn0000000qppGAA` |
| ESD (PhysicalDamagePricingProcedureV2) | `9QAfn000000IwtZGAS` |
| ESDV (PD V2 V1, Active) | `9QBfn0000003FiTGAU` |
| ESD (InsuranceDefaultPricingProcedure) | `9QAfn000000J8TJGA0` |
| ESDV (Default, Active) | `9QBfn0000003HcDGAU` |
| ContextDefinition (PDInsuranceContext) | `11Ofn0000013WXREA2` |
| PricingRecipe (NGPDefaultRecipe) | `12Gfn000000gTLlEAM` |
| TransactionProcessingType (AdvancedTransaction) | `1Bpfn0000000EHVCA2` |
| TransactionProcessingType (InsurancePricingTransaction) | `1Bpfn0000000EFtCAM` |

## Verification (once pricing works)

1. Open Quote `0Q0fn000001VTwPCAW`
2. Click "Reprice All"
3. Expected: `NetUnitPrice` on Physical Damage line is non-zero
4. Check: `SELECT COUNT() FROM PricingProcessExecution` returns > 0
