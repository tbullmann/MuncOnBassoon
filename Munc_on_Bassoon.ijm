// Dialog
#@ File(label="Select a input directory", style='directory') indir
#@ File(label="Select a output directory", style='directory') outdir

#@ String(label="Red channel", choices={"Bassoon", "Munc", "Marker"}, value="Munc", style="listBox") channel_red
#@ String(label="Green channel", choices={"Bassoon", "Munc", "Marker"}, value="Bassoon", style="listBox") channel_green
#@ String(label="Blue channel", choices={"Bassoon", "Munc", "Marker"}, value="Marker", style="listBox") channel_blue

#@ String(label="Munc threshold", value="Auto") threshold_Munc 
#@ Integer(label="Minimal diameter of Munc spots (pixel)", value=2) minimum_diameter_Munc
#@ Integer(label="Maximal diameter of Munc spots (pixel)", value=6) maximum_diameter_Munc
#@ Integer(label="Maximal distance of Munc spots in cluster (pixel)", value=8) maximal_distance_Munc
#@ String(label="Munc spot distance measured between", choices={"Borders", "Centroids", "Skeletons"}, value="Border", style="listBox") distance_between

#@ String(label="Bassoon threshold", value="Auto") threshold_Bassoon
#@ Integer(label="Minimal diameter of Bassoon blobs (pixel)", value=10) minimum_diameter_Bassoon
#@ Integer(label="Maximal diameter of Bassoon blobs (pixel)", value=25) maximum_diameter_Bassoon
#@ Integer(label="Dilate Bassoon blobs (pixel)", value=1) dilations_Bassoon

#@ String(label="Marker threshold", value="Auto") threshold_Marker
#@ Integer(label="Minimal diameter of synapses (pixel)", value=50) min_diameter_Marker
#@ Integer(label="Maximal diameter of synapses (pixel)", value=150) max_diameter_Marker

// Parameters
min_area_Munc = minimum_diameter_Munc*minimum_diameter_Munc*3.1415/4
min_area_Bassoon = minimum_diameter_Bassoon*minimum_diameter_Bassoon*3.1415/4

