# MuncOnBassoon
FIJI Macro for counting Munc spots on Bassoon blobs.

## Usage

![Interface](doc/Munc_on_Bassoon_Interface.JPG)

## Note on data

This script will process any image found in the specified input folder.

## Note on results

For each input file  this script produces three output files, which will be written to the specified output folder. For example, the results for an image named `image.tif` will be found in:

1. `image.tif.bassoon.csv` contains comma delimitted values for `Basson_id`, `Basson_area`, `Marker_mean`, `Munc_count` and `Munc_density`.
2. `image.tif.munc.csv` contains comma delimitted values for `Munc_id`, `Munc_area`, `Munc_mean`, and `Bassoon_id`.
3. `image.tif.segmented.tif` contains all segmented munc spots, all segmented bassoon blobs as well as the original marker channel.


## Note on test data
* The `example_data.tif` STORM image in the data folder is a copy of figure panel 5B from the following publication. It has been made available via CC BY 3.0. Please note that this is not a labelling by Munc and Bassoon.
```
Andreska, T., Aufmkolk, S., Sauer, M., & Blum, R. (2014). High abundance of BDNF within glutamatergic presynapses of cultured hippocampal neurons. Frontiers in cellular neuroscience, 8, 107.
```
* The `fake_data_3channel.tif` added a third channel containing the signal from an additional synapse marker with low resolution as typical for standard epifluorescence microscopy. This 3 channel image is only for testing purposes.   
