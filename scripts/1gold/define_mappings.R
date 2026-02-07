library(jsonlite)

mapping <- list(
  agencies = list(
    "Kantar" = 1,
    "STEM" = 2,
    "NMS Market Research" = 3,
    "Ipsos" = 4,
    "Median" = 5
  ),
  parties = list(
    "768" = "ANO 2011",
    "1327" = "Koalice KDU-ČSL, ODS a TOP 09",
    "166" = "STAROSTOVÉ A NEZÁVISLÍ",
    "1114" = "Svoboda a přímá demokracie (SPD)",
    "720" = "Česká pirátská strana",
    "47" = "Komunistická strana Čech a Moravy",
    "1245" = "PŘÍSAHA občanské hnutí",
    "1178" = "Motoristé sobě",
    "7" = "Sociální demokracie",
    "714" = "Svobodní",
    "5" = "Strana zelených",
    "1265" = "PRO Právo Respekt Odbornost",
    "1227" = "Trikolora",
    "1298" = "Stačilo!",
    "000" = "Ostatní"
  )
)

write_json(
  x = mapping,
  path = config::get("mapping", config = "gold"),
  auto_unbox = TRUE,
  pretty = TRUE
)
