# AWS Pricing Calculator - Reverse Engineered API Documentation

> Complete reverse engineering of `calculator.aws` for building an MCP server that can generate valid AWS cost estimates.

## Architecture Overview

The AWS Pricing Calculator is a React SPA that:
1. Loads **service definitions** (JSON configs describing UI forms + pricing rules) from CloudFront
2. Fetches **pricing data** (metered unit maps) from `calculator.aws/pricing/2.0/`
3. Performs **all cost calculations client-side** using the pricing data + user inputs
4. Saves/loads **estimates** via a serverless API (API Gateway + Lambda + S3)

```
┌──────────────────────────────────────────────────────────────────┐
│                      calculator.aws (SPA)                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐   ┌──────────────┐   ┌───────────────────┐     │
│  │ Service      │   │ Pricing Data │   │ Estimate          │     │
│  │ Manifest     │   │ (Metered     │   │ Save/Load/Share   │     │
│  │ + Definitions│   │  Unit Maps)  │   │                   │     │
│  └──────┬───────┘   └──────┬───────┘   └────────┬──────────┘     │
│         │                  │                     │               │
└─────────┼──────────────────┼─────────────────────┼───────────────┘
          │                  │                     │
          ▼                  ▼                     ▼
  d1qsjq9pzbk1k6     calculator.aws        dnd5zrqcec4or
  .cloudfront.net     /pricing/2.0/        .cloudfront.net
  (Service Defs)      (Pricing Data)       (Save API)
```

---

## API Endpoints (All Verified Working)

### 1. Service Manifest — List of All 436 Services

```
GET https://d1qsjq9pzbk1k6.cloudfront.net/manifest/{locale}.json
```

**Locales**: `en_US`, `zh_CN`, `ja_JP`, `ko_KR`, `fr_FR`, `de_DE`, `es_ES`, `it_IT`, `pt_BR`, `id_ID`, `zh_TW`

**Response** (array of 436 services):
```json
{
  "awsServices": [
    {
      "name": "Amazon EC2",
      "serviceCode": "eC2Next",
      "description": "...",
      "searchKeywords": ["EC2", "compute", ...],
      "type": "AWSService",
      "subType": "subService",           // optional - means it's a sub-calculator
      "regions": ["us-east-1", ...],
      "linkUrl": "https://aws.amazon.com/ec2/",
      "isActive": "true",
      "disableConfigure": false,
      "serviceDefinitionLocation": "https://d1qsjq9pzbk1k6.cloudfront.net/data/eC2Next/en_US.json",
      "serviceDefinitionUrlPath": "/data/eC2Next/en_US.json",
      "c2e": false,
      "MVPSupport": false,
      "templates": [],
      "disableRegionSupport": false,
      "slug": "EC2"
    }
  ]
}
```

**Service breakdown**: 201 main services, 235 sub-services, 436 total.

### 2. Service Definitions — Calculator Configuration per Service

```
GET https://d1qsjq9pzbk1k6.cloudfront.net/data/{serviceCode}/{locale}.json
```

**Example**: `https://d1qsjq9pzbk1k6.cloudfront.net/data/amazonS3/en_US.json`

**Response structure**:
```json
{
  "version": "0.0.1",
  "serviceName": "Amazon S3",
  "serviceCode": "amazonS3",
  "type": "AWSService",
  "regions": ["us-east-1", "us-east-2", ...],
  "serviceDescription": "...",
  "linkUrl": "https://aws.amazon.com/s3",
  "mappingDefinitions": [
    {
      "mappingDefinitionName": "amazonS3pricingjson",
      "mappingDefinitionURL": "pricing/2.0/meteredUnitMaps/s3/[currency]/current/s3.json"
    }
  ],
  "costType": ["Monthly"],
  "layout": "simple",
  "templates": [/* see Template Structure below */]
}
```

### 3. Pricing Data — Metered Unit Maps (What the Calculator Uses for Calculations)

