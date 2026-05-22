source("R/ifrs9_grap104_engine.R")

portfolio <- readr::read_csv("sample_data/loan_portfolio_sample.csv", show_col_types = FALSE)
scenarios <- readr::read_csv("sample_data/macro_scenarios.csv", show_col_types = FALSE)

results <- calculate_ecl(portfolio, scenarios)
print(results)

summary <- summarise_ecl(results)
print(summary$by_stage)
print(summary$by_measurement)

journal <- generate_impairment_journal(results, previous_allowance = 25000)
print(journal)

readr::write_csv(results, "output/ecl_results.csv")
readr::write_csv(summary$by_stage, "output/ecl_summary_by_stage.csv")
readr::write_csv(journal, "output/ecl_journal.csv")
