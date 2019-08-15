// Dialog
#@ File(label="Select a input directory", style='directory') indir
#@ File(label="Select a output directory", style='directory') outdir

#@ String(label="Red channel", choices={"Bassoon", "Munc", "Marker"}, value="Munc", style="listBox") RedChoice
#@ String(label="Green channel", choices={"Bassoon", "Munc", "Marker"}, value="Bassoon", style="listBox") GreenChoice
#@ String(label="Blue channel", choices={"Bassoon", "Munc", "Marker"}, value="Marker", style="listBox") BlueChoice

#@ String(label="Bassoon threshold", value="Auto") minBassoon
#@ Integer(label="Minimal diameter of Bassoon blobs (pixels)", value=10) minBassoonSize
#@ Integer(label="Maximal diameter of Bassoon blobs (pixels)", value=25) maxBassoonSize
#@ Integer(label="Dilate Bassoon blobs (pixels)", value=1) dilate_basson_blob

#@ String(label="Munc threshold", value="Auto") minMunc 
#@ Integer(label="Minimal diameter of Munc spots (pixels)", value=2) minMuncSize
#@ Integer(label="Maximal diameter of Munc spots (pixels)", value=6) maxMuncSize
#@ String(label="Munc spot in Bassoon blob when", choices={"one pixel inside", "half inside", "completely inside"}, value="half inside", style="listBox") InsideChoice

#@ String(label="Marker threshold", value="Auto") minMarker
#@ Integer(label="Minimal diameter of synapses (pixel)", value=50) minMarkerSize
#@ Integer(label="Maximal diameter of synapses (pixel)", value=150) maxMarkerSize
#@ String(label="Minimum overlap for Marker-positive Bassoon blobs (pixels)", value=1) min_Marker_overlap

// Parameters
min_spot_area = minMuncSize*minMuncSize*3.1415/4
min_blob_area = minBassoonSize*minBassoonSize*3.1415/4

// How to get the Basson blob id from the Count Mask
if (InsideChoice=="one pixel inside") {Measure="min";}
if (InsideChoice=="half inside") {Measure="modal";}
if (InsideChoice=="completely inside") {Measure="min";}

