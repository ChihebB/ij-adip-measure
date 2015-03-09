// Action Bar description file : Semester Project Chiheb Boussema
// Supervisor BIOP: Olivier Burri
// Supervisor Regenerative Hematopoiesis Lab: Prof. Olaia Naveiras



sep = File.separator;
// Install the BIOP Library
call("BIOP_LibInstaller.installLibrary", "BIOP"+sep+"BIOPLib.ijm");


run("Action Bar","/plugins/ActionBar/ij-adip-measure/Adip_Measure.ijm");

exit();

<codeLibrary>
function toolName() {
	return "Cellularity Measurement";
}

function drawRois(category) {
	if (getVersion>="1.37r")
        	setOption("DisablePopupMenu", true);

	// Setup some variables. Basically these numbers
	// Represent an action that has taken place (it's the action's ID)
	shift=1;
	ctrl=2; 
	rightButton=4;
	alt=8;
	leftButton=16;
	insideROI = 32; // requires 1.42i or later

	// Now we initialize the ROI counts and check if there are already ROIs with this name. 
	
	roiNum = 0;

	// done boolean to stop the loop that checks the mouse's location
	done=false;

	// rightClicked to make sure the function saves the ROI ONCE and not
	// continuously while "right click" is presed
	rightClicked = false;
	print("Started mouse tracking for "+category);
	print("-----> Draw a ROI, then RIGHT CLICK when done");
	print("-----> Press 'ALT' to stop adding ROIs");
	while(!done) {
		// getCursorLoc gives the x,y,z position of the mouse and the flags associated
		// to see if a particular action has happened, say a left click while shift is 
		// pressed, you do it like this: 
		// if (flags&leftButton!=0 && flags&shift!=0) { blah blah... }
		
		getCursorLoc(x,y,z,flags);
		// print(x,y,z,flags);
		//If a freehand selection exists and the right button was clicked AND that right click was not pressed before already
		if (flags&rightButton!=0 && selectionType!=-1 && !rightClicked) {
			// set rightCLicked to true to stop this condition from writing several times the same ROI
			rightClicked = true;

			// Add the ROI to the manager
			Roi.setName(category+" #"+roiNum+1);
			roiManager("Add");
			roiNum++;
			print(roiNum+" added.");
		}

		// Once we stopped pressing the right mouse button, we can then click it again and add a new ROI
		if (flags&rightButton==0) {
			rightClicked = false;
		}
		
		//We stop the loop when the user presses ALT
		if(isKeyDown("alt")) {
			done=true;
			print("ALT Pressed: Done");
			setKeyDown("none");
		}

		// This wait of 10ms is just to avoid checking the mouse position too often
		wait(10);
	}
	// Here we are out of the drawROI loop, so you can do some post processing already here if you want

}
function mergeArtifacts() {
	// Look for Artifact Rois
	n = roiManager("count");
	artifacts=newArray(n-1);
	for (i=1; i<n; i++) {
		artifacts[i-1]=i;
	}
	
	roiManager("Select", artifacts);
	roiManager("OR");
	Roi.setName("Artifacts");
	roiManager("Add");
	roiManager("Select", artifacts);
	
}


function preprocessDrawRois() {
	// Draw outline of interest
	setTool("polygon");
	waitForUser("Draw the tissue boundaries, then press OK.");
	Roi.setName("Tissue boundaries");
	roiManager("Add");
	
	// Draw as many Artifact Regions as needed
	setTool("free hand");
	drawRois("Artifacts");
	// save ROI set of current Image
	saveRois("Open");

}

// Find ROIs with a given regular expression. First index returned.
function findRoiWithName(roiName) {
	nR = roiManager("Count");

	for (i=0; i<nR; i++) {
		roiManager("Select", i);
		rName = Roi.getName();
		if (matches(rName, roiName)) {
			return i;
		}
	}
	return -1;
}


