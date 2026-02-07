# Libraries
library(jsonlite)
library(glue)
library(httr)
library(purrr)
library(tibble)

# Prepare data
if (!dir.exists(config::get("path", config = "bronze"))) {
  dir.create(config::get("path", config = "bronze"), recursive = TRUE)
}

# Download function
download_by_type <- function(url, .id = NULL, sleep = 5, .type = NULL) {
  try_load <- function(url, .type, .id = NULL) {
    url_glued <- glue(url)
    cat(glue("URL: {url_glued}"))

    # Make sure the program does not crash on fail
    res_raw <- tryCatch(
      GET(url_glued, user_agent("Mozilla/5.0"), config(http_version = 2)),
      error = function(e) e
    )

    if (inherits(res_raw, "error")) {
      return(list(
        success = FALSE,
        status_code = NA_integer_,
        error = conditionMessage(res_raw)
      ))
    }

    status <- status_code(res_raw)
    body_text <- tryCatch(
      content(res_raw, "text", encoding = "UTF-8"),
      error = function(e) NA_character_
    )

    if (status != 200) {
      return(list(success = FALSE, status_code = status, error = body_text))
    }

    parsed <- fromJSON(body_text)
    list(success = TRUE, status_code = 200L, data = parsed)
  }

  # First always try API to get the latest data
  if (is.null(.type) || isTRUE(.type == "api")) {
    res <- try_load(url, .type = "api", .id = .id)
    Sys.sleep(sleep)
    if (isTRUE(res$success) && identical(res$status_code, 200L)) {
      return(res$data)
    }

    message(glue(
      " - Api request failed (status={res$status_code}): {res$error}."
    ))
  }

  # Otherwise, fall back to cache
  if (is.null(.type) || isTRUE(.type == "cache")) {
    url <- paste0(url, ".json")
    res <- try_load(url, .type = "cache", .id = .id)

    Sys.sleep(sleep)
    if (isTRUE(res$success) && identical(res$status_code, 200L)) {
      return(res$data)
    }

    message(glue(
      " - Cache request failed (status={res$status_code}): {res$error}"
    ))

    url <- paste0(url, ".json")
    res <- try_load(url, .type = "cache", .id = .id)
    Sys.sleep(sleep)
    if (isTRUE(res$success) && identical(res$status_code, 200L)) {
      return(res$data)
    }

    message(glue(
      " - Cache with .json request failed (status={res$status_code}): {res$error}"
    ))
  }

  return(NULL)
}

# Download polls from API to always get the latest data
polls <- download_by_type(
  "https://{.type}.programydovoleb.cz/polls/all",
  .type = "api"
)

# Save polls
write_json(
  x = polls$list,
  path = config::get("polls", config = "bronze"),
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)

# Get all party codes
parties_codes <-
  polls$list$entries |>
  map(\(x) x$party) |>
  unlist() |>
  unique() |>
  sort()

# Download parties
parties <-
  map(parties_codes, \(.id) {
    print(glue("* Downloading {.id}..."))
    x <- download_by_type(config::get("parties"), .id = .id, sleep = 10)
    if (is.null(x)) {
      print(glue(" ! Failed to download {.id}."))
    } else {
      print(glue(" = Downloaded {.id}."))
    }

    return(x)
  }) |>
  setNames()

# Get full party data
parties_all <-
  parties |>
  map("list") |>
  setNames(parties_codes)

# Save full party data
write_json(
  x = parties_all,
  path = config::get("parties_all", config = "bronze"),
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)

# Create party df
parties_df <- map_df(parties_all, \(x) {
  # Get primary data
  df <- tibble(
    party_id = x[["VSTRANA"]],
    party_shortcut = x[["ZKRATKA"]],
    party_name = x[["NAZEV"]]
  )

  # Add colors, if available
  color <- x$`$data`$color[[1]]
  if (length(color) > 0) {
    df$party_color <- color[1, "value"]
  }

  df
})

# Write parties df
write_json(
  x = parties_df,
  path = config::get("parties", config = "bronze"),
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)

# Create licenses
license <-
  map(parties, "licence") |>
  setNames(parties_codes) |>
  append(list(polls = polls$licence), after = 0)

# Write license
write_json(
  x = license,
  path = config::get("license", config = "bronze"),
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)
