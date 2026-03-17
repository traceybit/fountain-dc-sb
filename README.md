# Fountain Diet Coke — Santa Barbara

A crowd-sourced interactive map of fountain Diet Coke locations in Santa Barbara, Goleta, and Isla Vista.

**Live site:** [traceymangin.github.io/fountain-dc-sb](https://traceymangin.github.io/fountain-dc-sb/)

## How it works

1. People submit fountain Diet Coke sightings and experiences via a [Google Form](https://docs.google.com/forms/d/e/1FAIpQLSep4UoqOil2V5x9Mxi1cqu_rlowAbNfmzpCryh0ZZQ1L4LlyQ/viewform)
2. Responses land in a Google Sheet
3. A geocoding script (`scripts/geocode.R`) reads the published sheet, converts addresses to coordinates, and saves a clean CSV
4. The Quarto website renders an interactive Leaflet map that reads from that CSV

## Updating the map with new submissions

After new form responses come in, run the geocode script in R:

```r
source("scripts/geocode.R")
```

This fetches the latest form responses, geocodes any new addresses, and writes `data/locations.csv`. Commit and push to trigger a site rebuild.

## Tech stack

- [Quarto](https://quarto.org/) — website framework
- [Leaflet](https://rstudio.github.io/leaflet/) — interactive map (R package)
- [PapaParse](https://www.papaparse.com/) — client-side CSV parsing
- [tidygeocoder](https://jessecambon.github.io/tidygeocoder/) — address geocoding via OpenStreetMap
- GitHub Actions + GitHub Pages — build and hosting

## Project structure

```
├── index.qmd                    # Main page with map
├── about.qmd                    # About page
├── _quarto.yml                  # Quarto site config
├── styles.css                   # Custom styling
├── data/
│   └── locations.csv            # Geocoded locations (generated)
├── scripts/
│   └── geocode.R                # Fetches form data + geocodes
└── .github/workflows/
    └── publish.yml              # GitHub Actions deployment
```

## Local development

Prerequisites: [Quarto CLI](https://quarto.org/docs/get-started/), R with `leaflet`, `readr`, `tidygeocoder`, and `dplyr`.

```bash
quarto preview
```