function processImage(ori) {

	// Make sure that only the tissue boundaries and Artifacts are in the ROI manager
	run("Select None");
	if (findRoiWithName("Artifact*") != -1) {
		mergeArtifacts();
	}
	boneID = getTheBone(ori);
	close(boneID);
	totalAreaHematopCells = processRedCells(ori);
	
	run("Select None");
	nomNdenom=processAdipocytes(ori);
	areaAdips=nomNdenom[0];
	denominator=nomNdenom[1];

	cell1= 100*(totalAreaHematopCells/denominator);
	cell2= 100*(1-areaAdips/denominator);
	return newArray(cell1, cell2) 
}


function processRedCells(ori) {
	selectImage(ori);
	title=getTitle();
	getVoxelSize(Vx,Vy,Vz,Vu);
	run("Colour Deconvolution", "vectors=[H&E DAB] hide");
	close(title+"-(Colour_2)");
	imageCalculator("Subtract", title+"-(Colour_3)", title+"-(Colour_1)");
	rename("HematoCells");
	close(title+"-(Colour_1)");
	
	selectWindow("HematoCells");

	// Locate bone ROI
	roiManager("Select", (lastRoi()) );
	run("Enlarge...", "enlarge=1");
	run("Clear", "slice");
	selectWindow(title);
	setTool("polygon");
	selectWindow("HematoCells");
	//------
	tissueBoundariesRoiID  = 0; // tissue boundaries are alaways ID 0;
	boneroiID = findRoiWithName("Bone"); // Bone ROI.

	RoisManip(tissueBoundariesRoiID, boneroiID, "AND", "Bone Within TB");  //Bone inside TB; 
	boneinTBRoiID=lastRoi();
	
	RoisManip(boneinTBRoiID, tissueBoundariesRoiID, "XOR", "TB-Bone"); //TB without bone, and probably without RBCs
	selectWindow("HematoCells");
	roiManager("Select", (lastRoi()) );
	//-----
	run("Smooth");
	setAutoThreshold("Default dark");
	//setAutoThreshold("Huang dark");
	
	// Convert to mask
	//Run Close
	run("Convert to Mask");
	setVoxelSize(Vx,Vy,Vz,Vu);
	run("Options...", "iterations=1 count=2 black edm=Overwrite do=Close pad");
	roiManager("Select", (lastRoi()) );
	setAutoThreshold("Default dark");
	//setAutoThreshold("Huang dark");
	run("Set Measurements...", "area mean standard min median area_fraction limit display redirect=None decimal=3");
	run("Measure");
	totalArea = getResult("Area", nResults-1);
	return totalArea;
	
}