// Segment a single image
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
	rename(channel_red);
	selectWindow("input (green)");
	rename(channel_green);
	selectWindow("input (blue)");
	rename(channel_blue);


	// ANALYSE MARKER
	// Segment Marker for pre-synapses
	selectWindow("Marker");
	run("Gaussian Blur...", "sigma=" + min_diameter_Marker/2);
	run("Subtract Background...", "rolling=" + max_diameter_Marker/2);	
	if (threshold_Marker=="Auto"){setAutoThreshold("Default dark no-reset");} else {setThreshold(parseInt(threshold_Marker), 255);}
	getThreshold(used_threshold_Marker, dummy);
	run("Convert to Mask");
	run("Median...", "radius=5"); // ringing artifacts


	// ANALYSE BASSON  
	// Segment Bassoon blobs
	selectWindow("Bassoon");
	run("Gaussian Blur...", "sigma=" + minimum_diameter_Bassoon/2);
	run("Subtract Background...", "rolling=" + maximum_diameter_Bassoon/2);	
	if (threshold_Bassoon=="Auto"){setAutoThreshold("Default dark no-reset");} else {setThreshold(parseInt(threshold_Bassoon), 255);}
	getThreshold(used_threshold_Bassoon, dummy);
	run("Convert to Mask");
	for (i=0; i<dilations_Bassoon; i++) {run("Dilate");}
	// run("Set Measurements...", "area mean redirect=Marker decimal=3");
	run("Set Measurements...", "area min redirect=Marker decimal=3");
	// First get the masks for segmentation images
	run("Analyze Particles...", "size=min_bassoon_area-Infinity show=Masks exclude clear include");
	// exclude (blobs at the image border), clear (measuremnts), include (holes in the blobs)
    selectWindow("Bassoon"); run("Analyze Particles...", "size=min_bassoon_area-Infinity show=[Count Masks] exclude clear include");
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
		if (getResult("Max", i-1) > 0) {Marker_overlap[i] = 1;} else {Marker_overlap[i] = 0;} 
	}
	Bassoon_area[0] = getWidth() * getHeight() - total_Bassoon_area;


	// ANALYSE MUNC 
	// Segment Munc spots
	selectWindow("Munc");
	rename("MuncRaw");
    run("Duplicate...", "title=Munc");
	run("Gaussian Blur...", "sigma=" + minimum_diameter_Munc/2);
	run("Subtract Background...", "rolling=" + maximum_diameter_Munc/2);	
	if (threshold_Munc=="Auto"){setAutoThreshold("Default dark no-reset");} else {setThreshold(parseInt(threshold_Munc), 255);}
	getThreshold(used_threshold_Munc, dummy);
	run("Convert to Mask");
	run("Set Measurements...", "centroid area min redirect=[Count Masks of Bassoon] decimal=3");
	run("Analyze Particles...", "size=min_area_Munc-Infinity show=Nothing exclude clear include");
	// Save results to Munc spot Area and Basson blob id (from the Measure)
	nR2 = nResults;
	Munc_area = newArray(nR2);
	Munc_x = newArray(nR2);
	Munc_y = newArray(nR2);
	Bassoon_id = newArray(nR2);
	for (i=0; i<nR2;i++) {
		Munc_area[i] = getResult("Area", i);
		Munc_x[i] = getResult("X", i);
		Munc_y[i] = getResult("Y", i);
		Bassoon_id[i] = getResult("Max", i);
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
	run("Analyze Particles...", "size=min_area_Munc-Infinity show=Masks exclude clear include");
	// Save results to Munc spot Area and Basson blob id (from the Measure)
	Munc_mean = newArray(nR2);
	for (i=0; i<nR2;i++) {
		Munc_mean[i] = getResult("Mean", i);
	}


	// CLUSTER MUNC SPOTS
    selectWindow("Mask of Munc");
    run("Duplicate...", "title=MuncCluster");
    run("Convert to Mask");    
    if (distance_between == "Centroids"){
    	run("Select All"); run("Clear", "slice");                    // Clear all Munc spots
    	for (i=0; i<nR2;i++) {setPixel(Munc_x[i], Munc_y[i], 255);}  // Place a single pixel at center of each Munc spot
    	}
    if (distance_between == "Skeletons") {run("Skeletonize");}	
    run("Maximum...", "radius="+(maximal_distance_Munc/2));
	run("Set Measurements...", "min redirect=Marker decimal=3");
	// First get the masks for segmentation images
	selectWindow("MuncCluster"); run("Analyze Particles...", "size=min_area_Munc-Infinity show=[Bare Outlines] exclude clear include");
	// exclude (clusters at the image border), clear (measurements), include (holes in the clusters)
	selectWindow("MuncCluster"); run("Analyze Particles...", "size=min_area_Munc-Infinity show=[Count Masks] display exclude clear include");
    nR3 = nResults + 1;   
	Cluster_Marker_overlap = newArray(nR3);
    Cluster_Munc_count = newArray(nR3);
	for (i=1; i<nR3;i++) {
		if (getResult("Max", i-1) > 0) {Cluster_Marker_overlap[i] = 1;} else {Cluster_Marker_overlap[i] = 0;}
	}
	run("Clear Results");
	// Get Cluster id for each Munc spot
	selectWindow("Mask of Munc");
	run("Convert to Mask");    
    run("Set Measurements...", "min redirect=[Count Masks of MuncCluster] decimal=3");
	run("Analyze Particles...", "size=1-Infinity show=Nothing exclude clear include");
	// Save results to Cluster id (from the Measure)
	Cluster_id = newArray(nR2);
	for (i=0; i<nR2;i++) {
		Cluster_id[i] = getResult("Min", i);
	}
	run("Clear Results");
    // Count Munc Spots per Cluster
    for (j=0; j<nR2; j++) {          // iterate through all munc spots
    	Cluster_Munc_count[Cluster_id[j]]+=1; // increase count for cluster id
    }


	// SAVE RESULTS
    // Save Munc cluster results: Marker overlap, Munc Count per Cluster
	run("Clear Results");
	for (i=0; i<nR3;i++) {
		setResult("Cluster_id", i, i);
		setResult("Marker_overlap", i, Cluster_Marker_overlap[i]);
		setResult("Munc_count", i, Cluster_Munc_count[i]);
	}
	updateResults();
	setOption("ShowRowNumbers", false);
	saveAs("Results", outFile+".cluster.csv");

	// Save Bassoon blob results: Bassoon Area, Marker Mean, Munc Count per Basson blob
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
    
	// Save Munc spot results: Munc Area, Position, Mean, Basson blob id, Cluster id
	run("Clear Results");
	for (i=0; i<nR2;i++) {
		setResult("Munc_id", i, i+1);
		setResult("Munc_area", i, Munc_area[i]);
		setResult("Munc_x", i, Munc_x[i]);
		setResult("Munc_y", i, Munc_y[i]);
		setResult("Munc_mean", i, Munc_mean[i]);
		setResult("Bassoon_id", i, Bassoon_id[i]);
		setResult("Cluster_id", i, Cluster_id[i]);
	}
	updateResults();
	setOption("ShowRowNumbers", false);
	saveAs("Results", outFile + ".munc.csv");


	// SAVE SEGMENTATION
	//Invert Outlines of Munc cluster to white on black
	selectWindow("Drawing of MuncCluster"); run("Invert");

	// Mask of Munc shows only particles large enough
	selectWindow("Munc"); close();
	selectWindow("Mask of Munc"); rename("Munc");
	
	// Mask of Bassoon shows only particles large enough
	selectWindow("Bassoon"); close();
	selectWindow("Mask of Bassoon"); rename("Bassoon");
	
	// Merge and save segmentation
	run("Merge Channels...", "c1=" + channel_red + " c2=" + channel_green + " c3=" + channel_blue + " c4=[Drawing of MuncCluster] " + " create" );
	selectWindow("Composite");  // On some Mac Version of FIJI, this seems neccessary
	run("RGB Color");
	selectWindow("Composite (RGB)");
	run("Duplicate...", "title=Segmented");
	selectWindow("Composite (RGB)");
	saveAs("PNG", outFile + ".segmented.png");

	// Side by side montage
	selectWindow("Raw");
	getDimensions(w, h, c, z, t);
	run("Canvas Size...", "width="+ 2*w +" height="+ h +" position=Top-Left");
	run("Insert...", "source=Segmented destination=Raw x="+ w +" y=0");
	saveAs("PNG", outFile + ".compare.png");

	// Close all images and the Results manager
    while (nImages>0) { selectImage(nImages); close(); }
	selectWindow("Results");
	run("Close");


	// SAVE PARAMETERS AND RETURN THRESHOLDS
	// Save parameters as YAML
	File.delete(outFile + ".parameters.yaml")
	f=File.open(outFile + ".parameters.yaml");
	print(f, "# Parameters used for segmentation\n");
	print(f, "channels:");
	print(f, "   red: " + channel_red);
	print(f, "   green: " + channel_green);
	print(f, "   blue: " + channel_blue);
	print(f, "Munc:");
	print(f, "   threshold: " + used_threshold_Munc);
	if (threshold_Munc=="Auto"){print(f, "   thresholding: Auto");} else {print(f, "   thresholding: Fixed");}
	print(f, "   min_diameter: " + minimum_diameter_Munc);
	print(f, "   max_diameter: " + maximum_diameter_Munc);
	print(f, "   cluster_distance: " + maximal_distance_Munc);
	print(f, "   distance_between: " + distance_between);
	
	print(f, "Bassoon:");
	print(f, "   threshold: " + used_threshold_Bassoon);
	if (threshold_Bassoon=="Auto"){print(f, "   thresholding: Auto");} else {print(f, "   thresholding: Fixed");}	
	print(f, "   min_diameter: " + minimum_diameter_Bassoon);
	print(f, "   max_diameter: " + maximum_diameter_Bassoon);
	print(f, "   dilations: " + dilations_Bassoon);
	print(f, "Marker:");
	print(f, "   threshold: " + used_threshold_Marker);
	if (threshold_Marker=="Auto"){print(f, "   thresholding: Auto");} else {print(f, "   thresholding: Fixed");}
	print(f, "   min_diameter: " + min_diameter_Marker);
	print(f, "   max_diameter: " + max_diameter_Marker);
	File.close(f);

	// return thresholds
	used_thresholds  = newArray(3);
	used_thresholds[0] = used_threshold_Munc;
	used_thresholds[1] = used_threshold_Bassoon;
	used_thresholds[2] = used_threshold_Marker;
	return used_thresholds;
}


