
#dependencies
library(tidyverse)
library(sf)

#load the wrapper script
source("arcpy_wrapper.R")


#### Build the file structure --------------------------------------------------

#make an input/geo file structure to give us a place to store files
if(!dir.exists("./input/geo")){
  dir.create("./input/geo", recursive = T)
}

#if we don't have a set of dummy data to work with, get some
if(!file.exists("./input/raw.csv")){
  
  #R will timeout the download by default, override the default timelimit
  options(timeout = 1e9)
  
  #download 72 hours of data to give us a working dataset to use for the MRE
  download.file("http://helena-backend.us-west-2.elasticbeanstalk.com/datasets/10038/72",
                destfile = "./input/raw.csv")
  
}
  
#load the data
raw <- read_csv("./input/raw.csv", col_names = NA)

#assign col names
colnames(raw) <- c("title", "rent", "size_stats", "neigh", "address1", "address2",
                   "gmaps_url", "beds_bath", "sqft", "avail", "hu_char", "text", "post_id",
                   "posted_date", "updated_date", "container", "url", "program_iter")

#inspect
glimpse(raw)


#### Test one-line geocoding ---------------------------------------------------

#address1 should be able to run by itself
one_line <- raw %>%
  select(address1)

#use wrapper function
one_line_result <- arcpy_geocode(one_line, run_fields = "address1")

#inspect result
glimpse(one_line_result)


#### Test reverse geocoding using the gmaps lat/lng ----------------------------

#prep a sf obj that is based on the google maps url coordinates
gmap_coord <- raw %>%
  mutate(gmaps_coord = str_remove_all(gmaps_url, "https://www.google.com/maps/search/")) %>%
  separate(gmaps_coord, into = c("gmaps_lat", "gmaps_lng"), sep = "\\,") %>%
  mutate_at(vars(gmaps_lng, gmaps_lat), parse_number) %>%
  filter(!is.na(gmaps_lng), !is.na(gmaps_lat)) %>%
  st_as_sf(coords = c("gmaps_lng", "gmaps_lat"), remove = FALSE) %>%
  st_set_crs("epsg:4326")

#use wrapper function
gmap_coord_result <- arcpy_rev_geocode(gmap_coord)

#inspect result
glimpse(gmap_coord_result)


#### Test multi field geocoding ------------------------------------------------

#address1 should be able to run by itself
multi_field <- gmap_coord_result %>%
  select(address2, city = rev_city, state = rev_regionabbr) %>%
  st_drop_geometry()

#use wrapper function
multi_field_result <- arcpy_geocode(multi_field, run_fields = c("address2", "city", "state"))

#inspect result
glimpse(multi_field_result)