function processAdipocytes(ori) {	
	// Get Parameters
	adipMin = getDataD("Min Size", 0);
	adipMax = getDataD("Max Size", 1000000000);
	minCir= getDataD("Min Circularity", 0);
	isSelectArtifact = getBoolD("Select Artifact Regions", false);
	isTestAP = getBoolD("Test Particle Analysis Parameters", false);
	
	selectImage(ori);
	title=getTitle();
	getVoxelSize(Vx,Vy,Vz,Vu);
	
	B=findRoiWithName("Bone"); //the bone inside all the image
	artifactsRoi=findRoiWithName("Artifacts"); //merged artifacts in one ROI
	
	//-----------------------------
	//Create the image which highlights the adipocytes and on which we are going to apply
	//the processing
	HSB="HSB-"+title;
	selectWindow(title);
	run("Select None");
	run("Duplicate...", "title=["+HSB+"]");
	
	selectWindow(HSB);
	run("HSB Stack");
	selectWindow(HSB);
	run("Stack to Images");
	close("Hue");
	close("Brightness");
	close(HSB);
	
	selectWindow(title);
	run("Colour Deconvolution", "vectors=[H&E DAB] hide");
	close(title+"-(Colour_2)");
	imageCalculator("Subtract", title+"-(Colour_3)", title+"-(Colour_1)");
	rename("Adip");
	imageCalculator("Add", "Adip", "Saturation");
	imageCalculator("Add", "Adip", "Saturation");
	
	close(title+"-(Colour_1)");
	close("Saturation");
	//-------------------------------------
	
	sigma=1.2;
	run("Gaussian Blur...", "sigma="+sigma);
	setThreshold(0,127);
	run("Convert to Mask");
	roiManager("Select", B); //select the Bone
	run("Enlarge...", "enlarge=1"); //enlarge the selected area of bone
	run("Clear", "slice");
	Roi.setName("Enlarged Bone");
	roiManager("Add");
	EnB=lastRoi(); //Enlarged Bone: EnB
	
	run("Watershed");
	setAutoThreshold("Default dark");
	setVoxelSize(Vx,Vy,Vz,Vu);
	workingImage=getImageID();
	
//*****
	run("Create Selection");//select all the white spaces in the image
	Roi.setName("All white");
	roiManager("Add");
	AllWhite=lastRoi();
//*****

	TB  = 0; // tissue boundaries are alaways ID 0;

//*****
	RoisManip(TB, AllWhite, "AND", "All White in TB");//all white space inside TB
	WhiteInTB=lastRoi();
//*****

	//get the enlarged bone inside TB
	RoisManip(TB,EnB, "AND", "Enlarged Bone Within TB");  //enlarged bone inside the tissue boundaries
	EnBinTB=lastRoi(); //Enlarged Bone inside TB -EnBinTB

	//get the bone inside TB (unnecessary)
	/*RoisManip(TB, B, "AND", "Bone Within TB");
	BoneInTB=lastRoi(); //bone within the tissue boundaries*/

	//** Not necessary **
	/*RoisManip(BoneInTB,TB, "XOR", "TB-Bone");
	TB_Bone=lastRoi();  //TB without bone*/
	//**
	
//*****
	RoisManip(EnBinTB,TB, "XOR", "TB - EnB");
	TB_EnB=lastRoi();  //TB without enlarged bone
	//saveRois("Open");
	//roiManager("Select", TB_EnB );

//*****
	if (artifactsRoi != -1) 
		RoisManip(TB_EnB, artifactsRoi, "XOR", "TB without bone or artifacts");

//*****
	toDelete=newArray(B, EnB, /*BoneInTB,*/ EnBinTB, /*TB_Bone,*/ AllWhite);
	roiManager("select", toDelete );
	roiManager("Delete");
//*****	

	additionalWhiteSpace = false;
	if (isSelectArtifact) {
		//Ask if there is some unwanted white space to be manually selected out
		drawWhite=drawWhiteSpace(ori);  //drawWhite = true if white space was selected, false otherwise
		if (drawWhite) {
		//lastRoi() is the unwanted white space, lastRoi()-1 is the TB without bone nor artifacts
			RoisManip(lastRoi()-1, lastRoi(), "XOR", "Area of Interest"); 
			roiManager("Deselect");
			roiManager("select", (lastRoi()-1) ); //delete unwanted white space
			roiManager("Delete");

			additionalWhiteSpace=true;
		}
	}
	selectImage(workingImage);
	roiManager("Select", (lastRoi()) ); //TB without bone and without unwanted white space
	// if isTestAP = true then the user will be asked to select the parameters when running Analyze Particles
	// otherwise the default values adipMin, adipMax and minCir will be used when running Analyze Particles.
	particlesNumber=ParticleAnalyze(ori, workingImage, roiManager("count"), isTestAP, adipMin, adipMax, minCir); //with this we get the Adipocytes

	
	AdipoParticles=newArray(particlesNumber);
	a=roiManager("count")-1;
	for (i=a; i>=(a-particlesNumber+1); i--) {
		AdipoParticles[a-i]=i;
	}			
	roiManager("Select", AdipoParticles);
	roiManager("OR");//make it in one ROI
	Roi.setName("Adips");
	roiManager("Add");
	roiManager("Select", AdipoParticles);
	roiManager("Delete");
	
	Adips=lastRoi();
	if (additionalWhiteSpace) {
		AOI=lastRoi()-1; //area of interest: TB without enlarged bone and without all artifacts
		TB_EnB_originalArtifacts=lastRoi()-2; //TB without enlarged bone and without the original artifacts drawn in the beginning
		TB_EnB=lastRoi()-3; //TB without enlarged bone
		WhiteInTB=lastRoi()-4;
	} else {
		TB_EnB_originalArtifacts=lastRoi()-1;//TB without enlarged bone and without the original artifacts drawn in the beginning
		TB_EnB=lastRoi()-2; //TB without enlarged bone
		WhiteInTB=lastRoi()-3;
	}
	
	roiManager("select", (Adips));
	run("Enlarge...", "enlarge=1 pixel");
	Roi.setName("Enlarged Adips");
	roiManager("Add");
	EnAdips=lastRoi();

	RoisManip(WhiteInTB, Adips, "XOR", "unwanted white space");
	unwantedWS=lastRoi();
	RoisManip(unwantedWS, TB_EnB, "XOR", "True Area of Interest, without artifacts");
	denominator=lastRoi(); //call it denominator because the measure of this area will be in the denominator when calculating the cellularity
	
	//saveRois("Open");
	
	selectImage(ori);
	//---measure area of the denominator
	roiManager("select", (denominator));
	run("Set Measurements...", "area display redirect=None decimal=3");
	run("Measure");
	//---measure area enlarged adipocytes (nominator)
	roiManager("select", (EnAdips));
	run("Set Measurements...", "area mean standard min median area_fraction display redirect=None decimal=3");
	run("Measure");

	areaAdips = getResult("Area", nResults-1);
	denominator= getResult("Area", nResults-2);
	return newArray(areaAdips, denominator)
}	

