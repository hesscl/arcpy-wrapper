#This script takes the shapefile of new listing coordinates from an online rental listing source and
#uses ESRI Business Analyst address locators to reverse geocode listings to obtain address and placename
#information about the listing.

#dependencies
import os
import csv
import sys
import arcinfo
import arcpy

#allow overwriting previous shapefiles
arcpy.env.overwriteOutput = True

#handle the input arguments
input_filename = sys.argv[1] # we're going to grab the first command line argument, use that as our input file
output_layer = sys.argv[2] #use this to name what the script returns
	
#identify the destination folder relative to script path
script_directory = os.path.dirname(os.path.abspath(__file__))
dest_folder = os.path.join(script_directory, "input", "geo")

#define the filepath for the input CSV that R spit out, along with the GDB for geocoding
input_filename = os.path.join(dest_folder, input_filename)

#assign reverse geocoding geodatabase as var, build output layer path for arcpy
output_gdb = "rev_geocoding.gdb"
output_gdb_filepath = os.path.join(dest_folder, output_gdb)
output_layer = f"{output_gdb_filepath}/{output_layer}"

#if we haven't geocoded here before, make a geodatabase in arcgis
if os.path.exists(output_gdb_filepath) is False:
    arcpy.management.CreateFileGDB(dest_folder, output_gdb)
	
#run the geocoding based on the current best-working setup
arcpy.geocoding.ReverseGeocode(in_features=input_filename, 
                               in_address_locator="R:/Data/GIS/Geocoding/2022 Business Analyst Data/Geocoding Data for ArcGIS Pro/USA", 
                               out_feature_class=output_layer)