```
GET https://calculator.aws/pricing/2.0/meteredUnitMaps/{service}/{currency}/current/{file}.json
```

**Known pricing paths** (extracted from JS bundle):
| Service | Path |
|---------|------|
| S3 | `s3/USD/current/s3.json` |
| EC2 EBS | `ec2/USD/current/ebs-calculator.json` |
| EC2 ELB | `ec2/USD/current/elb.json` |
| Data Transfer | `datatransfer/USD/current/datatransfer-calc.json` |
| Lambda | — (uses Bulk Pricing API directly) |
| Athena | `athena/USD/current/athena.json` |
| Chime | `chime/USD/current/chime.json` |
| DocumentDB | `docdb/USD/current/docdb-calc.json` |
| EFS | `efs/USD/current/efs.json` |
| Glacier | `glacier/USD/current/glacier.json` |
| KMS | `kms/USD/current/kms.json` |
| MQ | `mq/USD/current/mq.json` |
| RDS Aurora MySQL | `rds/USD/current/rds-aurora-mysql-calc.json` |
| RDS Storage | `rds/USD/current/rds-storage.json` |
| SES | `ses/USD/current/ses.json` |
| Storage Gateway | `storagegateway/USD/current/storagegateway.json` |
| WorkSpaces | `workspaces/USD/current/workspaces.json` |

**Response format** (metered unit map):
```json
{
  "manifest": {
    "serviceId": "s3",
    "accessType": "publish",
    "currencyCode": "USD",
    "hawkFilePublicationDate": "2026-02-23T23:22:15Z"
  },
  "sets": {},
  "regions": {
    "US West (Oregon)": {
      "<hash_key>": {
        "rateCode": "X8PQPAR4ATC828TS.JRTCKXETXF.6YS6EN2CT7",
        "price": "0.0007000000",
        "RegionlessRateCode": "<hash_key>"
      }
    },
    "US East (N. Virginia)": { ... },
    ...
  }
}
```

### 4. EC2 Instance Types

```
GET https://dzzn6wbl7e9ou.cloudfront.net/instance-types-{region}.json
```

**Example**: `https://dzzn6wbl7e9ou.cloudfront.net/instance-types-us-east-1.json`

Returns instance type metadata (arch, cores, threads).

### 5. EC2 Savings Plans Pricing

```
GET https://b0.p.awsstatic.com/pricing/2.0/meteredUnitMaps/computesavingsplan/{path}
```

### 6. EC2 Spot Pricing

```
GET https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json
```

### 7. Bulk Pricing API (AWS Official)

```
GET https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/index.json
```

Returns index of all 500+ AWS services with links to their detailed pricing.

**Per-service pricing**:
```
GET https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/{serviceCode}/current/index.json
GET https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/{serviceCode}/current/region_index.json
GET https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/{serviceCode}/current/{region}/index.json
```

**Bulk pricing data model**:
```json
{
  "formatVersion": "v1.0",
  "offerCode": "AWSLambda",
  "version": "20260316225720",
  "publicationDate": "2026-03-16T22:57:20Z",
  "products": {
    "<SKU>": {
      "sku": "8MV6QCXGTMB3SQSA",
      "productFamily": "Serverless",
      "attributes": {
        "servicecode": "AWSLambda",
        "location": "US East (N. Virginia)",
        "locationType": "AWS Region",
        "usagetype": "Lambda-Managed-Instances-m7a.large-Management-Hours",
        "operation": "",
        "regionCode": "us-east-1",
        "servicename": "AWS Lambda"
      }
    }
  },
  "terms": {
    "OnDemand": {
      "<SKU>": {
        "<SKU>.<OfferTermCode>": {
          "offerTermCode": "JRTCKXETXF",
          "sku": "<SKU>",
          "effectiveDate": "2026-03-01T00:00:00Z",
          "priceDimensions": {
            "<rateCode>": {
              "rateCode": "<SKU>.<OfferTermCode>.<rateId>",
              "description": "$0.1632 per Hour for ...",
              "beginRange": "0",
              "endRange": "Inf",
              "unit": "Hours",
              "pricePerUnit": { "USD": "0.1632000000" },
              "appliesTo": []
            }
          },
          "termAttributes": {}
        }
      }
    }
  }
}
```

