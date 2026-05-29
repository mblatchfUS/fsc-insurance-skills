# FSC Insurance Product Examples

Real-world working patterns from production and demo orgs.

## Available Examples

### [Commercial Property — Multi-Level Rollup Pricing](commercial-property-pattern.md)

**Source:** Gartner/Celent 2026 reference org  
**Pattern:** Multi-level rollup with two-procedure design

**What you'll learn:**
- ✅ Two-procedure pattern (peril-level + rollup)
- ✅ ItemProductCode filtering (stable across localizations)
- ✅ Context Dictionary integration (inputs/outputs)
- ✅ Composite key matrices (FactorGroup + FactorKey)
- ✅ Multi-level aggregation (AggregationKeyLevel1/2/3)
- ✅ ProductClassification for insured items (Location)

**Use this pattern when:**
- Building multi-level product hierarchies
- Pricing perils/sub-coverages separately then rolling up
- Using insured items (Vehicles, Buildings, Locations)

---

## How to Use These Examples

1. **Read the pattern doc** to understand the design principles
2. **Query the reference org** to see the actual metadata structure
3. **Adapt to your LOB** by replacing product codes and risk dimensions
4. **Test end-to-end** to verify `PricingProcessExecution` records appear

## Reference Orgs

- **Gartner/Celent 2026** — Working FSC Insurance demo org (alias: `Gartner/Celent 2026`)
- **DigInsTrialOrgMay2026** — Fresh trial org for validation testing

## Key Lessons

### ✅ Do This
- Filter on `ItemProductCode` (stable), not `ProductName` (localizable)
- Bind all inputs/outputs to Context Dictionary, never Literals
- Use composite keys (`FactorGroup__c + FactorKey__c`) in matrices
- Create two procedures: one for item-level, one for rollup
- Verify `enablePCMConfigRules=true` before expecting pricing to work

### ❌ Don't Do This
- Hardcode org-specific IDs (RecordTypes, ProductRelationshipTypes, etc.)
- Use `vlocity_*` namespace (legacy, being phased out)
- Add custom `__c` fields to standard objects without checking org schema first
- Compare against AJG-Clements as baseline (custom Apex, non-standard)
- Assume field availability across orgs (`Product2.ProductPurpose` exists in some, not all)

## Contributing

Have a working pattern from another LOB? Add it here:
1. Document the product structure and key design decisions
2. Include working record IDs from a reference org
3. Explain adaptation notes for other LOBs
4. Add a PR to the repo
