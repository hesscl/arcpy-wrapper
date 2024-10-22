#This script takes the CSV of new listings from an online rental listing source and
#uses ESRI Business Analyst address locators to geocode listings to a point, interpolated
#street segment or approximate area. 

#dependencies
import os
import csv
import sys
import arcinfo
import arcpy

#allow overwriting previous shapefiles
arcpy.env.overwriteOutput = True

#handle the mandatory input arguments
input_filepath = sys.argv[1] # we're going to grab the first command line argument, use that as our input file
output_layer = sys.argv[2] #use this to name what the script returns
add_field = sys.argv[3] #use these to specify what columns of input data table are used within GeocodeAddresses

#handle the components if provided
if len(sys.argv) > 4:
	city_field = sys.argv[4]
	state_field = sys.argv[5]
else:
	city_field = None
	state_field = None

#identify the destination folder relative to script path
script_directory = os.path.dirname(os.path.abspath(__file__))
dest_folder = os.path.join(script_directory, "input", "geo")

#define the filepath for the input CSV that R spit out, along with the GDB for geocoding
input_filepath = os.path.join(dest_folder, input_filepath)

#assign geocoding geodatabase as var, build output layer path for arcpy
output_gdb = "geocoding.gdb"
output_gdb_filepath = os.path.join(dest_folder, output_gdb)
output_layer = f"{output_gdb_filepath}/{output_layer}"

#if we haven't geocoded here before, make a geodatabase in arcgis
if os.path.exists(output_gdb_filepath) is False:
    arcpy.management.CreateFileGDB(dest_folder, output_gdb)

#for runs where we want to use a single field
if (city_field is None and state_field is None):
	in_add_string = "'Single Line Input' " + add_field + " VISIBLE NONE"
	
#for normal runs
else:
	in_add_string = "'Address or Place' " + add_field + " VISIBLE NONE;Address2 <None> VISIBLE NONE;Address3 <None> VISIBLE NONE;Neighborhood <None> VISIBLE NONE;City " + city_field + " VISIBLE NONE;County <None> VISIBLE NONE;State " + state_field + " VISIBLE NONE;ZIP <None> VISIBLE NONE;ZIP4 <None> VISIBLE NONE;Country <None> VISIBLE NONE"

#print the string we are going to pass to arcpy to control the geocoding
print(in_add_string)

#run the geocoding based on the current best-working setup
arcpy.geocoding.GeocodeAddresses(in_table=input_filepath, 
                                 address_locator="R:/Data/GIS/Geocoding/2022 Business Analyst Data/Geocoding Data for ArcGIS Pro/USA", 
								                 in_address_fields=in_add_string, 
								                 out_feature_class=output_layer, 
								                 out_relationship_type="STATIC",
								                 country="USA", 
								                 location_type="ROUTING_LOCATION")