function ParticleAnalyze(ori, workingImage, limitNumber, isTestAP, minSize, maxSize, minCir) {
	if (isTestAP) {
		Satisfied=false;	
	} else {
		Satisfied=true;
	}

	if (isTestAP) {
		run("Analyze Particles...");
	} else {
		run("Analyze Particles...", "size="+minSize+"-"+maxSize+"circularity="+minCir+"-1.00 exclude summarize add");
	}
	selectImage(ori);
	roiManager("Show all without labels");
	if (isTestAP) {
		Satisfied=getBoolean("Are you satisfied with these results?");
	}
	
	while (Satisfied==false) {
		if (roiManager("count") > limitNumber) {   //delete the particles
			particles=newArray(roiManager("count")-limitNumber);	
			for (i=0; i<particles.length; i++) {
				particles[i]=i+limitNumber;
			}			
		roiManager("Select", particles);
		roiManager("Delete");
		}		
		if (drawWhiteSpace(ori)) {
			RoisManip(lastRoi()-1, lastRoi(), "XOR", "Area of Interest"); //lastRoi() is the unwanted white space, lastRoi()-1 is the TB without bone
			roiManager("Select", (lastRoi()-1) ); //delete white space
			roiManager("Delete");
		}
		limitNumber=roiManager("count");
		selectImage(workingImage);
		roiManager("Select", (lastRoi()));
		if (isTestAP) {
			run("Analyze Particles...");
		} else {
			run("Analyze Particles...", "size="+minSize+"-"+maxSize+"circularity="+minCir+"-1.00 exclude summarize add");
		}
		selectImage(ori);
		roiManager("Show all without labels");
		Satisfied=getBoolean("Are you satisfied with these results?");
	}
	return roiManager("count")-limitNumber; //Particles Number
}


