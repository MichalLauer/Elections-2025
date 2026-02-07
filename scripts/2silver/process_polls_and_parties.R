# Libraries
library(jsonlite)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(nanoparquet)
library(forcats)

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
  reframe(
    poll_id = id...1,
    date_published = as.Date(datum),
    date_from = as.Date(from),
    date_to = as.Date(to),
    agency = agency,
    sample_size = amount,
    party = party,
    voteshare = value,
    error
  ) |>
  mutate(
    sample_size = replace_values(sample_size, -1 ~ NA),
    voteshare = voteshare / 100
  )

# Clean errors
df_polls <-
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

# # Compute party of "Others"
# df_polls <-
#   df_polls |>
#   group_by(poll_id) |>
#   group_modify(
#     \(x, group) {
#       current_sum <- sum(x$voteshare, na.rm = TRUE)
#       new_row <- x[1, ] |>
#         mutate(
#           party = 0,
#           voteshare = 1 - current_sum,
#           error_lower = NA,
#           error_upper = NA
#         )

#       bind_rows(x, new_row)
#     }
#   ) |>
#   ungroup() |>
#   arrange(-poll_id)

# Create codes for parties and agencies
df_polls <-
  df_polls |>
  mutate(
    agency = factor(agency),
    agency_id = as.integer(agency),
    party = factor(party),
    party_id = as.integer(party)
  ) |>
  relocate(agency_id, .after = agency) |>
  relocate(party_id, .after = party)

# Write polls
write_parquet(
  x = df_polls,
  file = config::get("polls", config = "silver")
)

# Transform parties
df_parties <-
  read_json(path = config::get("parties", config = "bronze")) |>
  map_df(\(x) {
    # Get primary data
    df <- tibble(
      party = x[["VSTRANA"]],
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

# # Add party for Other and factorize
# df_parties <-
#   bind_rows(
#     tibble(
#       party = 0,
#       party_shortcut = "XXX",
#       party_name = "Other parties",
#       party_color = "#ed08d3ff"
#     ),
#     df_parties
#   ) |>
#   mutate(party = factor(party))

# Add party for Other and factorize
df_parties <-
  df_parties |>
  mutate(party = factor(party))

# Write parties
write_parquet(
  x = df_parties,
  file = config::get("parties", config = "silver")
)
