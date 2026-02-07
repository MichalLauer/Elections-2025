# Libraries
library(nanoparquet)
library(jsonlite)
library(dplyr)
library(tidyr)
library(tibble)

# Read raw data
df_raw <- read_parquet(config::get("data", config = "silver"))
# Recode agencies
df <-
  df_raw |>
  mutate(
    party = as.character(party),
    agency = recode_values(
      agency,
      from = names(mapping$agencies),
      to = unlist(mapping$agencies)
    )
  )

# Create raw calendar
poll_day <- as.Date("2025-10-04")
calendar_raw <-
  tibble(
    date = seq(min(df_raw$date), poll_day, by = "day")
  ) |>
  left_join(y = df, by = join_by(date), relationship = "one-to-many")

# Create raw calendar with missing votes
calendar_raw_wide <-
  calendar_raw |>
  select(date, agency, party, value) |>
  pivot_wider(
    names_from = "party",
    values_from = "value"
  ) |>
  rowwise() |>
  mutate(
    "000" = 1 - sum(c_across(`768`:`1298`), na.rm = TRUE)
  ) |>
  ungroup()

calendar_wide <-
  calendar_raw |>
  select(date, agency, from, to, duration_days, amount, attendance) |>
  distinct() |>
  left_join(
    y = calendar_raw_wide,
    by = join_by(date, agency),
    relationship = "one-to-one"
  )

calendar_long <-
  calendar_wide |>
  pivot_longer(
    cols = `768`:`000`,
    names_to = "party",
    values_to = "voteshare",
  ) |>
  left_join(
    distinct(df, party, name, shortcut, color),
    by = join_by(party),
    relationship = "many-to-one"
  )

# Save calendar
write_parquet(
  x = calendar_wide,
  file = config::get("calendar_wide", config = "gold")
)

write_parquet(
  x = calendar_long,
  file = config::get("calendar_long", config = "gold"),
)