function batchProcessFolder() { 
	nI = getNumberImages();
	results=newArray(3*nI); //each image gives 3 results: its name and 2 cellularity measures
	for (i=0; i<nI; i++) {
		roiManager("reset");
		openImage(i);
		ori=getImageID();
		name=getTitle();
		cellularities=processImage(ori);
		results[3*i]=name;
		results[3*i+1]=cellularities[0]; //this is cellularity 1
		results[3*i+2]=cellularities[1]; //this is cellularity 2
		close("*");  //close all images
	}
	//now put the results in a clean table containing the name of the image and both cellularity estimations
	prepareTable("Results_Window");
	run("Clear Results");
	for (i=0; i<nI; i++) {
		setResult("Image Name", i, results[3*i]);
		setResult("Cellularity 1", i, results[3*i+1]);
		setResult("Cellularity 2", i, results[3*i+2]);
	}
	closeTable("Results_Window");
	selectWindow("Results_Window");
}

function lastRoi() {
	return roiManager("count")-1;
}

function getTheBone(ori) {
	selectImage(ori);
	title=getTitle();
	bone="Bone";
	run("Colour Deconvolution", "vectors=[H&E 2] hide");
	close(title+"-(Colour_1)");
	close(title+"-(Colour_3)");
	selectWindow(title+"-(Colour_2)");
	setAutoThreshold("Default");
	run("Convert to Mask");
	run("Options...", "iterations=7 count=5 black edm=Overwrite do=Open");
	closeIterations=8; // or 7
	run("Options...", "iterations="+closeIterations+" count=3 black edm=Overwrite do=Close pad");
	rename(bone+"-"+title);
	run("Create Selection");
	//----
	Roi.setName("Bone");
	roiManager("Add");
	//if (selectRBC(ori)) {
	//	RoisManip(lastRoi(),lastRoi()-1, "XOR", "bone without RBCs");
	//}
	return bone+"-"+title;
}


function drawWhiteSpace(ori) {  //allows drawing white space and returns a boolean true when doing so
	draw=getBoolean("Do you want to draw big white regions?");
	managerCount=roiManager("count");
	if (draw) {
		setTool("free hand");
		selectImage(ori);
		//waitForUser("Draw unwanted white spaces within tissue boundaries and press Add in the ROI Manager, then when finished press OK.");
		
		drawRois("Additional artifacts");
		
		if (roiManager("count")!=managerCount) //user has indeed selected regions
		{
			regions=roiManager("count")-managerCount;  //number of added regions
			whiteSpace=newArray(regions);
			for (i=regions; i>0; i--) {
				whiteSpace[regions-i]=i+managerCount-1;  //eg.: whiteSpace[0]=regions + managerCount -1
			}
			roiManager("Select", whiteSpace);
			if (regions > 1) {
				roiManager("OR");
			}
			Roi.setName("White Space");
			roiManager("Add");
			WS=roiManager("select", (roiManager("count")-1));
			roiManager("Select", whiteSpace);
			roiManager("Delete");

			// save ROI set of current Image
			//saveRois("Open");
		}
		return true;
	} else {
		return false;
	}
}

function RoisManip(roi1, roi2, actionType, roiName) {
	array=newArray(roi1,roi2);
	roiManager("Select", array);
	roiManager(""+actionType);
	Roi.setName(""+roiName); 
	roiManager("Add");
}

function selectRBC(ori) {  //allows drawing RBCs and returns a boolean true when doing so
	draw=getBoolean("Do you want to manually select RBC-rich regions?");
	managerCount=roiManager("count");
	if (draw) {
		setTool("free hand");
		selectImage(ori);
		waitForUser("Draw RBC regions and press Add in the ROI Manager, then when finished press OK.");

		if (roiManager("count")!=managerCount) //user has indeed selected regions
		{
			regions = roiManager("count")-managerCount;
			RBCs=newArray(regions);
			for (i=regions; i>0; i--) {
				RBCs[regions-i]=i+managerCount-1;  //
			}
			roiManager("Select", RBCs);
			if (regions > 1) {
				roiManager("XOR");
			}
			Roi.setName("selected RBCs");
			roiManager("Add");
			RBC=roiManager("select", (roiManager("count")-1));
			roiManager("Select", RBCs);
			roiManager("Delete");

			// save ROI set of current Image
			//saveRois("Open");
		}
		return true;
	} else {
		return false;
	}
}

