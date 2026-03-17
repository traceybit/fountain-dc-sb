# geocode.R
# Reads form responses from the published Google Sheet CSV (no auth needed),
# geocodes addresses, and saves a clean CSV locally for the website to use.
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
    full_address  = paste(address, city, "CA", sep = ", ")
  )

# Geocode all addresses
message(sprintf("Geocoding %d row(s)...", nrow(clean)))

geocoded <- clean |>
  geocode(full_address, method = "osm", lat = latitude, long = longitude)

# Report results
n_success <- sum(!is.na(geocoded$latitude))
n_fail <- sum(is.na(geocoded$latitude))
message(sprintf("  Geocoded: %d, Failed: %d", n_success, n_fail))

if (n_fail > 0) {
  failed <- geocoded |> filter(is.na(latitude))
  message("  Could not geocode:")
  for (i in seq_len(nrow(failed))) {
    message(sprintf("    - %s (%s)", failed$business_name[i], failed$full_address[i]))
  }
}

# Save clean output locally
output <- geocoded |>
  select(business_name, address, city, latitude, longitude,
         consumed, rating, review, submitter)

dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
write_csv(output, output_file)

message(sprintf("Wrote %d rows to %s. Done!", nrow(output), output_file))