function segment(inFile, outFile){
	// Open and rename for processing
	open(inFile);
	rename("Raw");
	run("Duplicate...", "title=input");
    
	// TODO: Instead of the following reset of the scale to 1/pixel
	// adjust the parameters measured in pixel according to the scale in the tiff
	run("Set Scale...", "known=1 unit=pixel");

	// Split colors and rename each channel according to Dialog for processing
	if (bitDepth()!=24) {
		print("Skipped non RGB image " + inFile);
		close();
		return; }  
    run("Split Channels");
	selectWindow("input (red)");
	rename(RedChoice);
	selectWindow("input (green)");
	rename(GreenChoice);
	selectWindow("input (blue)");
	rename(BlueChoice);

	// Analyse Marker
	selectWindow("Marker");
	run("Gaussian Blur...", "sigma=" + minMarkerSize/2);
	run("Subtract Background...", "rolling=" + maxMarkerSize/2);	
	if (minMarker=="Auto"){setAutoThreshold("Default dark no-reset"); getThreshold(Auto_minMarker, dummy); } else {setThreshold(parseInt(minMarker), 255);}
	run("Convert to Mask");
	run("Median...", "radius=5"); // ringing artifacts

	// Analyse Basoon blobs
	selectWindow("Bassoon");
	run("Gaussian Blur...", "sigma=" + minBassoonSize/2);
	run("Subtract Background...", "rolling=" + maxBassoonSize/2);	
	if (minBassoon=="Auto"){setAutoThreshold("Default dark no-reset"); getThreshold(Auto_minBassoon, dummy);} else {setThreshold(parseInt(minBassoon), 255);}
	setOption("BlackBackground", true);
	run("Convert to Mask");
	for (i=0; i<dilate_basson_blob; i++) {run("Dilate");}
	// run("Set Measurements...", "area mean redirect=Marker decimal=3");
	run("Set Measurements...", "area mean redirect=Marker decimal=3");
	// exclude (blobs at the image border), clear (measuremnts), include (holes in the blobs)
    run("Analyze Particles...", "size=min_bassoon_area-Infinity show=[Count Masks] exclude clear include");
    // Save results to Bassoon spot Area and Mean of Marker
	nR1 = 1 + nResults;   // additional for background with Bassoon id = 0
	Bassoon_area = newArray(nR1);
	Marker_overlap = newArray(nR1);
    Munc_count = newArray(nR1);
    Munc_density = newArray(nR1);
    total_Bassoon_area = 0;
	for (i=1; i<nR1;i++) {
		total_Bassoon_area  += getResult("Area", i-1);
		Bassoon_area[i] = getResult("Area", i-1);
		// it is not possible to directly count the number of pixels in the ROI, therefore we use sum = mean * area
		if (getResult("Mean", i-1) * getResult("Area", i-1) >= min_Marker_overlap) {Marker_overlap[i] = 1;} else {Marker_overlap[i] = 0;}
	}
	Bassoon_area[0] = getWidth() * getHeight() - total_Bassoon_area;

	// Analyse Munc spots
	selectWindow("Munc");
	rename("MuncRaw");
    run("Duplicate...", "title=Munc");
	run("Gaussian Blur...", "sigma=" + minMuncSize/2);
	run("Subtract Background...", "rolling=" + maxMuncSize/2);	
	if (minMunc=="Auto"){setAutoThreshold("Default dark no-reset"); getThreshold(Auto_minMunc, dummy);} else {setThreshold(parseInt(minMunc), 255);}
	run("Convert to Mask");
	run("Set Measurements...", "area " + Measure + " redirect=[Count Masks of Bassoon] decimal=3");
	run("Analyze Particles...", "size=min_spot_area-Infinity show=[Bare Outlines] exclude clear include");
	// Save results to Munc spot Area and Basson blob id (from the Measure)
	nR2 = nResults;
	Munc_area = newArray(nR2);
	Bassoon_id = newArray(nR2);
	for (i=0; i<nR2;i++) {
		Munc_area[i] = getResult("Area", i);
		if (InsideChoice=="one pixel inside") {Bassoon_id[i] = getResult("Max", i);}
		if (InsideChoice=="half inside") {Bassoon_id[i] = getResult("Mode", i);}
		if (InsideChoice=="completely inside") {Bassoon_id[i] = getResult("Min", i);}
	}

    // Count Munc Spots per Bassoon blob
    for (j=0; j<nR2; j++) {          // iterate through all munc spots
    	Munc_count[Bassoon_id[j]]+=1; // increase count for basson id
    }
    // Munc spot density = Munc count / Bassoon area or background area
    for (i=0; i<nR1; i++) {Munc_density[i] = Munc_count[i] / Bassoon_area[i]; }

    // Measure Munc spot mean intensity
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
		setResult("Bassoon_id", i, i);
		setResult("Bassoon_area", i, Bassoon_area[i]);
		setResult("Marker_overlap", i, Marker_overlap[i]);
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
		setResult("Bassoon_id", i, Bassoon_id[i]);
	}
	updateResults();
	setOption("ShowRowNumbers", false);
	saveAs("Results", outFile + ".munc.csv");
	
	// Merge and save segmentation
	run("Merge Channels...", "c1=" + RedChoice + " c2=" + GreenChoice + " c3=" + BlueChoice + " create");
	selectWindow("Composite");  // On some Mac Version of FIJI, this seems neccessary
	run("RGB Color");
	selectWindow("Composite (RGB)");
	run("Duplicate...", "title=Segmented");
	selectWindow("Composite (RGB)");
	saveAs("Tiff", outFile + ".segmented.tif");

	// Side by side montage
	//run("Combine...", "stack1=Raw stack2=Segmented");
	//run("Stack to Hyperstack...", "order=xyczt(default) channels=&c slices=&z frames=&t display=Composite");
	selectWindow("Raw");
	getDimensions(w, h, c, z, t);
	run("Canvas Size...", "width="+ 2*w +" height="+ h +" position=Top-Left");
	run("Insert...", "source=Segmented destination=Raw x="+ w +" y=0");
	saveAs("Tiff", outFile + ".compare.tif");


	// Close all images and the Results manager
    while (nImages>0) { selectImage(nImages); close(); }
	selectWindow("Results");
	run("Close");

		// Save parameters
	File.delete(outFile + ".parameters.yaml")
	f=File.open(outFile + ".parameters.yaml");
	print(f, "# Parameters used for segmentation\n");
	print(f, "channels:");
	print(f, "   red: " + RedChoice);
	print(f, "   green: " + GreenChoice);
	print(f, "   blue: " + BlueChoice);
	print(f, "Bassoon:");
	if (minBassoon=="Auto"){
		print(f, "   threshold: " + Auto_minBassoon);
		print(f, "   thresholding: Auto");} 
	else {
		print(f, "   threshold: " + minBassoon);
		print(f, "   thresholding: Fixed");}	
	print(f, "   min_diameter: " + minBassoonSize);
	print(f, "   max_diameter: " + maxBassoonSize);
	print(f, "   dilations: " + dilate_basson_blob);
	print(f, "Munc:");
	if (minMunc=="Auto"){
		print(f, "   threshold: " + Auto_minMunc);
		print(f, "   thresholding: Auto");} 
	else {
		print(f, "   threshold: " + minMunc);
		print(f, "   thresholding: Fixed");}
	print(f, "   min_diameter: " + minMuncSize);
	print(f, "   max_diameter: " + maxMuncSize);
	print(f, "   inside_choice: " + InsideChoice);
	print(f, "Marker:");
	if (minMarker=="Auto"){
		print(f, "   threshold: " + Auto_minMarker);
		print(f, "   thresholding: Auto");} 
	else {
		print(f, "   threshold: " + minMarker);
		print(f, "   thresholding: Fixed");}
	print(f, "   min_diameter: " + minMarkerSize);
	print(f, "   max_diameter: " + maxMarkerSize);
	print(f, "   min_overlap: " + min_Marker_overlap);
	File.close(f);

}

list = getFileList(indir);
for (i=0; i<list.length; i++) {
	if ((endsWith(list[i], ".tif")) || (endsWith(list[i], ".png"))){
		inFile = ""+indir+"/"+list[i];
		outFile = ""+outdir+"/"+list[i];
		segment(inFile, outFile);
		}
	}
