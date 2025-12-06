# Libraries
library(jsonlite)
library(dplyr)
library(tidyr)
library(purrr)
library(nanoparquet)

# Transform polls
df_polls <-
  read_json(path = config::get("polls", config = "bronze")) |>
  bind_rows() |>
  filter(volby == 166) |>
  select(date = datum, agency, amount, from, to, attendance, entries) |>
  unnest_wider(col = entries) |>
  select(-c(id, poll, mandates)) |>
  mutate(
    across(.cols = c(date, from, to), .fns = as.Date),
    across(.cols = c(attendance, value), .fns = \(x) x / 100),
    duration_days = as.integer(to - from + 1),
    agency = factor(agency),
  ) |>
  arrange(date, agency)
write_parquet(
  x = df_polls,
  file = config::get("polls", config = "silver")
)

# Transform parties
df_parties <-
  read_json(path = config::get("parties", config = "bronze")) |>
  map(pluck, 1) |>
  map(function(x) {
    x |>
      list_modify(`$coalition` = zap()) |>
      modify_at("SLOZENI", as.character)
  }) |>
  bind_rows() |>
  unnest_wider(col = `$data`, names_sep = "_") |>
  unnest_wider(col = `$data_1`, names_sep = "_") |>
  filter(`$data_1_type` == "color") |>
  select(
    id = VSTRANA,
    name = NAZEV,
    shortcut = ZKRATKA,
    color = `$data_1_value`
  ) |>
  mutate(
    name = factor(name),
    shortcut = factor(shortcut)
  )
write_parquet(
  x = df_parties,
  file = config::get("parties", config = "silver")
)

# Merge
df_all <-
  df_polls |>
  left_join(
    y = df_parties,
    by = join_by(party == id),
    relationship = "many-to-one"
  )
write_parquet(
  x = df_all,
  file = config::get("data", config = "silver")
)
