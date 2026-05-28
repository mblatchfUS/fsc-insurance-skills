# Physical Damage Product Build — Lessons Learned

## Context

Built Physical Damage insurance product in `DigInsTrialOrgMay2026` trial org. Goal was end-to-end working pricing (Configure → Update Prices → $non-zero).

## Key Blocker: `enablePCMConfigRules`

**Root cause:** `enablePCMConfigRules = false` in trial org (vs. `true` in working Gartner/Celent org).

When `false`:
- Only `DefaultPricingProcessTypeHandler` fires
- `ProductQualificationProcessTypeHandler` never runs
- Pricing procedures are ignored → always returns $0

**Cannot be enabled via Metadata API** — fails with: `"There was an error enabling or disabling a setting: OrgPreferences.PCMConfigRulesEnabled"`

This is a **provisioned feature toggle** requiring:
- Setup UI navigation (likely "Product and Pricing Configuration" or "Revenue Settings")
- Prerequisites must be met first (likely involves setting a default pricing procedure)

## What We Fixed

- [x] Deployed 4 missing TransactionProcessingTypes
- [x] Created Quote Level and Product Level ProcedurePlanDefinitions
- [x] Activated pricing procedures (InsuranceDefaultPricingProcedure, PhysicalDamagePricingProcedureV2)
- [x] Built product structure (root + coverages + Vehicle via ProductClassification)
- [x] All PricebookEntries, ProductSellingModels, ProductSellingModelOptions correctly configured

## Open Issues

1. **Primary:** Need to manually enable PCM Config Rules via Setup UI
2. Empty Vehicle browse — needs BrowseProductsContextDefinition extending ProductDiscoveryContext__stdctx
3. "Required fields: [Price Book Entry]" error on coverage save — may resolve after #1 is fixed

## Key Record IDs (DigInsTrialOrgMay2026)

| Record | ID |
|---|---|
| Quote | `0Q0fn000001VTwPCAW` |
| Product2 (Physical Damage) | `01tfn000004jg7FAAQ` |
| Product2 (Vehicle) | `01tfn000004nk93AAA` |
| ESD (PhysicalDamagePricingProcedureV2) | `9QAfn000000IwtZGAS` |
| ESD (InsuranceDefaultPricingProcedure) | `9QAfn000000J8TJGA0` |
| ContextDefinition (PDInsuranceContext) | `11Ofn0000013WXREA2` |

## References

- Plan: `/Users/mblatchford/.claude/plans/jiggly-splashing-sun.md`
- Working reference: Gartner/Celent 2026 (Commercial Property)
- Trial org: DigInsTrialOrgMay2026
