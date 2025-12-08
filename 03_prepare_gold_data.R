if (!dir.exists(config::get("path", config = "gold"))) {
  dir.create(config::get("path", config = "gold"), recursive = TRUE)
}