function buildSettings() {
	names = newArray("Adipocyte Detection Parameters", "Min Size", "Max Size", "Min Circularity", "Steps with user interaction", "Select Artifact Regions", "Test Particle Analysis Parameters");
	types = newArray("m", "n","n","n","m", "c", "c");
	defaults = newArray("",0,1000000,0,"", true, false);

	promptParameters(names, types, defaults);

}

</codeLibrary>

//******* Select Working Folder
<line>
<button>
label=Select Working Folder
arg=<macro>
	setImageFolder("Select the folder where your images are located");
</macro>
</line>

//********* Select Image
<line>
<button>
label=Select Image
arg=<macro>
	selectImageDialog();
</macro>
</line>
<line>
<button>
label=Set Parameters
arg=<macro>
	buildSettings();
</macro>

</line>
<line>
<button>
label=Draw ROIs
arg=<macro>
	preprocessDrawRois();
</macro>
<button>
label=Batch Draw ROIs
arg=<macro>
	nI = getNumberImages();
	for (i=0; i<nI; i++) {
		roiManager("reset");
		openImage(i);
		preprocessDrawRois();
		close();
	}

</macro>
</line>

<line>
//******* Test Red Cells Analysis
<button>
label=Test Hematopoietic Cells Analysis
arg=<macro>
	ori= getImageID();
	boneRoi = findRoiWithName("Bone");
	
	if (boneRoi != -1) {
		roiManager("Select", boneRoi);
		roiManager("Delete");
	}
	
	if (findRoiWithName("Bone Within TB") != -1) {
		roiManager("Select", findRoiWithName("Bone Within TB"));
		roiManager("Delete");
	}
	if (findRoiWithName("TB-Bone") != -1) {
		roiManager("Select", findRoiWithName("TB-Bone"));
		roiManager("Delete");
	}
	
	bone=getTheBone(ori);
	close(bone);
	totalAreaHematopCells = processRedCells(ori);
</macro>

//***** Test Adipocyte Analysis
<button>
label=Test Adipocyte Analysis
arg=<macro>
	ori=getImageID();
	name=getTitle();
	if (roiManager("count") != 0) {
		roiManager("reset");
		// If the ROI set exists, reopen it
		openRoiSet(name);
	}
	
	if (findRoiWithName("Artifact*") != -1) { //if at least one artifact region has been drawn
		mergeArtifacts();
	}
	
	bone=getTheBone(ori);
	close(bone);
	nomNdenom=processAdipocytes(ori);
	areaAdip=nomNdenom[0];
	denominator=nomNdenom[1];
	run("Table...", "name=Results_Window");
	print("[Results_Window]","Cellularity 2: "+(1-areaAdip/denominator)*100);
</macro>
</line>

//***** Process Current Image
<line>
<button>
label=Process Current Image
arg=<macro>
	ori = getImageID();
	name=getTitle();
	cellularities=processImage(ori);
	saveCurrentImage();
	saveRois("Save");
	/*
	selectWindow("HematoCells");
	run("Convert to Mask");
	selectWindow("Adip");
	run("Convert to Mask");
	run("Merge Channels...", "c5=Adip c6=HematoCells create keep");
	*/
	prepareTable("Results_Window");
	run("Clear Results");
	setResult("Image Name", 0, name);
	setResult("Cellularity 1", 0, cellularities[0]);
	setResult("Cellularity 2", 0, cellularities[1]);
	closeTable("Results_Window");
	selectWindow("Results_Window");
</macro>
<button>
label=Batch Process
arg=<macro>
	batchProcessFolder();
</macro>
</line>

<line>
//******* Close all images except current one
<button>
label=Close All but Current
arg=<macro>
	close("\\Others");
</macro>
</line>
<line>
//******* Close all images except current one
<button>
label=Debug
arg=<macro>
	saveCurrentImage();
</macro>
</line>
