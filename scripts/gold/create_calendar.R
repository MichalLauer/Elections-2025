# Libraries
library(nanoparquet)
library(jsonlite)
library(dplyr)
library(tidyr)
library(tibble)

# Read raw data
df_raw <-
  read_parquet(here::here("data", "silver", "data.parquet")) |>
  filter(!is.na(amount))

# Read mapping
mapping <- read_json(here::here("data", "gold", "mapping.json"))

# Compute the leftover voting preferences
df <-
  df_raw |>
  select(date, agency, amount, party, value) |>
  pivot_wider(
    id_cols = c(date, agency, amount),
    names_from = "party",
    values_from = "value"
  ) |>
  rowwise() |>
  mutate(
    "000" = 1 - sum(c_across(`768`:`1298`), na.rm = TRUE)
  ) |>
  ungroup()


# # Remove parties with any NA column and move the preference to "Other"
# na_parties <-
#   df |>
#   select(where(\(x) sum(is.na(x)) > 0)) |>
#   colnames()

# df <-
#   df |>
#   rowwise() |>
#   mutate(
#     "000" = sum(c_across(all_of(c(na_parties, "000"))), na.rm = TRUE)
#   ) |>
#   ungroup() |>
#   select(-all_of(na_parties), -agency)

# Remap agencies
df <-
  df |>
  mutate(
    agency = unlist(mapping$agencies[agency])
  )

# Create calendar of full voting range
calendar_raw <-
  tibble(
    date = seq(min(df$date), max(df$date), by = "day")
  ) |>
  mutate(
    t = row_number()
  ) |>
  cross_join(
    y = tibble(agency = seq_along(mapping$agencies))
  )

# Join data to date - agency polls
calendar <-
  calendar_raw |>
  left_join(df, by = join_by(date, agency), relationship = "one-to-one")

# Save calendar
write_parquet(
  x = calendar,
  file = here::here("data", "gold", "calendar.parquet")
)
