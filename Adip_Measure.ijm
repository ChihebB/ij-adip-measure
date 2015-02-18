<<<<<<< HEAD

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

function setParametersDialog() {
	minParticles   = getDataD("Minimum Adipocyte Size [um]", 30);
	maxParticles   = getDataD("Maximum Adipocyte Size [um]", 3000);
	minCircularity = getDataD("Minimum Circularity", 0.2);

	Dialog.create(toolName() + "Parameters");

	Dialog.addNumber("Minimum Adipocyte Size [um]", minParticles);
	Dialog.addNumber("Maximum Adipocyte Size [um]", maxParticles);
	Dialog.addNumber("Minimum Circularity", minCircularity);

	Dialog.show();

	minParticles   = Dialog.getNumber();
	maxParticles   = Dialog.getNumber();
	minCircularity = Dialog.getNumber();

	setData("Minimum Adipocyte Size [um]", minParticles);
	setData("Maximum Adipocyte Size [um]", maxParticles);
	setData("Minimum Circularity", minCircularity);

	// To use, call getData(key)
	
}

function drawRois() {
	// Draw outline of interest
	setTool("polygon");
	waitForUser("Draw the tissue boundaries, then press OK.");
	Roi.setName("Tissue boundaries");
	roiManager("Add");
	
	// Draw as many Artifact Regions as needed

	// save ROI set of current Image
	saveRois("Open");

}
function processRedCells() {
	ori=getImageID();
	title=getTitle();
	getVoxelSize(Vx,Vy,Vz,Vu);
	bone="Bone";
	getTheBone(ori);
	Bone=lastRoi();
	//----
	close(bone+"-"+title);
	selectWindow(title);
	run("Colour Deconvolution", "vectors=[H&E DAB] hide");
	close(title+"-(Colour_2)");
	imageCalculator("Subtract", title+"-(Colour_3)", title+"-(Colour_1)");
	rename("HematoCells");
	close(title+"-(Colour_1)");
	
	selectWindow("HematoCells");
	roiManager("Select", (roiManager("count") - 1 ) );
	run("Enlarge...", "enlarge=1");
	run("Clear", "slice");
	selectWindow(title);
	setTool("polygon");
	waitForUser("Set the boundaries");
	//roiManager("Select",0);
	Roi.setName("Tissue Boundaries");
	roiManager("Add");
	selectWindow("HematoCells");
	//------
	TB=lastRoi();
	
	RoisManip(TB, Bone, "AND", "Bone Within TB");  //Bone inside TB; 
	BoneinTB=lastRoi();
	
	RoisManip(BoneinTB, TB, "XOR", "TB-Bone"); //TB without bone, and probably without RBCs
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
	//run("Options...", "iterations=1 count=2 black edm=Overwrite do=Close pad");
	roiManager("Select", (lastRoi()) );
	setAutoThreshold("Default dark");
	//setAutoThreshold("Huang dark");
	run("Set Measurements...", "area mean standard min median area_fraction limit display redirect=None decimal=3");
	run("Measure");
	selectWindow("Results");	
}

