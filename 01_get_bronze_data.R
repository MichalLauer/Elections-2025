# Libraries
library(fs)
library(jsonlite)
library(glue)
library(httr)
library(purrr)


# Prepare data
if (!dir.exists(config::get("path", config = "bronze"))) {
  dir.create(config::get("path", config = "bronze"), recursive = TRUE)
}

if (!dir.exists(config::get("path", config = "silver"))) {
  dir.create(config::get("path", config = "silver"), recursive = TRUE)
}

# Download function
download_by_type <- function(url, .id = NULL, sleep = 5) {
  try_load <- function(url, .type, .id = NULL) {
    url_glued <- glue(url)

    res_raw <- tryCatch(
      GET(url_glued, user_agent("Elections-2025 R script")),
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

  # Try cache
  res <- try_load(url, .type = "cache", .id = .id)
  Sys.sleep(sleep)
  if (isTRUE(res$success) && identical(res$status_code, 200L)) {
    return(res$data)
  }

  message(glue(
    "Cache request failed (status={res$status_code}): {res$error} — trying cache with .json"
  ))

  # Try cache with double .json
  url2 <- paste0(url, ".json")
  res2 <- try_load(url2, .type = "cache", .id = .id)
  Sys.sleep(sleep)
  if (isTRUE(res2$success) && identical(res2$status_code, 200L)) {
    return(res2$data)
  }

  message(glue(
    "Cache with .json request failed (status={res2$status_code}): {res2$error} — trying API"
  ))

  # Try api
  res3 <- try_load(url, .type = "api", .id = .id)
  Sys.sleep(sleep)
  if (isTRUE(res3$success) && identical(res3$status_code, 200L)) {
    return(res3$data)
  }

  message(glue("Api request failed (status={res3$status_code}): {res3$error}."))

  return(NULL)
}

# Download polls
polls <- download_by_type(config::get("polls"))
write_json(
  x = polls$list,
  path = config::get("polls", config = "bronze"),
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)


# Download parties
parties <-
  polls$list$entries |>
  map(\(x) x$party) |>
  unlist() |>
  unique() |>
  sort() |>
  head() |>
  tail(1) |>
  map(\(.id) {
    print(glue("* Downloading {.id}..."))
    x <- download_by_type(config::get("parties"), .id = .id)
    if (is.null(x)) {
      print(glue("! Failed to download {.id}."))
    } else {
      print(glue("= Downloaded {.id}."))
    }

    return(x$cis$strany)
  })
write_json(
  x = parties,
  path = config::get("parties", config = "bronze"),
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)
