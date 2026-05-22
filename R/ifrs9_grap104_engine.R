# IFRS 9 + GRAP 104 Big Data Actuarial Calculation Engine
# Author: Troden Mukwasi / Clarionmark-style actuarial engine

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(duckdb)
  library(DBI)
  library(arrow)
  library(jsonlite)
})

# -----------------------------
# 1. Data validation
# -----------------------------
validate_portfolio <- function(portfolio) {
  required_cols <- c(
    "instrument_id", "entity", "product_type", "sector", "province",
    "days_past_due", "current_rating", "origination_rating",
    "ead", "lgd", "pd_12m", "pd_lifetime", "eir", "remaining_years",
    "measurement_category"
  )
  missing_cols <- setdiff(required_cols, names(portfolio))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  portfolio
}

validate_scenarios <- function(scenarios) {
  required_cols <- c("scenario", "weight", "pd_multiplier", "lgd_multiplier")
  missing_cols <- setdiff(required_cols, names(scenarios))
  if (length(missing_cols) > 0) {
    stop(paste("Missing scenario columns:", paste(missing_cols, collapse = ", ")))
  }
  if (abs(sum(scenarios$weight) - 1) > 0.0001) {
    stop("Scenario weights must sum to 1.00")
  }
  scenarios
}

# -----------------------------
# 2. IFRS 9 / GRAP 104 staging
# -----------------------------
assign_ecl_stage <- function(portfolio,
                             sicr_rating_notches = 2,
                             stage2_dpd = 30,
                             stage3_dpd = 90) {
  portfolio %>%
    mutate(
      rating_deterioration = current_rating - origination_rating,
      stage = case_when(
        days_past_due >= stage3_dpd ~ 3L,
        days_past_due >= stage2_dpd | rating_deterioration >= sicr_rating_notches ~ 2L,
        TRUE ~ 1L
      ),
      ecl_horizon = case_when(
        stage == 1L ~ "12-month ECL",
        stage %in% c(2L, 3L) ~ "Lifetime ECL",
        TRUE ~ "Unclassified"
      )
    )
}

# -----------------------------
# 3. Measurement category mapping
# -----------------------------
map_measurement_category <- function(portfolio) {
  portfolio %>%
    mutate(
      grap104_measurement_bucket = case_when(
        measurement_category %in% c("amortised_cost", "amortized_cost") ~ "Amortised cost",
        measurement_category %in% c("fvoci", "fair_value_through_net_assets") ~ "Fair value through net assets / FVOCI equivalent",
        measurement_category %in% c("fvsd", "fair_value_surplus_deficit", "fvtpl") ~ "Fair value through surplus or deficit",
        TRUE ~ "Other / review required"
      ),
      impairment_required = case_when(
        grap104_measurement_bucket %in% c("Amortised cost", "Fair value through net assets / FVOCI equivalent") ~ TRUE,
        TRUE ~ FALSE
      )
    )
}

# -----------------------------
# 4. Core ECL calculation
# -----------------------------
calculate_ecl <- function(portfolio, scenarios) {
  portfolio <- validate_portfolio(portfolio)
  scenarios <- validate_scenarios(scenarios)

  staged <- portfolio %>%
    assign_ecl_stage() %>%
    map_measurement_category()

  expanded <- merge(staged, scenarios, all = TRUE)

  expanded %>%
    mutate(
      pd_used = ifelse(stage == 1L, pd_12m, pd_lifetime),
      adjusted_pd = pmin(pd_used * pd_multiplier, 1),
      adjusted_lgd = pmin(lgd * lgd_multiplier, 1),
      discount_factor = 1 / ((1 + eir) ^ pmax(remaining_years, 0)),
      gross_ecl = adjusted_pd * adjusted_lgd * ead,
      discounted_ecl = ifelse(stage == 1L, gross_ecl, gross_ecl * discount_factor),
      weighted_ecl = ifelse(impairment_required, discounted_ecl * weight, 0),
      provision_status = ifelse(impairment_required, "ECL recognised", "No ECL allowance - fair value category")
    ) %>%
    group_by(
      instrument_id, entity, product_type, sector, province,
      stage, ecl_horizon, measurement_category,
      grap104_measurement_bucket, impairment_required, provision_status, ead
    ) %>%
    summarise(
      ifrs9_grap104_ecl = sum(weighted_ecl, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      coverage_ratio = ifelse(ead > 0, ifrs9_grap104_ecl / ead, 0)
    )
}

# -----------------------------
# 5. Big data processing
# -----------------------------
calculate_ecl_bigdata <- function(portfolio_path, scenarios_path, output_path = "output/ecl_results.parquet") {
  scenarios <- read_csv(scenarios_path, show_col_types = FALSE)
  validate_scenarios(scenarios)

  portfolio <- open_dataset(portfolio_path, format = "csv") %>% collect()
  portfolio <- validate_portfolio(portfolio)

  result <- calculate_ecl(portfolio, scenarios)

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  write_parquet(result, output_path)
  result
}

# -----------------------------
# 6. Portfolio summaries
# -----------------------------
summarise_ecl <- function(ecl_results) {
  list(
    by_stage = ecl_results %>%
      group_by(stage, ecl_horizon) %>%
      summarise(total_ead = sum(ead), total_ecl = sum(ifrs9_grap104_ecl), coverage_ratio = total_ecl / total_ead, .groups = "drop"),

    by_product = ecl_results %>%
      group_by(product_type) %>%
      summarise(total_ead = sum(ead), total_ecl = sum(ifrs9_grap104_ecl), coverage_ratio = total_ecl / total_ead, .groups = "drop"),

    by_sector = ecl_results %>%
      group_by(sector) %>%
      summarise(total_ead = sum(ead), total_ecl = sum(ifrs9_grap104_ecl), coverage_ratio = total_ecl / total_ead, .groups = "drop"),

    by_province = ecl_results %>%
      group_by(province) %>%
      summarise(total_ead = sum(ead), total_ecl = sum(ifrs9_grap104_ecl), coverage_ratio = total_ecl / total_ead, .groups = "drop"),

    by_measurement = ecl_results %>%
      group_by(grap104_measurement_bucket, provision_status) %>%
      summarise(total_ead = sum(ead), total_ecl = sum(ifrs9_grap104_ecl), coverage_ratio = ifelse(total_ead > 0, total_ecl / total_ead, 0), .groups = "drop")
  )
}

# -----------------------------
# 7. Journal/reporting output
# -----------------------------
generate_impairment_journal <- function(ecl_results, previous_allowance = 0) {
  current_allowance <- sum(ecl_results$ifrs9_grap104_ecl, na.rm = TRUE)
  movement <- current_allowance - previous_allowance

  data.frame(
    journal_line = c(1, 2),
    account = ifelse(movement >= 0,
                     c("Impairment loss - surplus or deficit", "Loss allowance - financial assets"),
                     c("Loss allowance - financial assets", "Impairment gain - surplus or deficit")),
    debit = c(max(movement, 0), max(-movement, 0)),
    credit = c(max(-movement, 0), max(movement, 0)),
    description = "IFRS 9 / GRAP 104 expected credit loss allowance movement"
  )
}
