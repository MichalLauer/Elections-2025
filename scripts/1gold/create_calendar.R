# Libraries
library(nanoparquet)
library(jsonlite)
library(dplyr)
library(tidyr)
library(tibble)

# Read raw data
polls_raw <- read_parquet(config::get("polls", config = "silver"))
parties_raw <- read_parquet(config::get("parties", config = "silver"))

# Create calendar
start_date <- min(polls_raw$date_published)
end_date <- as.Date("2025-10-04")
calendar_long <-
  tibble(
    date_published = seq(start_date, end_date, by = "day")
  ) |>
  mutate(
    t = row_number()
  ) |>
  left_join(
    y = polls_raw,
    by = join_by(date_published),
    relationship = "one-to-many"
  ) |>
  left_join(
    y = parties_raw,
    by = join_by(party)
  )

write_parquet(
  x = calendar_long,
  file = config::get("calendar_long", config = "gold")
)
