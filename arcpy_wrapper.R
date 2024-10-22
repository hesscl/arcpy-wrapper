#### Wrapper and related elements for geocoding/geoparsing ---------------------
#### natrent @ UW

#functions to handle/support the geocoding process using ArcPy as primary geocoder
#for national rental data scraping with Smartystreets as primary geoparser for ads
#where we need to extract addresses from the listed text

arcpy_geocode <- function(tbl, run_fields = NULL, debug = FALSE){
  
  #save some values for the geocoding script call
  #LISTSRC <- config$SOURCEABB
  #LISTLOC <- config$SCRIPT_ID
  #input_tbl <- paste0(config$PATH, "/data/geo/ESRI/", LISTSRC, "_", LISTLOC, "_to_geocode_", stage, ".csv")
  #output_shp <- paste0(config$PATH, "/data/geo/ESRI/", LISTSRC, "_", LISTLOC, "_geocoded_", stage, ".shp")
  
  #path to python
  PYPATH <- '"C:/Program Files/ArcGIS/Pro/bin/Python/Scripts/propy.bat"'

  #geocode script locs
  geocode_script <- "./arcpy_geocode.py"
  
  #grab the object name of what was passed as tbl
  tbl_name <- deparse(substitute(tbl))
  
  #prep run date string
  run_date <- str_replace_all(Sys.time(), "-|\\s|\\:|\\.", "_")
  
  #filenames for run
  input_tbl <- paste0(tbl_name, "_", run_date, ".csv")
  output_layer <- paste0(tbl_name, "_", run_date)

  #make sure we have the right arguments to proceed
  if(is.null(run_fields)){
    stop("Need to specify the address, city and state fields as ordered character vector.")
  }
  
  #make sure the run_field columns are character to avoid join errors
  tbl[unique(run_fields)] <- lapply(tbl[unique(run_fields)], as.character)

  #reduce the table to unique combinations to be geocoded
  geocode_tbl <- tbl %>%
    select(all_of(run_fields)) %>%
    distinct()
  
  #write the geocode table to storage with the corresponding name
  write_csv(geocode_tbl, paste0("./input/geo/", input_tbl), na = " ")
  
  run_fields_input <- paste(run_fields, collapse = " ")
  
  #give us three tries to get past ArcGIS gremlines
  gc_tries <- 1
  gc_result <- NULL
  sleep_time <- 20
  
  #Python2.7 script to use ArcPy.GeocodeAddresses_geocoding
  #cat(paste("Command:", PYPATH, geocode_script, input_tbl, output_shp, run_fields_input))
  arguments <- paste(geocode_script, input_tbl, output_layer, run_fields_input)
  command <- paste(PYPATH, arguments)
  print(command)
  
  while(gc_tries <= 3 && is.null(gc_result)){
    gc_result <- try(system(command))
    
    if(inherits(gc_result, "try-error")){
      
      #a lot of observed bugs result from what looks like licensing issues
      #i.e. ArcGIS thinks we are using more licenses than we are allowed
      Sys.sleep(sleep_time)
      
      #reset the gc_result object for another run, mark that we used an attempt
      gc_result <- NULL
      gc_tries <- gc_tries + 1
    }
  }
  
  #read in the point data shapefile that was produced
  result <- try(read_sf("./input/geo/geocoding.gdb", layer = output_layer,
                         stringsAsFactors = FALSE),
                 silent = !debug)
  
  #clean up the CSV we passed to ArcGIS
  file.remove(paste0("./input/geo/", input_tbl))
  
  #end function call based on whether result exists / was unsuccessful
  if(!inherits(result, "try-error")){

    #if it does exist, we only need the tabular data
    result$Shape <- NULL

    #rename input fields
    result <- result %>%
      rename_at(vars(starts_with("USER_")), ~ str_remove_all(., "USER_"))

    #silently join this back to the geocoding table that was input
    geocode_tbl <- suppressWarnings(suppressMessages(left_join(geocode_tbl, result)))

    #now join this back to the original, undeduplicated table
    tbl <- suppressWarnings(suppressMessages(left_join(tbl, geocode_tbl, by = run_fields)))

    #return the tbl that now has geocode fields
    tbl

    #if we had three unsuccessful runs and/or couldn't read in the shp we expected
  } else{

    #stop and print the last observed error
    stop(paste("ArcGIS geocoding was stopped after 3 unsuccessful attempts.\n\nLast Error:\n",
               as.character(result)))
  }
}