### 8. Save Estimate API

```
POST https://dnd5zrqcec4or.cloudfront.net/Prod/v2/saveAs
```

**Request**: Serialized estimate JSON (the entire rootGroup state)
**Response**:
```json
{
  "body": "{\"savedKey\": \"<estimate-id>\"}"
}
```

The savedKey becomes the `?id=` parameter: `https://calculator.aws/estimate?id=<savedKey>`

### 9. Load Saved Estimate

```
GET https://d3knqfixx3sbls.cloudfront.net/{estimateKey}
```

Returns the full estimate JSON for a previously saved estimate.

### 10. PDF Export

```
POST https://dg7avmwizdsta.cloudfront.net/Prod/pdfexport
```

### 11. GraphQL API

```
POST https://7bena91p37.execute-api.us-west-2.amazonaws.com/Prod/v1/graphql
```

### 12. Bulk Import Templates

```
GET https://d1qsjq9pzbk1k6.cloudfront.net/data/{serviceCode}/bulkImport/{fileName}
```

---

## Service Definition Template Structure

This is the core of how the calculator works. Each service has a JSON definition that describes:
- What **input fields** to show the user
- What **pricing lookups** to perform
- What **math operations** to calculate costs

### Component Types

#### Input Components
```json
{
  "type": "input",
  "subType": "fileSize | numericInput | dropdown | radio | checkbox",
  "label": "S3 Standard Storage",
  "id": "s3Services_generated_0",
  "dropDownSize": [
    {"label": "GB", "value": "gb"},
    {"label": "TB", "value": "tb"}
  ],
  "defaultOption": {"size": "gb", "frequency": "NA"},
  "outputSize": "gb",
  "validations": {
    "required": true,
    "allowDecimals": true,
    "minValue": 0,
    "maxValue": 1000000000000
  },
  "placeholder": "Enter amount",
  "displayInConfigSummary": true
}
```

#### Pricing Components
```json
{
  "type": "pricing",
  "subType": "tieredPricing | simplePricing | pricingPLC2",
  "mappingDefinitionName": "amazonS3pricingjson",
  "label": "Pricing for Standard S3 Storage",
  "tiers": {
    "allRegions": [
      {"startOfTier": 0, "endOfTier": 51200, "meteredUnit": "General Purpose Standard 0"},
      {"startOfTier": 51201, "endOfTier": 512000, "meteredUnit": "General Purpose Standard 51200"},
      {"startOfTier": 512000, "endOfTier": -1, "meteredUnit": "General Purpose Standard 512000"}
    ]
  },
  "id": "s3Services_generated_4"
}
```

#### Math Components
```json
{
  "type": "maths",
  "subType": "tieredPricingMath | simpleMath | multiplicationMath",
  "tieredPricingReferLabel": "Pricing for Standard S3 Storage",
  "inputReferLabel": "S3 Standard Storage",
  "outputUnitLabel": "[currency] (data written to AWS storage cost)",
  "inputUnitLabel": "GB",
  "inputRefer": "s3Services_generated_0",
  "tieredPricingRefer": "s3Services_generated_4"
}
```

#### Display Components
```json
{
  "type": "display",
  "subType": "priceDisplay",
  "costType": "Monthly",
  "label": "S3 Storage fee",
  "decimalPlaces": 2,
  "subTotalRefer": "s3Services_generated_5",
  "refer": ["s3Services_generated_0", ...]
}
```

### Calculation Flow