function processAdipocytes() {	
	//initBiopLib();
	ori = getImageID();
	title=getTitle();
	getVoxelSize(Vx,Vy,Vz,Vu);
	bone="Bone";
	getTheBone(ori);
	B=lastRoi(); //Bone
	//****
	//saveRois("Open");
	//****
	close(bone+"-"+title);
	
	//-----------------------------
	//Create the image which highlights the adipocytes and on which we are going to apply
	//the processing
	HSB="HSB-"+title;
	selectWindow(title);
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
	//****
	//saveRois("Open");
	//****
	
	run("Watershed");
	setAutoThreshold("Default dark");
	setVoxelSize(Vx,Vy,Vz,Vu);
	workingImage=getImageID();
//*****
	run("Create Selection");
	Roi.setName("All white");
	roiManager("Add");
	AllWhite=lastRoi();
//*****
	//Choisir la ROI
	setTool("freehand");
	waitForUser("Set the boundaries");
	Roi.setName("Tissue Boundaries");
	roiManager("Add");
	TB=lastRoi(); //Tissue Boundaries -TB
	
	//****
	//saveRois("Open");
	//****
//*****
	RoisManip(TB, AllWhite, "AND", "All White in TB");
	WhiteInTB=lastRoi();
//*****

	//get the enlarged bone inside TB
	RoisManip(TB,EnB, "AND", "Enlarged Bone Within TB");  //enlarged bone inside the tissue boundaries
	EnBinTB=lastRoi(); //Enlarged Bone inside TB -EnBinTB
	//****
	//saveRois("Open");
	//****
	//get the bone inside TB (unnecessary)
	RoisManip(TB, B, "AND", "Bone Within TB");
	BoneInTB=lastRoi(); //bone within the tissue boundaries
	//****
	//saveRois("Open");
	//****

	//** Not necessary **
	RoisManip(BoneInTB,TB, "XOR", "TB-Bone");
	TB_Bone=lastRoi();  //TB without bone
	//**
	
	//*******************
	RoisManip(EnBinTB,TB, "XOR", "TB - EnB");
	TB_EnB=lastRoi();  //TB without enlarged bone
	saveRois("Open");
	//roiManager("Select", TB_EnB );
	//*******************
	
	/*//---measure area of white space
	run("Set Measurements...", "area mean standard min median area_fraction limit display redirect=None decimal=3");
	run("Measure");*/
	//------
	toDelete=newArray(B, EnB, BoneInTB, EnBinTB, TB_Bone, AllWhite);
	roiManager("select", toDelete );
	roiManager("Delete");

	//Ask if there is some unwanted white space to be manually selected out
	drawWhite=drawWhiteSpace(ori);  //drawWhite = true if white space was selected, false otherwise
	if (drawWhite) {
		RoisManip(lastRoi()-1, lastRoi(), "XOR", "Area of Interest"); //lastRoi() is the unwanted white space, lastRoi()-1 is the TB without bone
		roiManager("Deselect");
		roiManager("select", (lastRoi()-1) ); //delete white space
		roiManager("Delete");
	}
	selectImage(workingImage);
	roiManager("Select", (lastRoi()) ); //TB without bone and without unwanted white space
	particlesNumber=ParticleAnalyze(ori, workingImage, roiManager("count")); //with this we get the Adipocytes

	AdipoParticles=newArray(particlesNumber);
	a=roiManager("count")-1;
	//roiManager("select", (a-234+1));
	for (i=a; i>=(a-particlesNumber+1); i--) {
		AdipoParticles[a-i]=i;
	}			
	roiManager("Select", AdipoParticles);
	roiManager("OR");
	Roi.setName("Adips");
	roiManager("Add");
	roiManager("Select", AdipoParticles);
	roiManager("Delete");
	Adips=lastRoi();
	AOI=lastRoi()-1; //area of interest
	TB_EnB=lastRoi()-2;
	WhiteInTB=lastRoi()-3;
	
	roiManager("select", (Adips));
	run("Enlarge...", "enlarge=1 pixel");
	Roi.setName("Enlarged Adips");
	roiManager("Add");
	EnAdips=lastRoi();

	RoisManip(WhiteInTB, Adips, "XOR", "unwanted white space");
	unwantedWS=lastRoi();
	RoisManip(unwantedWS, TB_EnB, "XOR", "True Area of Interest, without artifacts");
	denominator=lastRoi(); //call it denominator because the measure of this area will be in the denominator when calculating the cellularity
	selectImage(ori);
	//---measure area of the denominator
	roiManager("select", (denominator));
	run("Set Measurements...", "area mean standard min median area_fraction display redirect=None decimal=3");
	run("Measure");
	//---measure area enlarged adipocytes (nominator)
	roiManager("select", (EnAdips));
	run("Set Measurements...", "area mean standard min median area_fraction display redirect=None decimal=3");
	run("Measure");
	
}	

