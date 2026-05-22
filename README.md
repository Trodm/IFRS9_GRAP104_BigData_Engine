# IFRS 9 + GRAP 104 Big Data Actuarial Calculation Engine in R

This package extends the IFRS 9 Expected Credit Loss (ECL) engine so it can be used for large portfolios and GRAP 104 financial instruments reporting.

## Purpose

The engine supports:

- IFRS 9 ECL calculations
- GRAP 104 financial instruments impairment calculations
- Stage 1, Stage 2 and Stage 3 impairment logic
- 12-month and lifetime ECL
- Forward-looking macroeconomic scenarios
- Big-data processing using Apache Arrow and DuckDB
- Portfolio segmentation
- Financial instrument classification support
- Journal-ready impairment summaries
- Reporting by stage, product, sector, province, rating band and institution

## Key Formula

ECL = PD × LGD × EAD × Discount Factor × Scenario Weight

## GRAP 104 Alignment

GRAP 104 deals with financial instruments in the public sector. The revised impairment approach uses expected credit losses, which is broadly aligned with IFRS 9 principles. This engine therefore supports both private-sector IFRS 9 and public-sector GRAP 104 impairment workflows.

## Main Files

- `R/ifrs9_grap104_engine.R` - core calculation engine
- `api.R` - Plumber API for Render deployment
- `example_run.R` - local test script
- `sample_data/loan_portfolio_sample.csv` - sample portfolio
- `sample_data/macro_scenarios.csv` - macroeconomic scenario assumptions
- `Dockerfile` - Render deployment file
- `render.yaml` - Render deployment configuration
- `requirements_notes.md` - package installation notes

## Local Run

```r
source("example_run.R")
```

## API Endpoints

After deployment:

- `/health`
- `/example`
- `/calculate`

## Render Deployment

Use Docker environment on Render.

Health check path:

```text
/health
```