1. **User inputs** value (e.g., 100 GB of S3 storage)
2. **Pricing component** looks up the metered unit map for the selected region
3. **Math component** multiplies: `quantity × price_per_unit` (or applies tiered pricing)
4. **Display component** shows the monthly/hourly cost

For tiered pricing:
```
if quantity <= tier1.endOfTier:
    cost = quantity * tier1.price
elif quantity <= tier2.endOfTier:
    cost = tier1.endOfTier * tier1.price + (quantity - tier1.endOfTier) * tier2.price
...
```

---

## Estimate Data Model

The calculator stores estimates as a tree:

```
Estimate (root)
├── title: "My Estimate"
├── groups: [
│   ├── Group 1: "Web Tier"
│   │   ├── services: [
│   │   │   ├── Service Config 1 (EC2)
│   │   │   │   ├── serviceCode: "eC2Next"
│   │   │   │   ├── region: "us-east-1"
│   │   │   │   ├── inputs: { componentId → value }
│   │   │   │   └── costs: { monthly: 150.00, upfront: 0 }
│   │   │   └── Service Config 2 (RDS)
│   │   └── subTotal: { monthly: 450.00 }
│   └── Group 2: "Data Tier"
│       └── ...
└── total: { monthly: 1200.00, upfront: 500.00 }
```

The estimate is stored in browser localStorage under key `root-estimate-v1`.

### Share URL Format
```
https://calculator.aws/estimate?id={savedKey}
```

When sharing:
1. Calculator serializes the entire `rootGroup` state to JSON
2. POSTs to `https://dnd5zrqcec4or.cloudfront.net/Prod/v2/saveAs`
3. Gets back a `savedKey`
4. Generates URL: `calculator.aws/estimate?id={savedKey}`

---

## Calculator Configuration (PRC_CONFIG)

The calculator has a global config (`window.PRC_CONFIG`) with:

### Feature Flags
```json
{
  "FEATURE_FLAGS": {
    "APERTURE_FEEDBACK_FORM": true,
    "AWS_SUPPORT": true,
    "BULK_ESTIMATOR": true,
    "EC2_REDESIGN": true,
    "EC2_SAVINGS_PLAN": true,
    "NOTIFICATION": true,
    "SMC_DEPRECIATION": true,
    "STATS": true,
    "WINDOWS_WORKLOADS": true,
    "PANORAMA": true
  }
}
```

### Cross-Partition Support
Supports: `aws` (commercial), `aws-us-gov` (GovCloud), `aws-iso` (Top Secret), `aws-iso-b` (Secret)

### Volume Discounts
Enabled via query params: `c2e`, `ctrct`, `token`

---

## MCP Server Implementation Strategy

### Recommended Tools for the MCP

#### 1. `list_aws_services`
Fetches and returns the service manifest (436 services with codes, names, regions).

#### 2. `get_service_definition`
Fetches the full service definition JSON for a given `serviceCode` and `locale`.

#### 3. `get_pricing_data`
Fetches metered unit map pricing for a service/region/currency combination.

#### 4. `calculate_service_cost`
Given a serviceCode, region, and input parameters, performs the same calculation the browser does:
- Loads service definition
- Loads pricing data
- Applies inputs to pricing tiers
- Returns itemized cost breakdown

#### 5. `create_estimate`
Builds a complete estimate (multiple services, grouped) and returns:
- Itemized cost breakdown
- Total monthly/annual cost
- A shareable calculator.aws URL (via the save API)

#### 6. `get_estimate`
Loads a previously saved estimate by its ID.

#### 7. `list_ec2_instance_types`
Returns instance types available in a region with specs.

### Data Flow for Cost Calculation

