// Dialog
#@ File(label="Select a input directory", style='directory') indir
#@ File(label="Select a output directory", style='directory') outdir
#@ String(label="Red channel", choices={"Bassoon", "Munc", "Marker"}, value="Munc", style="listBox") RedChoice
#@ String(label="Green channel", choices={"Bassoon", "Munc", "Marker"}, value="Bassoon", style="listBox") GreenChoice
#@ String(label="Blue channel", choices={"Bassoon", "Munc", "Marker"}, value="Marker", style="listBox") BlueChoice
#@ String(label="Bassoon threshold", value="Auto") minBassoon
#@ Integer(label="Minimum area of Bassoon blobs (pixels)", value=250) min_bassoon_area
#@ Integer(label="Dilate area of Bassoon blobs (times)", value=1) dilate_basson_blob
#@ String(label="Munc threshold", value="Auto") minMunc 
#@ Integer(label="Average diameter of Munc spots (pixel)", value=1) spot_size
#@ String(label="Munc spot in Bassoon blob when", choices={"one pixel inside", "half inside", "completely inside"}, value="half inside", style="listBox") InsideChoice

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
	getDimensions(width, height, channels, slices, frames);

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
    run("Analyze Particles...", "size=min_bassoon_area-Infinity show=[Count Masks] exclude clear include");
    // Save results to Bassoon spot Area and Mean of Marker
	nR1 = 1 + nResults;   // additional for background with Bassoon id = 0
	Bassoon_area = newArray(nR1);
	Marker_mean = newArray(nR1);
    Munc_count = newArray(nR1);
    Munc_density = newArray(nR1);
    total_Bassoon_area = 0;
	for (i=1; i<nR1;i++) {
		total_Bassoon_area  += getResult("Area", i-1);
		Bassoon_area[i] = getResult("Area", i-1);
		Marker_mean[i] = getResult("Mean", i-1);
	}
	Bassoon_area[0] = width * height - total_Bassoon_area;

	// Analyse Munc spots
	selectWindow("Munc");
	rename("MuncRaw");
    run("Duplicate...", "title=Munc");
	run("Gaussian Blur...", "sigma=spot_size");
	run("Subtract Background...", "rolling=spot_background_size");
	if (minMunc=="Auto"){setAutoThreshold("Default dark no-reset");} else {setThreshold(parseInt(minMunc), 255);}
	run("Convert to Mask");
	run("Set Measurements...", "area " + Measure + " redirect=[Count Masks of Bassoon] decimal=3");
	run("Analyze Particles...", "size=min_spot_area-Infinity show=[Bare Outlines] exclude clear include");
	// Save results to Munc spot Area and Basson blob id (from the Measure)
	nR2 = nResults;
	Munc_area = newArray(nR2);
	Basson_id = newArray(nR2);
	for (i=0; i<nR2;i++) {
		Munc_area[i] = getResult("Area", i);
		if (InsideChoice=="one pixel inside") {Basson_id[i] = getResult("Max", i);}
		if (InsideChoice=="half inside") {Basson_id[i] = getResult("Mode", i);}
		if (InsideChoice=="completely inside") {Basson_id[i] = getResult("Min", i);}
	}

    // Count Munc Spots per Bassoon blob
    for (j=0; j<nR2; j++) {          // iterate through all munc spots
    	Munc_count[Basson_id[j]]+=1; // increase count for basson id
    }
    // Munc spot density = Munc count / Bassoon area or background area
    for (i=0; i<nR1; i++) {Munc_density[i] = Munc_count[i] / Bassoon_area[i]; }

    // Measure und save Munc spot mean intensity
    selectWindow("Munc");
    run("Convert to Mask");
	run("Set Measurements...", "area mean redirect=MuncRaw decimal=3");
	run("Analyze Particles...", "size=min_spot_area-Infinity show=[Bare Outlines] exclude clear include");
	// Save results to Munc spot Area and Basson blob id (from the Measure)
	Munc_mean = newArray(nR2);
	for (i=0; i<nR2;i++) {
		Munc_mean[i] = getResult("Mean", i);
	}

	// Save result table with Bassoon Area, Marker Mean, Munc Count per Basson blob
	run("Clear Results");
	for (i=0; i<nR1;i++) {
//		setResult("Basson_id", i, Bassoon_label[i]);
		setResult("Basson_id", i, i);
		setResult("Basson_area", i, Bassoon_area[i]);
		setResult("Marker_mean", i, Marker_mean[i]);
		setResult("Munc_count", i, Munc_count[i]);
		setResult("Munc_density", i, Munc_density[i]);
	}
	updateResults();
	setOption("ShowRowNumbers", false);
	saveAs("Results", outFile+".bassoon.csv");
    
	// Save result table with Area and Basson blob id (from the Measure)
	run("Clear Results");
	for (i=0; i<nR2;i++) {
		setResult("Munc_id", i, i+1);
		setResult("Munc_area", i, Munc_area[i]);
		setResult("Munc_mean", i, Munc_mean[i]);
		setResult("Bassoon_id", i, Basson_id[i]);
	}
	updateResults();
	setOption("ShowRowNumbers", false);
	saveAs("Results", outFile + ".munc.csv");

	// Merge and save segmentation
	run("Merge Channels...", "c1=" + RedChoice + " c2=" + GreenChoice + " c3=" + BlueChoice + " create");
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