// main 
used_thresholds  = newArray(3);  
list = getFileList(indir);
used_filenames = newArray(list.length);
used_thresholds_Munc = newArray(list.length);
used_thresholds_Bassoon = newArray(list.length);
used_thresholds_Marker = newArray(list.length);

j = 0;   //counting used files (as there might be other files in the indir)
for (i=0; i<list.length; i++) {
	if ((endsWith(list[i], ".tif")) || (endsWith(list[i], ".png"))){
		inFile = ""+indir+"/"+list[i];
		outFile = ""+outdir+"/"+list[i];
		used_thresholds = segment(inFile, outFile);
		// storing used filename and associated thresholds
		print ("Segmented " + (j+1) + ". image");
		used_filenames[j] = list[i];
		used_thresholds_Munc[j] = used_thresholds[0];
		used_thresholds_Bassoon[j] = used_thresholds[1];
		used_thresholds_Marker[j] = used_thresholds[2];
		j++;  //increment index for next used file
		}
	}

// Save the used thresholds for each file as  csv
// List only values for used files
print ("Saving thresholds for " + j + " image files..");
run("Clear Results");
for (i=0; i<j;i++) {
	setResult("input_filename", i, used_filenames[i]);
	setResult("used_threshold_Munc", i, used_thresholds_Munc[i]);
	setResult("used_threshold_Bassoon", i, used_thresholds_Bassoon[i]);
	setResult("used_threshold_Marker", i, used_thresholds_Marker[i]);
}
updateResults();
setOption("ShowRowNumbers", false);
saveAs("Results", outdir + "/used_thresholds.csv");
// Close Results manager
selectWindow("Results");
run("Close");
	