```python
# Pseudocode for calculating S3 costs

# 1. Load service definition
svc_def = fetch(f"https://d1qsjq9pzbk1k6.cloudfront.net/data/amazonS3/en_US.json")

# 2. Load pricing data
pricing_url = svc_def["mappingDefinitions"][0]["mappingDefinitionURL"]
pricing_url = pricing_url.replace("[currency]", "USD")
pricing = fetch(f"https://calculator.aws/{pricing_url}")

# 3. Look up price for region and metered unit
region_pricing = pricing["regions"]["US East (N. Virginia)"]
# Each entry has: rateCode, price, RegionlessRateCode

# 4. Match metered unit from tier definition to pricing entry
# The service definition's tiered pricing component has "meteredUnit" names
# These correspond to entries in the metered unit map via the rate code mapping

# 5. Calculate
tier1_price = float(region_pricing[hash_for_tier1]["price"])
tier2_price = float(region_pricing[hash_for_tier2]["price"])

if storage_gb <= 51200:
    cost = storage_gb * tier1_price
elif storage_gb <= 512000:
    cost = 51200 * tier1_price + (storage_gb - 51200) * tier2_price
# ... etc
```

### Key Implementation Notes

1. **All calculations are client-side** — the calculator has no server-side calculation API. Your MCP must replicate the math.

2. **Pricing data uses hashed keys** — The metered unit maps use hash-based keys (e.g., `"-CXH_xScb_..."`) that map to rate codes. The service definitions reference "metered units" by name (e.g., `"General Purpose Standard 0"`), and you need to resolve these via the pricing data's rate codes.

3. **The `[currency]` placeholder** in mapping definition URLs should be replaced with `USD`, `CNY`, etc.

4. **Rate codes follow the pattern**: `{SKU}.{OfferTermCode}.{RateId}` where `JRTCKXETXF` = On-Demand.

5. **Lotus packages** — Some services (especially newer ones) use dynamically loaded "Lotus" packages from CloudFront. These are separate JS bundles that contain the calculator logic for that service. The older services use the JSON template system described above.

6. **The save API requires no authentication** for public estimates — it's a simple POST that returns a key.

---

## CloudFront Distribution Map

| Distribution | Purpose |
|---|---|
| `d1qsjq9pzbk1k6.cloudfront.net` | Service definitions, manifests, bulk import templates |
| `d3pv0p0lgn4sbz.cloudfront.net` | Pricing data (us-east-1, production) |
| `d1cec4jo95y6k9.cloudfront.net` | Pricing data (us-west-2, production) |
| `d1jsol0ugtvlyg.cloudfront.net` | Pricing data (us-east-1, default/dev) |
| `d2xkhmkdbp06as.cloudfront.net` | Pricing data (us-west-2, default/dev) |
| `dnd5zrqcec4or.cloudfront.net` | Save estimate API |
| `d3knqfixx3sbls.cloudfront.net` | Load saved estimate |
| `dg7avmwizdsta.cloudfront.net` | PDF export API |
| `dzzn6wbl7e9ou.cloudfront.net` | EC2 instance types navigator |
| `s3.us-east-2.amazonaws.com/aws.calculator.platform.assets` | Static assets (workload images) |

---

## Service Codes Reference (Popular Services)

| Service | Code | Slug |
|---------|------|------|
| Amazon EC2 | `eC2Next` | `EC2` |
| AWS Lambda | `aWSLambda` | `Lambda` |
| Amazon S3 | `amazonS3` | — |
| Amazon RDS MySQL | `amazonRDSMySQLDB` | `RDSMySQL` |
| Amazon RDS PostgreSQL | `amazonRDSPostgreSQLDB` | — |
| Amazon RDS Aurora MySQL | `amazonRDSAuroraMySqlCompatibleDB` | — |
| Amazon RDS Aurora PostgreSQL | `amazonRDSAuroraPostgreSQLCompatibleDB` | — |
| Amazon DynamoDB | `amazonDynamoDB` | — |
| AWS Fargate | `awsFargate` | `Fargate` |
| Amazon CloudFront | `amazonCloudFront` | `CloudFront` |
| Amazon ECS | `amazonECS` | — |
| Amazon EKS | `amazonEKS` | — |
| AWS Data Transfer | `aWSDataTransfer` | — |
| Amazon EFS | `amazonEFS` | — |
| Amazon ElastiCache | `amazonElasticache` | — |
| Amazon SQS | `amazonSQS` | — |
| Amazon SNS | `amazonSNS` | — |
| Amazon API Gateway | `amazonApiGateway` | — |
| AWS Storage Gateway | `aWSStorageGateway` | — |
| Amazon Bedrock | `amazonBedrock` | — |

