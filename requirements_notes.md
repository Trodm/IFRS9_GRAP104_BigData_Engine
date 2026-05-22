# R Package Requirements

Install locally in R:

```r
install.packages(c(
  "plumber",
  "jsonlite",
  "dplyr",
  "readr",
  "duckdb",
  "DBI",
  "arrow"
))
```

For Render, the Dockerfile installs these automatically.

## Big Data Notes

For very large datasets:

- Store portfolio data as Parquet instead of CSV where possible.
- Use Arrow datasets for partitioned data.
- Use DuckDB for SQL-style queries over millions of rows.
- Process by reporting date, entity, product type or province to reduce memory pressure.
- Save calculated ECL results to Parquet for Power BI or actuarial reporting.
