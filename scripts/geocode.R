# geocode.R
# Reads form responses from the published Google Sheet CSV (no auth needed),
# geocodes addresses, and saves a clean CSV locally for the website to use.
#
# Geocoding strategy:
#   1. Try the full address as submitted
#   2. If that fails, try "business_name, city, CA" as a fallback
#   3. If both fail, skip the entry (it still runs, just no marker on the map)
#
# Usage: Run this after new form submissions come in.
#   source("scripts/geocode.R")
#
# Requirements:
#   install.packages(c("readr", "tidygeocoder", "dplyr"))

library(readr)
library(tidygeocoder)
library(dplyr)

# ---- CONFIG ----
# Published CSV URL for the "Form Responses 1" tab
csv_url <- "https://docs.google.com/spreadsheets/d/e/2PACX-1vQGxW_wJnCWEgEvsWkMUgy2yfHW3i44X7UaY2pBaWA2aeeoWpxVar1adtZUnYmzO6uBEnhUrEzW_QGX/pub?gid=1264001528&single=true&output=csv"

output_file <- "data/locations.csv"
# ----------------

# Read published CSV (no auth required)
# Force all columns to character to avoid type-guessing issues
dat <- read_csv(csv_url, show_col_types = FALSE, col_types = cols(.default = "c"))

# Find columns by partial match on the form question text
find_col <- function(df, pattern) {
  matched <- grep(pattern, names(df), ignore.case = TRUE, value = TRUE)
  if (length(matched) == 0) return(NA_character_)
  matched[1]
}

name_col     <- find_col(dat, "business name")
city_col     <- find_col(dat, "select the area")
address_col  <- find_col(dat, "address of the business")
review_col   <- find_col(dat, "review of the fountain")
rating_col   <- find_col(dat, "please rate")
consumed_col <- find_col(dat, "did you consume")
submitter_col <- find_col(dat, "please enter your name")

# Check required columns exist
missing <- c()
if (is.na(name_col)) missing <- c(missing, "business name")
if (is.na(city_col)) missing <- c(missing, "city/area")
if (is.na(address_col)) missing <- c(missing, "address")

if (length(missing) > 0) {
  message("Could not find required columns: ", paste(missing, collapse = ", "))
  message("Available columns: ", paste(names(dat), collapse = ", "))
  stop("Missing required columns.")
}

# Safe column accessor — returns NA string if column not found
safe_col <- function(df, col_name) {
  if (is.na(col_name)) return(rep(NA_character_, nrow(df)))
  df[[col_name]]
}

# Build a clean data frame with short column names
clean <- tibble(
  business_name    = dat[[name_col]],
  address          = dat[[address_col]],
  city             = dat[[city_col]],
  consumed         = safe_col(dat, consumed_col),
  rating           = safe_col(dat, rating_col),
  review           = safe_col(dat, review_col),
  submitter        = safe_col(dat, submitter_col),
  full_address     = paste(address, city, "CA", sep = ", "),
  fallback_address = paste(business_name, city, "CA", sep = ", ")
)

# Geocode row by row with fallback logic
message(sprintf("Geocoding %d row(s)...", nrow(clean)))

results <- list()

for (i in seq_len(nrow(clean))) {
  row <- clean[i, ]

  lat <- NA_real_
  lng <- NA_real_

  # Attempt 1: full address
  tryCatch({
    geo <- geocode(
      tibble(addr = row$full_address),
      addr, method = "osm", lat = lat, long = lng, quiet = TRUE
    )
    lat <- geo$lat
    lng <- geo$lng
  }, error = function(e) {
    message(sprintf("  Address geocode error for '%s': %s", row$business_name, e$message))
  })

  # Attempt 2: fallback to business name + city if address failed
  if (is.na(lat) || is.na(lng)) {
    message(sprintf("  Address failed for '%s', trying business name + city...", row$business_name))
    tryCatch({
      geo <- geocode(
        tibble(addr = row$fallback_address),
        addr, method = "osm", lat = lat, long = lng, quiet = TRUE
      )
      lat <- geo$lat
      lng <- geo$lng
    }, error = function(e) {
      message(sprintf("  Fallback geocode error for '%s': %s", row$business_name, e$message))
    })
  }

  if (!is.na(lat) && !is.na(lng)) {
    message(sprintf("  Done: %s -> %.4f, %.4f", row$business_name, lat, lng))
  } else {
    message(sprintf("  Skipping: could not geocode '%s'", row$business_name))
  }

  results[[i]] <- tibble(
    business_name = row$business_name,
    address       = row$address,
    city          = row$city,
    latitude      = lat,
    longitude     = lng,
    consumed      = row$consumed,
    rating        = row$rating,
    review        = row$review,
    submitter     = row$submitter
  )
}

geocoded <- bind_rows(results)

# Report summary
n_success <- sum(!is.na(geocoded$latitude))
n_fail <- sum(is.na(geocoded$latitude))
message(sprintf("Results: %d geocoded, %d skipped", n_success, n_fail))

# Only keep rows with valid coordinates for the output
output <- geocoded |>
  filter(!is.na(latitude), !is.na(longitude))

dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
write_csv(output, output_file)

message(sprintf("Wrote %d rows to %s. Done!", nrow(output), output_file))