Full list: 436 services available via the manifest API.

---

## Export Formats

The calculator supports three export formats:
1. **JSON** — Full estimate data as structured JSON
2. **CSV** — Tabular cost breakdown
3. **PDF** — Formatted PDF via the export API

---

## Frontend Application Details

- **Framework**: React (Create React App)
- **Bundle**: `static/js/bundle.js` (~8.9 MB minified)
- **Lazy-loaded chunks**: `static/js/{chunkId}.bundle.js`
- **CSS**: `static/css/main.b1abd0c1.css`
- **Config**: `config.js` (dynamic, contains `window.PRC_CONFIG`)
- **Base path**: `b2b2e861-58f8-4b04-bb59-818f2d550ab5/[AWSMarketingPricingCalculatorPlatformFrontEndUI-1.0]pkg.configfarm.frontend_ui_assets/frontend_ui_assets`
- **State management**: Redux (estimate stored as `root-estimate-v1` in localStorage)
- **Math library**: Uses `BigNumber.js` for precise decimal arithmetic

---

## Existing Implementations & Official APIs

### Existing MCP Server: Musheer360/aws-calculator-mcp

**GitHub**: https://github.com/Musheer360/aws-calculator-mcp
**License**: MIT

An existing open-source MCP server (TypeScript) that has already reverse-engineered the calculator.aws REST APIs. Uses the same unauthenticated CloudFront endpoints documented above. This is the most complete public implementation.

**5 MCP Tools Exposed**:

| Tool | Description |
|------|-------------|
| `search_services` | Search 436+ AWS services by keyword, returns serviceCodes |
| `get_service_schema` | Get full input schema for a service (form fields, dropdowns, validations) |
| `configure_service` | Configure a service with inputs, fetches real-time pricing, calculates costs |
| `create_estimate` | Build multi-service estimate, save via API, return shareable calculator.aws URL |
| `load_estimate` | Load existing estimate by ID or URL |

**`create_estimate` input format** (what the MCP tool accepts):
```json
{
  "name": "My Estimate",
  "services": [
    {
      "serviceCode": "eC2Next",
      "region": "us-east-1",
      "serviceName": "Amazon EC2",
      "monthlyCost": 123.45,
      "upfrontCost": 0,
      "configSummary": "t3.medium, Linux, On-Demand",
      "calculationComponents": { "<fieldId>": "<value>" },
      "templateId": "quickEstimate",
      "group": "Web Tier"
    }
  ]
}
```

**Key implementation details from the source**:
- Uses `configure_service` to fetch real-time pricing and auto-calculate costs
- `calculationComponents` keys are field IDs from `get_service_schema` (e.g., `s3Services_generated_0`)
- For dropdown fields, use the `value` property (not `label`) from options
- For frequency/fileSize fields, provide `{ value: number, unit: "unitString" }`
- Services can be organized into named groups
- Costs are auto-calculated if `monthlyCost` is 0

### Official AWS Pricing Calculator API (Authenticated)

AWS now offers an **official, authenticated API** as part of Billing and Cost Management with 38 operations:

**Endpoint**: `bcm-pricing-calculator.{region}.amazonaws.com`

