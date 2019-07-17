// Dialog
#@ File(label="Select a input directory", style='directory') indir
#@ File(label="Select a output directory", style='directory') outdir
#@ String(label="Red channel", choices={"Bassoon", "Munc", "Marker"}, value="Basson", style="listBox") RedChoice
#@ String(label="Green channel", choices={"Bassoon", "Munc", "Marker"}, value="Munc", style="listBox") GreenChoice
#@ String(label="Blue channel", choices={"Bassoon", "Munc", "Marker"}, value="Marker", style="listBox") BlueChoice
#@ String(label="Basson threshold", value="Auto") minBassoon 
#@ Integer(label="Minimum area of Bassoon blobs (pixels)", value=30) min_bassoon_area
#@ Integer(label="Dilate area of Bassoon blobs (times)", value=1) dilate_basson_blob
#@ String(label="Munc threshold", value="Auto") minMunc 
#@ Integer(label="Average diameter of Munc spots (pixel)", value=2) spot_size
#@ String(label="Munc spot in Basson blob when", choices={"one pixel inside", "half inside", "completely inside"}, value="half inside", style="listBox") InsideChoice

// Parameters 
min_spot_area = spot_size*spot_size*3.1415/4
spot_background_size = spot_size*2

// How to get the Basson blob id from the Count Mask 
if (InsideChoice=="one pixel inside") {Measure="min";}
if (InsideChoice=="half inside") {Measure="modal";}
if (InsideChoice=="completely inside") {Measure="min";}

function segment(inFile, outFile){
	// Open and rename for processing
	open(inFile);
	rename("input");
	
	// TODO: Instead of the following reset of the scale to 1/pixel 
	// adjust the parameters measured in pixel according to the scale in the tiff
	run("Set Scale...", "known=1 unit=pixel"); 
	
	// Split colors and rename each channel according to Dialog for processing
	run("Split Channels");
	selectWindow("input (red)");
	rename(RedChoice);
	selectWindow("input (green)");
	rename(GreenChoice);
	selectWindow("input (blue)");
	rename(BlueChoice);
	
	// Analyse Basoon blobs
	selectWindow("Bassoon");
	run("Gaussian Blur...", "sigma=spot_size");
	if (minBassoon=="Auto"){setAutoThreshold("Default dark no-reset");} else {setThreshold(parseInt(minBassoon), 255);}
	setOption("BlackBackground", true);
	run("Convert to Mask");
	for (i=0; i<dilate_basson_blob; i++) {run("Dilate");}
	run("Set Measurements...", "area mean redirect=Marker decimal=3");
	// exclude (blobs at the image border), clear (measuremnts), include (holes in the blobs)
	run("Analyze Particles...", "size=spot_background_area-Infinity show=[Count Masks] exclude clear include");
	saveAs("Results", outFile+".bassoon.csv");

	// Analyse Munc spots
	selectWindow("Munc");
	run("Gaussian Blur...", "sigma=spot_size");
	run("Subtract Background...", "rolling=spot_background_size");
	if (minMunc=="Auto"){setAutoThreshold("Default dark no-reset");} else {setThreshold(parseInt(minMunc), 255);}
	run("Convert to Mask");
	run("Set Measurements...", "area " + Measure + " redirect=[Count Masks of Bassoon] decimal=3");
	run("Analyze Particles...", "size=min_spot_area-Infinity show=[Bare Outlines] exclude clear include");
	saveAs("Results", outFile + ".raw.munc.csv");
	// New result table with Area and Basson blob id (from the Measure)
	nR = nResults;
	label = newArray(nR);
	area = newArray(nR);
	blob_id = newArray(nR);
	for (i=0; i<nR;i++) {
		area[i] = getResult("Area", i);
		if (InsideChoice=="one pixel inside") {blob_id[i] = getResult("Max", i);}
		if (InsideChoice=="half inside") {blob_id[i] = getResult("Mode", i);}
		if (InsideChoice=="completely inside") {blob_id[i] = getResult("Min", i);}
	}
	run("Clear Results"); 
	for (i=0; i<nR;i++) {
		setResult("Area", i, area[i]);
		setResult("Bassoon_id", i, blob_id[i]);
	}
	updateResults();
	saveAs("Results", outFile + ".munc.csv");
	
	// Merge and save segmentation 
	run("Merge Channels...", "c1=Bassoon c2=Munc c3=Marker create");
	run("RGB Color");
	saveAs("Tiff", outFile + ".segmented.tif");

	// Close all images and the Results manager
	while (nImages>0) { selectImage(nImages); close(); } 
	selectWindow("Results"); 
	run("Close"); 
}

list = getFileList(indir);
for (i=0; i<list.length; i++) {
	if ((endsWith(list[i], ".tif")) || (endsWith(list[i], ".png"))){
		inFile = ""+indir+"/"+list[i];
		outFile = ""+outdir+"/"+list[i];
		segment(inFile, outFile);
		}
	}



