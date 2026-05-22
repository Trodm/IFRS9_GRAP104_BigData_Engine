library(plumber)
library(jsonlite)
library(readr)
source("R/ifrs9_grap104_engine.R")

#* Health check
#* @get /health
function() {
  list(status = "ok", engine = "IFRS 9 + GRAP 104 Big Data ECL Engine")
}

#* Example calculation
#* @get /example
function() {
  portfolio <- read_csv("sample_data/loan_portfolio_sample.csv", show_col_types = FALSE)
  scenarios <- read_csv("sample_data/macro_scenarios.csv", show_col_types = FALSE)
  results <- calculate_ecl(portfolio, scenarios)
  summary <- summarise_ecl(results)
  list(results = results, summary_by_stage = summary$by_stage, summary_by_measurement = summary$by_measurement)
}

#* Calculate ECL from JSON payload
#* @post /calculate
function(req) {
  payload <- fromJSON(req$postBody)
  portfolio <- as.data.frame(payload$portfolio)
  scenarios <- as.data.frame(payload$scenarios)
  previous_allowance <- ifelse(is.null(payload$previous_allowance), 0, payload$previous_allowance)

  results <- calculate_ecl(portfolio, scenarios)
  summary <- summarise_ecl(results)
  journal <- generate_impairment_journal(results, previous_allowance)

  list(results = results, summary = summary, journal = journal)
}