**Key Operations**:
- **Bill Estimates**: `CreateBillEstimate`, `GetBillEstimate`, `ListBillEstimates`, `ListBillEstimateLineItems`, `ListBillEstimateCommitments`
- **Bill Scenarios**: `CreateBillScenario`, `GetBillScenario`, `ListBillScenarios`, plus batch operations for commitment/usage modifications
- **Workload Estimates**: `CreateWorkloadEstimate`, `GetWorkloadEstimate`, `ListWorkloadEstimates`, plus batch operations for usage
- **Preferences**: `GetPreferences`, `UpdatePreferences`

This API supports modeling Savings Plans, Reserved Instances, and benefit-sharing preferences. Requires IAM authentication.

**Docs**: https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_Operations_AWS_Billing_and_Cost_Management_Pricing_Calculator.html

### AWS Price List API (Raw Pricing Data)

```
GET https://api.pricing.us-east-1.amazonaws.com  (requires IAM auth)
GET https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/index.json  (public, no auth)
```

- **Price List Query API** — Programmatic queries by product attributes at SKU level (requires IAM)
- **Price List Bulk API** — Download full price list files in JSON/CSV by service and region (public)

### Other Tools
- **[awslabs/mcp PR #1247](https://github.com/awslabs/mcp/pull/1247)** — Official AWS MCP adding Workload Estimate support
- **[lyft/awspricing](https://github.com/lyft/awspricing)** — Python library wrapping the Price List Query API
- **[concurrencylabs/aws-pricing-tools](https://github.com/concurrencylabs/aws-pricing-tools)** — Lambda-based pricing tools

---

## Save Estimate Request Body Format

The POST to `https://dnd5zrqcec4or.cloudfront.net/Prod/v2/saveAs` accepts:

```json
{
  "name": "My Estimate",
  "services": {
    "<serviceId>": {
      "version": "0.0.1",
      "serviceCode": "amazonS3",
      "estimateFor": "amazonS3",
      "region": "us-east-1",
      "description": "S3 estimate",
      "calculationComponents": {
        "s3Services_generated_0": 100,
        "s3Services_generated_1": 10000
      },
      "serviceCost": { "monthly": 2.35, "upfront": 0 },
      "serviceName": "Amazon S3",
      "regionName": "US East (N. Virginia)",
      "configSummary": "100 GB Standard Storage",
      "templateId": "template_0"
    }
  },
  "groups": {
    "<groupId>": {
      "name": "My Group",
      "services": ["<serviceId>"]
    }
  },
  "groupSubtotal": { "monthly": 2.35, "upfront": 0 },
  "totalCost": { "monthly": 2.35, "upfront": 0 },
  "support": {},
  "metaData": {
    "locale": "en_US",
    "currency": "USD",
    "createdOn": "2026-03-20T00:00:00Z",
    "source": "calculator.aws"
  }
}
```

**Response**: `{ "statusCode": 201, "body": "{\"savedKey\": \"abc123...\"}" }`

The `savedKey` creates a shareable URL: `https://calculator.aws/#/estimate?id={savedKey}`

**Notes**:
- Uses hash routing (`#/estimate`), not path routing
- Links expire after **1 year** (for estimates created after May 31, 2023)
- Each save generates a **new** ID; updates don't modify the original link
- No AWS account required to view shared estimates

---

## Two Separate AWS Pricing Calculator Systems

AWS has **two completely different** pricing calculator systems:

| | Public Calculator | In-Console BCM API |
|---|---|---|
| **URL** | `calculator.aws` | AWS Console / SDK |
| **Auth** | None required | IAM authentication |
| **API** | Undocumented CloudFront endpoints | Official `bcm-pricing-calculator` API |
| **SDK** | None | `@aws-sdk/client-bcm-pricing-calculator` |
| **Region** | N/A | `us-east-1` only |
| **Cost** | Free | Workload estimates free; Bill estimates $2 each after 5/month |
| **CLI** | N/A | `aws bcm-pricing-calculator create-workload-estimate` |

For building an MCP, the **public calculator** (undocumented) is more accessible since it requires no auth. The **BCM API** is the officially supported path but requires AWS credentials.