function ParticleAnalyze(ori, workingImage, limitNumber) {
	Satisfied=false;
	run("Analyze Particles...");
	selectImage(ori);
	roiManager("Show all without labels");
	Satisfied=getBoolean("Are you satisfied with these results?");
	
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
=======

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

function setParametersDialog() {
	minParticles   = getDataD("Minimum Adipocyte Size [um]", 30);
	maxParticles   = getDataD("Maximum Adipocyte Size [um]", 3000);
	minCircularity = getDataD("Minimum Circularity", 0.2);

	Dialog.create(toolName() + "Parameters");

	Dialog.addNumber("Minimum Adipocyte Size [um]", minParticles);
	Dialog.addNumber("Maximum Adipocyte Size [um]", maxParticles);
	Dialog.addNumber("Minimum Circularity", minCircularity);

	Dialog.show();

	minParticles   = Dialog.getNumber();
	maxParticles   = Dialog.getNumber();
	minCircularity = Dialog.getNumber();

	setData("Minimum Adipocyte Size [um]", minParticles);
	setData("Maximum Adipocyte Size [um]", maxParticles);
	setData("Minimum Circularity", minCircularity);

	// To use, call getData(key)
	
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
>>>>>>> FETCH_HEAD
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
	for (i=1; i>n; i++) {
		artifacts[i-1]=i;
	}
	
	roiManager("Select", artifacts);
	roiManager("XOR");
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
	drawRois("Artifacts");
	// save ROI set of current Image
	saveRois("Open");

}

function 

function processRedCells() {
	ori=getImageID();
	title=getTitle();
	getVoxelSize(Vx,Vy,Vz,Vu);
	bone="Bone";
	getTheBone(ori);
	Bone=lastRoi();
	//----
	close(bone+"-"+title);
	selectWindow(title);
	run("Colour Deconvolution", "vectors=[H&E DAB] hide");
	close(title+"-(Colour_2)");
	imageCalculator("Subtract", title+"-(Colour_3)", title+"-(Colour_1)");
	rename("HematoCells");
	close(title+"-(Colour_1)");
	
	selectWindow("HematoCells");
	roiManager("Select", (roiManager("count") - 1 ) );
	run("Enlarge...", "enlarge=1");
	run("Clear", "slice");
	selectWindow(title);
	setTool("polygon");
	waitForUser("Set the boundaries");
	Roi.setName("Tissue Boundaries");
	roiManager("Add");
	selectWindow("HematoCells");
	//------
	TB=lastRoi();
	
	RoisManip(TB, Bone, "AND", "Bone Within TB");  //Bone inside TB; 
	BoneinTB=lastRoi();
	
	RoisManip(BoneinTB, TB, "XOR", "TB-Bone"); //TB without bone, and probably without RBCs
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
	selectWindow("Results");	
}

function processAdipocytes() {	
	//initBiopLib();
	ori = getImageID();
	title=getTitle();
	getVoxelSize(Vx,Vy,Vz,Vu);
	bone="Bone";
	getTheBone(ori);
	B=lastRoi(); //Bone
	//****
	//saveRois("Open");
	//****
	close(bone+"-"+title);
	
	//-----------------------------
	//Create the image which highlights the adipocytes and on which we are going to apply
	//the processing
	HSB="HSB-"+title;
	selectWindow(title);
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
	//****
	//saveRois("Open");
	//****
	
	run("Watershed");
	setAutoThreshold("Default dark");
	setVoxelSize(Vx,Vy,Vz,Vu);
	workingImage=getImageID();
//*****
	run("Create Selection");
	Roi.setName("All white");
	roiManager("Add");
	AllWhite=lastRoi();
//*****
	//Choisir la ROI
	setTool("freehand");
	waitForUser("Set the boundaries");
	Roi.setName("Tissue Boundaries");
	roiManager("Add");
	TB=lastRoi(); //Tissue Boundaries -TB
	
	//****
	//saveRois("Open");
	//****
//*****
	RoisManip(TB, AllWhite, "AND", "All White in TB");
	WhiteInTB=lastRoi();
//*****

	//get the enlarged bone inside TB
	RoisManip(TB,EnB, "AND", "Enlarged Bone Within TB");  //enlarged bone inside the tissue boundaries
	EnBinTB=lastRoi(); //Enlarged Bone inside TB -EnBinTB
	//****
	//saveRois("Open");
	//****
	//get the bone inside TB (unnecessary)
	RoisManip(TB, B, "AND", "Bone Within TB");
	BoneInTB=lastRoi(); //bone within the tissue boundaries
	//****
	//saveRois("Open");
	//****

	//** Not necessary **
	RoisManip(BoneInTB,TB, "XOR", "TB-Bone");
	TB_Bone=lastRoi();  //TB without bone
	//**
	
	//*******************
	RoisManip(EnBinTB,TB, "XOR", "TB - EnB");
	TB_EnB=lastRoi();  //TB without enlarged bone
	saveRois("Open");
	//roiManager("Select", TB_EnB );
	//*******************
	
	/*//---measure area of white space
	run("Set Measurements...", "area mean standard min median area_fraction limit display redirect=None decimal=3");
	run("Measure");*/
	//------
	toDelete=newArray(B, EnB, BoneInTB, EnBinTB, TB_Bone, AllWhite);
	roiManager("select", toDelete );
	roiManager("Delete");

	//Ask if there is some unwanted white space to be manually selected out
	drawWhite=drawWhiteSpace(ori);  //drawWhite = true if white space was selected, false otherwise
	if (drawWhite) {
		RoisManip(lastRoi()-1, lastRoi(), "XOR", "Area of Interest"); //lastRoi() is the unwanted white space, lastRoi()-1 is the TB without bone
		roiManager("Deselect");
		roiManager("select", (lastRoi()-1) ); //delete white space
		roiManager("Delete");
	}
	selectImage(workingImage);
	roiManager("Select", (lastRoi()) ); //TB without bone and without unwanted white space
	particlesNumber=ParticleAnalyze(ori, workingImage, roiManager("count")); //with this we get the Adipocytes

	AdipoParticles=newArray(particlesNumber);
	a=roiManager("count")-1;
	//roiManager("select", (a-234+1));
	for (i=a; i>=(a-particlesNumber+1); i--) {
		AdipoParticles[a-i]=i;
	}			
	roiManager("Select", AdipoParticles);
	roiManager("OR");
	Roi.setName("Adips");
	roiManager("Add");
	roiManager("Select", AdipoParticles);
	roiManager("Delete");
	Adips=lastRoi();
	AOI=lastRoi()-1; //area of interest
	TB_EnB=lastRoi()-2;
	WhiteInTB=lastRoi()-3;
	
	roiManager("select", (Adips));
	run("Enlarge...", "enlarge=1 pixel");
	Roi.setName("Enlarged Adips");
	roiManager("Add");
	EnAdips=lastRoi();

	RoisManip(WhiteInTB, Adips, "XOR", "unwanted white space");
	unwantedWS=lastRoi();
	RoisManip(unwantedWS, TB_EnB, "XOR", "True Area of Interest, without artifacts");
	denominator=lastRoi(); //call it denominator because the measure of this area will be in the denominator when calculating the cellularity
	selectImage(ori);
	//---measure area of the denominator
	roiManager("select", (denominator));
	run("Set Measurements...", "area mean standard min median area_fraction display redirect=None decimal=3");
	run("Measure");
	//---measure area enlarged adipocytes (nominator)
	roiManager("select", (EnAdips));
	run("Set Measurements...", "area mean standard min median area_fraction display redirect=None decimal=3");
	run("Measure");
	
}	

function ParticleAnalyze(ori, workingImage, limitNumber) {
	Satisfied=false;
	run("Analyze Particles...");
	selectImage(ori);
	roiManager("Show all without labels");
	Satisfied=getBoolean("Are you satisfied with these results?");
	
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
		run("Analyze Particles...");
		selectImage(ori);
		roiManager("Show all without labels");
		Satisfied=getBoolean("Are you satisfied with these results?");
	}
	return roiManager("count")-limitNumber; //Particles Number
}

