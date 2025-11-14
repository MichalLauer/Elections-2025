# Libraries
library(fs)
library(jsonlite)
library(glue)
library(stringr)
library(tibble)
library(purrr)
library(dplyr)
library(tidyr)
library(nanoparquet)

# Prepare data
if (!dir.exists(config::get("path", config = "bronze"))) {
  dir.create(config::get("path", config = "bronze"), recursive = TRUE)
}

if (!dir.exists(config::get("path", config = "silver"))) {
  dir.create(config::get("path", config = "silver"), recursive = TRUE)
}

# Download raw data

## Download polls
config::get("polls") |>
  read_json() |>
  _$list |>
  write_json(
    path = path(config::get("path", config="bronze"), config::get("polls", config="bronze")),
    simplifyVector = TRUE,
    auto_unbox = TRUE,
    pretty = TRUE
  )

## Download parties
parties <- list()
polls <- read_json(path(config::get("path", config="bronze"), config::get("polls", config="bronze")))

for (poll in polls) {
  # Only latest elections
  if (!isTRUE(poll$volby == 166)) next

  for (entry in poll$entries) {
    .party_id <- as.character(entry$party)

    if (is.null(parties[[.party_id]])) {
      print(glue("> Downloading party: {.party_id}"))
      party <- read_json(glue(config::get("party", config = "path")))
      Sys.sleep(1)

      parties[[.party_id]] <- list(
        name = party$list[[1]]$NAZEV,
        shortname = party$list[[1]]$ZKRATKA
      )
    }
  }
}

write_json(
  x = parties,
  path = path(config::get("path", config="bronze"), config::get("parties", config="bronze")),
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)

## Merge and save
df <-
  map(polls, function(poll) {
    # Only latest elections
    if (!isTRUE(poll$volby == 166)) return(NULL)

    if (length(poll$attendance) == 0) {
      poll$attendance <- NA
    }

    map(poll$entries, function(e) tibble(party = as.integer(e$party), p = e$value/100)) |>
      bind_rows() |>
      mutate(
        date = as.Date(poll$datum),
        agency = poll$agency,
        attendance = poll$attendance
      )
  }) |>
    bind_rows()

df_party <-
  parties |>
  enframe(name = "party") |>
  unnest_wider(col = "value") |>
  mutate(party = as.integer(party))

df <- left_join(
  x = df,
  y = df_party,
  by = "party",
  relationship = "many-to-one"
)

write_parquet(
  x = df,
  file = path(
    config::get("path", config="silver"), config::get("polls", config="silver")
  )
)


