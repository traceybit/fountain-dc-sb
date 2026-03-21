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
dat <- read_csv(csv_url, show_col_types = FALSE)

# Find columns by partial match on the form question text
find_col <- function(df, pattern) {
  matched <- grep(pattern, names(df), ignore.case = TRUE, value = TRUE)
  if (length(matched) == 0) stop(paste("Could not find column matching:", pattern))
  matched[1]
}

name_col     <- find_col(dat, "business name")
city_col     <- find_col(dat, "select the area")
address_col  <- find_col(dat, "address of the business")
review_col   <- find_col(dat, "review of the fountain")
rating_col   <- find_col(dat, "please rate")
consumed_col <- find_col(dat, "did you consume")
submitter_col <- find_col(dat, "please enter your name")

# Build a clean data frame with short column names
clean <- dat |>
  transmute(
    business_name = .data[[name_col]],
    address       = .data[[address_col]],
    city          = .data[[city_col]],
    consumed      = .data[[consumed_col]],
    rating        = .data[[rating_col]],
    review        = .data[[review_col]],
    submitter     = .data[[submitter_col]],
    full_address  = paste(address, city, "CA", sep = ", "),
    fallback_address = paste(business_name, city, "CA", sep = ", ")
  )

# Geocode row by row with fallback logic
message(sprintf("Geocoding %d row(s)...", nrow(clean)))

results <- list()

for (i in seq_len(nrow(clean))) {
  row <- clean[i, ]

  # Attempt 1: full address
  geo <- tryCatch(
    row |> geocode(full_address, method = "osm", lat = latitude, long = longitude, quiet = TRUE),
    error = function(e) row |> mutate(latitude = NA_real_, longitude = NA_real_)
  )

  # Attempt 2: fallback to business name + city if address failed
  if (is.na(geo$latitude) || is.na(geo$longitude)) {
    message(sprintf("  Address failed for '%s', trying business name + city...", row$business_name))
    geo <- tryCatch(
      row |> geocode(fallback_address, method = "osm", lat = latitude, long = longitude, quiet = TRUE),
      error = function(e) row |> mutate(latitude = NA_real_, longitude = NA_real_)
    )
  }

  if (!is.na(geo$latitude) && !is.na(geo$longitude)) {
    message(sprintf("  Done: %s -> %.4f, %.4f", row$business_name, geo$latitude, geo$longitude))
  } else {
    message(sprintf("  Skipping: could not geocode '%s'", row$business_name))
  }

  results[[i]] <- geo
}

geocoded <- bind_rows(results)

# Report summary
n_success <- sum(!is.na(geocoded$latitude))
n_fail <- sum(is.na(geocoded$latitude))
message(sprintf("Results: %d geocoded, %d skipped", n_success, n_fail))

# Only keep rows with valid coordinates for the output
output <- geocoded |>
  filter(!is.na(latitude), !is.na(longitude)) |>
  select(business_name, address, city, latitude, longitude,
         consumed, rating, review, submitter)

dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
write_csv(output, output_file)

message(sprintf("Wrote %d rows to %s. Done!", nrow(output), output_file))
