# Libraries
library(jsonlite)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(nanoparquet)

# Prepare storage
if (!dir.exists(config::get("path", config = "silver"))) {
  dir.create(config::get("path", config = "silver"), recursive = TRUE)
}

# Transform polls
df_polls <-
  read_json(path = config::get("polls", config = "bronze")) |>
  bind_rows() |>
  # Sněmovní volby, 2025
  filter(volby == 166) |>
  unnest_wider(col = entries, names_repair = "unique_quiet") |>
  select(
    poll_id = id...1,
    date_published = datum,
    date_from = from,
    date_to = to,
    agency,
    sample_size = amount,
    party,
    voteshare = value,
    error
  ) |>
  mutate(
    sample_size = replace_values(sample_size, -1 ~ NA),
    voteshare = voteshare / 100
  )

# Clean errors
df_polls_clean <-
  df_polls |>
  mutate(
    errors = if_else(
      is.na(error),
      NA,
      str_extract_all(error, r"(\d,\d)")
    )
  ) |>
  unnest_wider(errors, names_sep = "_", transform = \(x) {
    x |>
      str_replace(",", "\\.") |>
      as.numeric()
  }) |>
  rowwise() |>
  mutate(
    error_lower = min(errors_1, errors_2),
    error_upper = max(errors_1, errors_2),
    # error_upper = max(errors_1, errors_2, na.rm = TRUE)
  ) |>
  ungroup() |>
  select(-c(error, errors_1, errors_2))

# Write polls
write_parquet(
  x = df_polls_clean,
  file = config::get("polls", config = "silver")
)

# Transform parties
df_parties <-
  read_json(path = config::get("parties", config = "bronze")) |>
  map_df(\(x) {
    # Get primary data
    df <- tibble(
      party_id = x[["VSTRANA"]],
      party_shortcut = x[["ZKRATKA"]],
      party_name = x[["NAZEV"]]
    )

    # Add colors, if available
    color <- x$`$data`$color
    if (length(color) > 0) {
      df$party_color <- color[[1]]$value
    }

    df
  })

# Write parties
write_parquet(
  x = df_parties,
  file = config::get("parties", config = "silver")
)
