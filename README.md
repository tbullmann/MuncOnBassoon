# MuncOnBassoon
FIJI Macro for counting Munc spots on Bassoon blobs.

|example data|segmentation result|
|--------------------------------|-----------------------------------|
|![example data](doc/input.jpg) | ![example result](doc/output.jpg) |

## Usage

![Interface](doc/Munc_on_Bassoon_Interface.JPG)

## Note on data

This script will process any image found in the specified input folder.

## Note on results

For each input file  this script produces three output files, which will be written to the specified output folder. For example, the results for an image named `example_data.tif` will be found in:

1. `example_data.tif.bassoon.csv` contains comma delimitted values for `Basson_id`, `Basson_area`, `Marker_overlap`, `Munc_count` and `Munc_density`. The `Bassoon_id=0` referes to the background.

| Bassoon_id | Bassoon_area | Marker_overlap | Munc_count | Munc_density |
|------------|--------------|----------------|------------|--------------|
| 0          | 65304        | 0              | 41         | 6.278E-4     |
| 1          | 216          | 0              | 1          | 0.005        |
| 2          | 79           | 0              | 0          | 0.000        |
| 3          | 561          | 1              | 5          | 0.009        |
| 4          | 888          | 1              | 6          | 0.007        |
| ..         | ..           | ..             | ..         | ..           |
| 14         | 88           | 0              | 0          | 0.000        |


2. `example_data.tif.munc.csv` contains comma delimitted values for `Munc_id`, `Munc_area`, `Munc_mean`, and `Bassoon_id`.

| Munc_id | Munc_area | Munc_mean | Bassoon_id |
|---------|-----------|-----------|------------|
| 1       | 13        | 77.385    | 0          |
| 2       | 24        | 97.917    | 0          |
| 3       | 10        | 83.000    | 0          |
| 4       | 5         | 84.400    | 0          |
| 5       | 5         | 83.600    | 0          |
| ..      | ..        | ..        | ..         |
| 71      | 24        | 95.000    | 0          |


3. `example_data.tif.segmented.png` contains all segmented Munc spots, Bassoon blobs and segmented pre-synapses based on the marker channel.

4. `example_data.tif.compare.png` shows the input image side by side with the segmented images.

4. `example_data.tif.parameters.yaml` contains all parameters used for the segmentation of the image which were provided by the user dialog. Note, that it contains the used `threshold` values as well as the method used for `thresholding` (`Auto` or `Fixed`).

```yaml
channels:
   red: Munc
   green: Bassoon
   blue: Marker
Munc:
   threshold: 34
   thresholding: Auto
   min_diameter: 2
   max_diameter: 6
   inside_choice: half inside
Bassoon:
   threshold: 35
   thresholding: Auto
   min_diameter: 10
   max_diameter: 25
   dilations: 1
Marker:
   threshold: 10
   thresholding: Auto
   min_diameter: 50
   max_diameter: 150
   min_overlap: 1
```


After all images are processed, another file is created: `used_thresholds.csv` contains comma delimitted values for `used_filenames`, `used_threshold_Munc`, `used_threshold_Bassoon` and `used_threshold_Marker`.

| input_filename   | used_threshold_Munc | used_threshold_Bassoon | used_threshold_Marker |
|------------------|---------------------|------------------------|-----------------------|
| test_example.tif | 34                  | 35                     | 10                    |



## Note on test data
* The `example_data.tif` STORM image in the `doc` folder is a copy of figure panel 5B from the following publication. It has been made available via CC BY 3.0. Please note that this is not a labelling by Munc and Bassoon.
```
Andreska, T., Aufmkolk, S., Sauer, M., & Blum, R. (2014). High abundance of BDNF within glutamatergic presynapses of cultured hippocampal neurons. Frontiers in cellular neuroscience, 8, 107.
```
* The `test_example.tif` swapped the red and and the blue channel. Also added was third, blue channel containing the signal from an additional synapse marker with low resolution as typical for standard epifluorescence microscopy. This image is only for testing purposes.   