arcpy_rev_geocode <- function(sf, debug = FALSE){
  
  #save some values for the geocoding script call
  # LISTSRC <- config$SOURCEABB
  # LISTLOC <- config$SCRIPT_ID
  # PYPATH <- config$PYPATH
  # rev_geocode_script <- paste0(config$PATH, "/scripts/arcpyRevGeocode.py")
  # input_shp <- paste0(config$PATH, "/data/geo/ESRI/", LISTSRC, "_", LISTLOC, "_rev_geocode_arcpy.shp")
  # output_shp <- paste0(config$PATH, "/data/geo/ESRI/", LISTSRC, "_", LISTLOC, "_rev_geocoded")
  
  #path to python
  PYPATH <- '"C:/Program Files/ArcGIS/Pro/bin/Python/Scripts/propy.bat"'
  
  #geocode script locs
  geocode_script <- "./arcpy_rev_geocode.py"
  
  #grab the object name of what was passed as tbl
  sf_name <- deparse(substitute(sf))
  
  #prep run date string
  run_date <- str_replace_all(Sys.time(), "-|\\s|\\:|\\.", "_")
  
  #filenames for run
  input_shp <- paste0(sf_name, "_", run_date, ".shp")
  output_layer <- paste0(sf_name, "_", run_date)
  
  #reduce the table to unique lat/long combinations to be geocoded
  rev_geocode_coords <- sf %>%
    select(gmaps_lat, gmaps_lng, geometry) %>%
    distinct(gmaps_lat, gmaps_lng, geometry)
  
  #write the geocode table to storage with the corresponding name
  st_write(rev_geocode_coords, dsn = paste0("./input/geo/", input_shp), 
           driver = "ESRI Shapefile", quiet = !debug)
  
  #give us three tries to get past ArcGIS gremlines
  gc_tries <- 1
  gc_result <- NULL
  sleep_time <- 20
  
  arguments <- paste(geocode_script, input_shp, output_layer)
  command <- paste(PYPATH, arguments)
  
  while(gc_tries <= 3 && is.null(gc_result)){
    gc_result <- try(system(command))
    
    if(inherits(gc_result, "try-error")){
      
      #a lot of observed bugs result from what looks like licensing issues
      #i.e. ArcGIS thinks we are using more licenses than we are allowed
      Sys.sleep(sleep_time)
      
      #reset the gc_result object for another run, mark that we used an attempt
      gc_result <- NULL
      gc_tries <- gc_tries + 1
    }
  }
  
  #read in the point data shapefile that was produced
  result <- try(read_sf("./input/geo/rev_geocoding.gdb", layer = output_layer,
                        stringsAsFactors = FALSE),
                silent = !debug)
  
  #remove the input shapefile NB: using output layer str to wildcard the input since
  #shapefiles have multiple component files
  file.remove(paste0(output_layer, ".*"))
  
  #end function call based on whether result exists / was unsuccessful
  if(!inherits(result, "try-error")){

    #turn result object into data.frames
    result <- st_drop_geometry(result)

    #clean up the resulting result df a bit
    result <- result %>%
      rename_at(vars(starts_with("REV_")), tolower) %>%
      rename(rev_zip = rev_postal, rev_zip_ext = rev_postalext) %>%
      mutate_at(c("rev_address", "rev_city", "rev_region"), toupper)

    #now join this back to the original, undeduplicated table
    sf <- suppressWarnings(suppressMessages(left_join(sf, result)))

    #return the tbl that now has geocode fields
    sf

    #if we had three unsuccessful runs and/or couldn't read in the shp we expected
  } else{

    #stop and print the last observed error
    stop(paste("ArcGIS reverse geocoding was stopped after 3 unsuccessful attempts.\n\nLast Error:\n",
               as.character(result)))
  }
}
