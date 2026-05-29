# Commercial Property — Multi-Level Rollup Pricing Pattern

## Source

**Reference org:** Gartner/Celent 2026 (alias: `Gartner/Celent 2026`)  
**Working quote:** `0Q0Ws000007jRXtKAM` — "CP - ABC Enterprise"

This is the **gold standard** for FSC Insurance pricing with multi-level rollup:
- ✅ Pricing returns non-$0 values
- ✅ Multi-level product hierarchy (Root → Location → Building → Perils)
- ✅ Two-procedure pattern (peril-level + rollup)
- ✅ Insured item via ProductClassification (Location)

## Product Structure

```
Commercial Property (Root)
└── Location (ProductClassification link)
    └── Building (Coverage)
        ├── Fire / Lightning (Peril)
        ├── Explosion (Peril)
        ├── Smoke (Peril)
        ├── Vandalism / Malicious Mischief (Peril)
        ├── Water Damage (Peril)
        ├── Theft (Peril)
        ├── Windstorm / Hail (Peril)
        ├── Ordinance or Law (Peril)
        ├── Building Personal Property (Built-in)
        ├── Building Coverage (Built-in)
        ├── Business Income Interruption (Built-in)
        └── Earthquake (Optional)
```

## Key Design Patterns

### 1. Two-Procedure Pattern

**Procedure 1: Peril-Level Pricing**  
ESD: `CPPerilCoveragesPricingProcedure` (v2, `9QBWs000000TwkNOAS`)

- **When it runs:** For each peril/coverage line item
- **Filter:** `ItemProductCode IN ('cp-fire-lightning', 'cp-explosion', ...)`
- **Inputs:** Read from Context Dictionary (`BuildingValue`, `OccupancyType`, `ConstructionType`, `ProtectionClass`)
- **Logic:** Lookup rating factors via CalculationMatrix, apply to coverage limit
- **Outputs:** Write `PremiumValue__c` to Context Dictionary
- **Key:** Uses **composite keys** in matrices (`FactorGroup__c + FactorKey__c`) instead of multi-column input mappings

**Procedure 2: Rollup Pricing**  
ESD: `CPBaseCoveragesPricingProcedure` (v5, `9QBWs000000TwkQOAS`)

- **When it runs:** For root Commercial Property line item
- **Filter:** `ItemProductCode = 'commercial-property'`
- **Logic:** Aggregate all child coverage premiums via `AggregationKeyLevel1/2/3`
- **Outputs:** Write aggregated total to root line's `NetUnitPrice`

### 2. ItemProductCode Filtering

All filter expressions use `ItemProductCode` (stable) not `ProductName` (localizable):

```javascript
// Peril procedure filter
Context.Quote.ItemProductCode IN ['cp-fire-lightning', 'cp-explosion', 'cp-smoke', ...]

// Root procedure filter
Context.Quote.ItemProductCode == 'commercial-property'
```

### 3. Context Dictionary Integration

**Critical:** All procedure inputs/outputs bind to **Context Dictionary**, never Literals.

Example Context Dictionary entries:
- `BuildingValue` → `QuoteLineItem.BuildingValue__c`
- `OccupancyType` → `QuoteLineItem.OccupancyType__c`
- `PremiumValue__c` → `QuoteLineItem.PremiumValue__c` (output)

Context Dictionary acts as the **integration layer** between:
- Product Configurator UI → Context Dictionary → Pricing Procedure
- Pricing Procedure → Context Dictionary → Quote sObjects

### 4. Composite Key Matrices

Instead of multi-input CalculationMatrix columns like:

```
| ConstructionType | ProtectionClass | OccupancyType | Factor |
```

Use **composite keys**:

```
| FactorGroup__c | FactorKey__c | Factor |
| Construction   | Frame-1-Retail | 1.25  |
| Construction   | Masonry-2-Office | 0.85 |
```

Build keys at runtime: `ConstructionType + '-' + ProtectionClass + '-' + OccupancyType`

Benefits:
- Fewer matrix columns → simpler UI
- Easier to extend with new dimensions
- Cleaner SOQL queries

### 5. Multi-Level Aggregation

Use `AggregationKeyLevel1/2/3` to roll up premiums through the hierarchy:

```
Level 1: Peril → Building
Level 2: Building → Location
Level 3: Location → Root
```

Set these on ProductRelatedComponent to define rollup paths.

## Pricing Procedure Sequence

1. User clicks "Update Prices" in Product Configurator
2. `ProductQualificationProcessTypeHandler` fires (requires `enablePCMConfigRules=true`)
3. For each line item:
   - If peril/coverage → `CPPerilCoveragesPricingProcedure` runs, writes `PremiumValue__c`
   - If root → `CPBaseCoveragesPricingProcedure` runs, aggregates children
4. Platform writes final values to `QuoteLineItem.NetUnitPrice`
5. `PricingProcessExecution` record created (evidence of run)

## Quote Example

**Quote:** `0Q0Ws000007jRXtKAM`  
**Result:**
- Commercial Property root: `NetUnitPrice = $345,728.44`
- Location: `NetUnitPrice = $345,728.44`
- Building: `NetUnitPrice = $345,728.44`
- Fire / Lightning peril: `NetUnitPrice = $29,306.86`
- Vandalism: `NetUnitPrice = $2,686.32`

## Key Record IDs (Gartner/Celent 2026)

| Record | ID |
|---|---|
| ESD (CPPerilCoveragesPricingProcedure) | `9QBWs000000TwkNOAS` (v2) |
| ESD (CPBaseCoveragesPricingProcedure) | `9QBWs000000TwkQOAS` (v5) |
| Product2 (Commercial Property) | `01tWs00000DVQVNIA5` |
| ProductClassification (Location) | `11BWs0000008OUXMA2` |
| ContextDefinition (InsuranceContext) | `11OWs0000004CfgMAE` |

## Adaptation Notes

To adapt this pattern to a new Line of Business:

1. **Replace product codes** — change `cp-*` to your LOB prefix (e.g., `pd-*` for Physical Damage)
2. **Update filter expressions** — match your product structure
3. **Create LOB-specific matrices** — rating factors for your risk dimensions
4. **Map Context Dictionary** — bind to your QuoteLineItem custom fields
5. **Maintain two-procedure pattern** — one for item-level, one for rollup
6. **Test end-to-end** — verify `PricingProcessExecution` records appear

## References

- Salesforce doc: [Set Up Insurance Quoting](https://help.salesforce.com/s/articleView?id=ind.insurance_admin_set_up_quoting.htm&type=5)
- Salesforce doc: [Quote Configurator](https://help.salesforce.com/s/articleView?id=ind.insurance_admin_quote_configurator.htm&type=5)
- Internal skill: `creating-insurance-product` (v4.0)