function batchProcessFolder() { 

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
	Roi.setName("-Bone");
	roiManager("Add");
	if (selectRBC(ori)) {
		RoisManip(lastRoi(),lastRoi()-1, "XOR", "bone without RBCs");
	}
}


function drawWhiteSpace(ori) {  //allows drawing white space and returns a boolean true when doing so
	draw=getBoolean("Do you want to draw big white regions?");
	managerCount=roiManager("count");
	if (draw) {
		setTool("free hand");
		selectImage(ori);
		waitForUser("Draw unwanted white spaces within tissue boundaries and press Add in the ROI Manager, then when finished press OK.");
		
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
			saveRois("Open");
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
			saveRois("Open");
		}
		return true;
	} else {
		return false;
	}
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
	
	//Close the image before going to the next one
	close();
}

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

//******* Select the bone inside TB

<line>
<button>
label=Select the bone inside TB
arg=<macro>
	ori=getImageID();
	getTheBone(ori);
</macro>


//******* Test Red Cells Analysis
<line>
<button>
label=Test Hematopoietic Cells Analysis
arg=<macro>
	//ori= getImageID();
	//getVoxelSize(Vx,Vy,Vz,Vu);
	processRedCells();
</macro>

//***** Test Adipocyte Analysis
<button>
label=Test Adipocyte Analysis
arg=<macro>
	processAdipocytes();
</macro>
</line>

//***** Process Current Image
<line>
<button>
label=Process Current Image
arg=<macro>
	ori = getImageID();
	processRedCells();
	selectImage(ori);
	waitForUser("Please press on the image outside the tissue boundaries, then press Ok.");
	processAdipocytes();
	selectWindow("HematoCells");
	run("Convert to Mask");
	selectWindow("Adip");
	run("Convert to Mask");
	run("Merge Channels...", "c5=Adip c6=HematoCells create keep");
</macro>
</line>
