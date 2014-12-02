#pragma rtGlobals=3		// Use modern global access method.

// Author: Carlo Dri (dri@tasc.infm.it)
// Version: 0.8

static structure errorCode
	int32	SUCCESS 
	int32	UNKNOWN_ERROR
	int32	ALREADY_FILE_OPEN
	int32	EMPTY_RESULTFILE
	int32	FILE_NOT_READABLE
	int32	NO_NEW_BRICKLETS
	int32	WRONG_PARAMETER
	int32	INTERNAL_ERROR_CONVERTING_DATA
	int32	NO_FILE_OPEN
	int32	INVALID_RANGE
	int32	NON_EXISTENT_BRICKLET
	int32	WAVE_EXIST
endstructure



static function initStruct(errorCode)
	Struct errorCode &errorCode

	errorCode.SUCCESS =0
	errorCode.UNKNOWN_ERROR=10001
	errorCode.ALREADY_FILE_OPEN=10002
	errorCode.EMPTY_RESULTFILE=10004
	errorCode.FILE_NOT_READABLE=10008
	errorCode.NO_NEW_BRICKLETS=10016
	errorCode.WRONG_PARAMETER=10032
	errorCode.INTERNAL_ERROR_CONVERTING_DATA=10064
	errorCode.NO_FILE_OPEN=10128
	errorCode.INVALID_RANGE=10256  
	errorCode.NON_EXISTENT_BRICKLET=10512
	errorCode.WAVE_EXIST=11024
	
end


function/DF GetBrickletPath(brickletID)
	variable brickletID
	string brickletPath
	
	sprintf brickletPath, "root:X_%05d", brickletID
	// DFREF dfr = $dataFolderName
	return $brickletPath
end

function/S GetBrickletName(brickletID, direction) // direction 0 for Up and 1 for ReUp
	variable brickletID, direction
	string brickletName
	
	if(direction == 0)
		sprintf brickletName, "data_%05d_Up", brickletID
	elseif(direction == 1)
		sprintf brickletName, "data_%05d_ReUp", brickletID
	endif
	return brickletName
end


function KillAllBrickletDataFolders() // the implementation is a bit sick...
	string dataFolderName
	variable index = 1
	
	SetDataFolder("root:")
	CloseWinType(1)
	CloseWinType(3)
	CloseWinType(4)
	do
		dataFolderName = GetIndexedObjName("root:", 4, index)
		if(stringmatch(dataFolderName, "X_*") == 1)
			KillDataFolder /Z $dataFolderName
			index -= 1
		elseif(cmpstr(dataFolderName,"") == 0)
			break
		endif
		index += 1
	while(1)
end


function Is2DzBricklet(bricklet) //returns 0 if bricklet is a 2D Z image, 1 otherwise
	variable bricklet
	WAVE/T overViewTable
	
	if((cmpstr(overViewTable[bricklet-1][4],"2") == 0) && (cmpstr(overViewTable[bricklet-1][5],"Z") == 0))
		return 0
	else 
		return 1
	endif
end


function RowByRowBackground(brickletID, direction)
	variable brickletID, direction // 0 for x, 1 for y
	string fullPathToBricklet
	variable numLines, lineIndex = 0
	
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder GetBrickletPath(brickletID)
	
	wave wImage = $GetBrickletName(brickletID, direction)
	numLines = DimSize(wImage, direction) // get numRows or numCols depending on selected direction of line correction
	Make/O/N=3 w_coef={0.1,0.001,0.00001}
	variable NaNThreshold
	do
		duplicate/O/R=[][lineIndex,lineIndex] wImage $"wLine" // extract the line
		wave wLine // weird duplicate method is to avoid unwanted wave overwrites (see man page for duplicate)
		redimension/N=(-1,0) wLine // make it 1D
		WaveStats/M=1/Q wLine
		NaNThreshold = numpnts(wLine) - 3
		if ( V_numNans < NaNThreshold )
			curvefit/Q line wLine
			wImage[][lineIndex] -= w_coef[0]+w_coef[1]*x
		endif
		lineIndex += 1
	while(lineIndex < numLines)
	
	killwaves/Z V_avg, V_npnts, V_numInfs, V_numNaNs
	killwaves/Z w_coef, w_sigma, wLine // cleanup before leaving
	setdatafolder saveDFR
	
	return 0
end

function SetImageContrast(wImage, contrast) //contrast is in range 0...1 - acts on TOP graph!!
	WAVE wImage
	variable contrast
	variable normalization
	variable lowZ, highZ
	ImageHistogram wImage
	WAVE w_ImageHist
	Integrate/T w_ImageHist /D=w_HistInt
	normalization = WaveMax(w_HistInt)
	w_HistInt /= normalization
	FindLevel/EDGE=1/Q w_HistInt, (1 - contrast) / 2
	lowZ = V_LevelX
	FindLevel/EDGE=1/Q w_HistInt, 1 - ((1 - contrast) / 2)
	highZ = V_LevelX
	ModifyImage M_InterpolatedImage ctab= {lowZ,highZ,Grays,0}
end

function DisplayzImage(image)  // assumes you want to print the up-forward scan
	STRUCT image &image
	string upImageName
	string sSize, sBrickletID, sRunScan

	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder GetBrickletPath(image.brickletID)

	sprintf upImageName, "data_%05d_Up", image.brickletID
	ImageInterpolate /U=0.5 bilinear $upImageName
	WAVE M_InterpolatedImage
	Display;AppendImage M_InterpolatedImage
	
	SetImageContrast(M_InterpolatedImage, 0.94)
	
	ModifyGraph height={Plan,1,left,bottom}
	Label left "\\u#2"
	Label bottom "\\u#2"
	ModifyGraph fSize=7,btLen=2,stLen=1
	ModifyGraph minor=1,manTick=0
//	ModifyGraph manTick(left)={0,5,-9,0},manMinor(left)={4,50}
//	ModifyGraph manTick(bottom)={0,5,-9,0},manMinor(bottom)={4,50}
	ModifyGraph noLabel(bottom)=2
	ModifyGraph margin(bottom)=8,margin(left)=18,width=0
	ModifyGraph margin(top)=5,margin(right)=5,width=0
	ModifyGraph standoff=0
	ModifyGraph mirror=1
	ModifyGraph axThick=0.5

	sprintf sSize, "\\Z05 %5.1f ", image.size
	//TextBox/C/N=text0/A=LT/F=0/B=(0,0,0)/G=(65535,65535,65535)/X=0.00/Y=-2.85 sSize
	TextBox/C/N=text0/A=LT/F=0/B=1/X=0.00/Y=-3.125 sSize

	sBrickletID = "\\Z05 " + image.sBrickletID + " "
	TextBox/C/N=text1/A=MT/F=0/B=(0,0,0)/G=(65535,65535,65535)/X=0.00/Y=-2.9 sBrickletID

	sRunScan = "\\Z05 " + image.sRunScanCycle + " "
	TextBox/C/N=text2/F=0/B=(0,0,0)/G=(65535,65535,65535)/X=-0.00/Y=-2.9 sRunScan
	
	setdatafolder saveDFR
end


function CloseWinType(wintype)
	Variable wintype
	Variable windowIndex
	String toClose,listToClose
	
	listToClose=WinList("*", ";", "WIN:"+num2str(wintype))
	windowIndex=0		
	do
		toClose=StringFromList(windowIndex,listToClose)
		if (CmpStr("",toClose)==0)
			break
		else
			Execute "DoWindow/K "+toClose
		endif
		windowIndex += 1
	while (1)
end

static structure page
	variable width, height
	variable margin
	variable rows, columns
	variable imageHSpacing, imageVSpacing
	variable imageWidth
	variable vOffset, hOffset
	variable xParBox, yParBox
	variable xCommentBox, yCommentBox
	variable xExpNameBox, yExpNameBox
endstructure

static function InitPage(p)
	STRUCT page &p
	// prepare paramters for page layout
	p.margin = 10 // was 21
	p.width = 842
	p.height = 595
	p.rows = 3
	p.columns = 4
	// calculate relevant stuff
	p.imageWidth= (p.height - 2 * p.margin) / p.rows * 1.05 //empirical setting
	p.imageHSpacing = ((p.width - 2 * p.margin) / p.columns)
	p.imageVSpacing = ((p.height - 2 * p.margin) / p.rows) * 0.99
	p.vOffset = 9.5 // empirical
	p.hOffset = -1.7 // empirical
	
	p.xParBox = (2 * (p.columns - 1) - 1) * p.imageHSpacing / 2 - p.imageWidth / 2 + p.margin + p.hOffset
	p.yParBox = (2 * p.rows - 1) * p.imageVSpacing / 2  - p.imageWidth / 2 + p.margin + p.vOffset
	p.xParBox = (p.xParBox + 0.09 * p.imageWidth) / p.width * 100 //must be a percentage of plot area width
	p.yParBox = (p.yParBox + 0.05 * p.imageWidth) / p.height * 100
	
	p.xCommentBox = p.xParBox
	p.yCommentBox = p.yParBox + 0.95 * (p.imageWidth/p.width) * 100
	
	p.xExpNameBox = p.xParBox +  0.98 * (p.imageWidth/p.width) * 100
	p.yExpNameBox = p.yParBox + 1.17 * (p.imageWidth/p.width) * 100
end

static structure timeS
	variable	day
	variable	month
	variable	year
	variable	hour	
	variable	minutes
	variable	seconds
endstructure

function ExtractTimeOffset()
	WAVE/T resultFileMetaData = root:resultFileMetaData
	string sDateLastChange, sTimeStampLastChange
	variable year, month, day, hour, minute, seconds	
	variable igorTime, unixTime, timeDelta   //WARNING: unixTime is used with Igor convention i.e. from 1904!!!
		
	FindValue /TEXT="dateOfLastChange" resultFileMetaData
	sDateLastChange = resultFileMetaData[V_value][1]
	FindValue /TEXT="timeStampOfLastChange" resultFileMetaData
	sTimeStampLastChange =  resultFileMetaData[V_value][1]
	sscanf sDateLastChange, "%2d%*[/]%2d%*[/]%4d%*[ ]%2d%*[:]%2d%*[:]%2d" , month, day, year, hour, minute, seconds
	//print "Extracted:", day, month, year, "--", hour, minute, seconds
	unixTime = str2num(sTimeStampLastChange) + date2secs(1970, 1, 1)  //WARNING: unixTime is used with Igor convention i.e. from 1904!!!
	igorTime = date2secs(year, month, day) + 60 * 60 * hour + 60 * minute + seconds
	timeDelta = unixTime - igorTime
	return timeDelta
end

function CreatePrintLayout() // creates a layout with the proper settings for the printouts
	STRUCT page page
	InitPage(page)
	NewLayout /K=1 /P=Landscape
	PrintSettings margins={page.margin,page.margin,page.margin,page.margin}, orientation=1 // in future we want the layout to adapt to the printer margins
	TextBox/C/N=text0/F=0/A=LT/X=(page.xParBox)/Y=(page.yParBox) "\\Z08\\f01\\[0bID    \\[1run-scan    \\[2 V\\Bsmp\\M [V]      \\[3I\\Bt\\M [nA]        \\[4LG [%]    \\[5ang [°]   \\[6 sp [nm/s]     \\[7   offs [nm]       \\[8  time\\f00";DelayUpdate
end

function AppendExperimentData(brickletID)
	variable brickletID
	STRUCT page page
	STRUCT image image
	string sampleStr, dataSetNameStr, creationCommentStr, resultFileStr
	
	InitPage(page)
	InitImageParam(image)
	image.brickletID = brickletID
	GetImageParameters(image)
	
	sampleStr = "\\Z07\f01Sample:\f00 " + image.sSampleName
	TextBox/W=Layout0/C/N=text1/F=0/A=LT/X=(page.xCommentBox)/Y=(page.yCommentBox) sampleStr
	dataSetNameStr = "\\Z07\f01Data set:\f00 " + image.sDataSetName
	AppendText/W=Layout0/N=text1 dataSetNameStr
	creationCommentStr = "\\Z07\f01Comment:\f00 " + image.sCreationComment
	AppendText/W=Layout0/N=text1 creationCommentStr
	
	string year, month, day, hour, minute, seconds
	WAVE/T resultFileMetaData
	FindValue /TEXT="resultFileName" resultFileMetaData
	string sResultFile = resultFileMetaData[V_value][1]
	sscanf sResultFile, "%4s%2s%2s%*[-]%2s%2s%2s%*[.]", year, month, day, hour, minute, seconds
	resultFileStr = "\\Z20" + year + "-" + month + "-" + day + "  " + hour + ":" + minute + ":" + seconds
	//print resultFileStr
	TextBox/W=Layout0/C/N=text2/F=0/A=LT/X=(page.xExpNameBox)/Y=(page.yExpNameBox) resultFileStr
end

static structure image
	int16	brickletID
	string	sBrickletID
	int16	runCycle
	int16	scanCycle
	string 	sRunScanCycle
	double 	voltage
	string	sVoltage
	double 	current
	string	sCurrent
	double 	loopGain
	string	sLoopGain
	double 	offsetX
	string	sOffsetX
	double 	offsetY
	string	sOffsetY
	double	angle
	string	sAngle
	double	speed
	string	sSpeed
	double	acqTime
	string	sAcqTime
	double	size
	double	rasterTime
	double	numPoints
	string	sResultFileName
	string	sSampleName
	string	sDataSetName
	string	sCreationComment
endstructure

static function InitImageParam(im)
	STRUCT image &im
	// TODO: everything should be init to NaN for safety, except the brickletID
	im.runCycle = NaN
	im.scanCycle = NaN
	im.voltage = NaN
	im.current = NaN
	im.loopGain = NaN
	im.offsetX = NaN
	im.offsetY = NaN
	im.angle = NaN
	im.speed = NaN
	im.acqTime = NaN
	im.size = NaN
	im.rasterTime = NaN
	im.numPoints = NaN
end

static function GetImageParameters(image)
	STRUCT image &image
	string metaDataWave
	
	InitImageParam(image) // be sure that everything is NaN except image.brickletID
	
	sprintf metaDataWave, "metaData_%05d", image.brickletID
	DFREF saveDFR = GetDataFolderDFR()
	setdatafolder GetBrickletPath(image.brickletID)
	
	WAVE/T metaData = $metaDataWave
	
	sprintf image.sBrickletID "%3d", image.brickletID
	
	FindValue /TEXT="runCycleCount" metaData
	image.runCycle = str2num(metaData[V_value][1])
	
	FindValue /TEXT="scanCycleCount" metaData
	image.scanCycle = str2num(metaData[V_value][1])
	sprintf  image.sRunScanCycle, "%3d - %d",  image.runCycle, image.scanCycle
	//print image.sRunScanCycle
		
	FindValue /TEXT="GapVoltageControl.Voltage.value" metaData
	image.voltage = str2num(metaData[V_value][1]) 
	sprintf image.sVoltage, "%+7.3f" , image.voltage
	//print image.sVoltage
	
	FindValue /TEXT="Regulator.Setpoint_1.value" metaData
	image.current = str2num(metaData[V_value][1])  * 1e9 // convert A to nA
	sprintf image.sCurrent, "%8.3f" , image.current
	//print image.sCurrent
	
	FindValue /TEXT="Regulator.Loop_Gain_1_I.value" metaData
	image.loopGain = str2num(metaData[V_value][1])
	sprintf image.sLoopGain, "%6.2f" , image.loopGain
	//print image.sLoopGain
	
	FindValue /TEXT="XYScanner.Angle.value" metaData
	image.angle = str2num(metaData[V_value][1]) 
	sprintf image.sAngle, "%3d" , image.angle
	//print image.sAngle
	
	FindValue /TEXT="XYScanner.X_Offset.value" metaData
	image.offsetX = str2num(metaData[V_value][1]) *1e9 // convert m to nm
	sprintf image.sOffsetX, "%+9.3f" , image.offsetX
	
	FindValue /TEXT="XYScanner.Y_Offset.value" metaData
	image.offsetY = str2num(metaData[V_value][1]) *1e9 // convert m to nm
	sprintf image.sOffsetY, "%+9.3f" , image.offsetY
	
	FindValue /TEXT="XYScanner.Width.value" metaData
	image.size = str2num(metaData[V_value][1])  * 1e9
	FindValue /TEXT="XYScanner.Raster_Time.value" metaData
	image.rasterTime = str2num(metaData[V_value][1]) 
	FindValue /TEXT="XYScanner.Points.value" metaData
	image.numPoints = str2num(metaData[V_value][1]) 
	image.speed = image.size / (image.rasterTime * image.numPoints) // should be ok, but to be checked
	sprintf  image.sSpeed "%7.2f", image.speed
	//print image.sSpeed
	
	FindValue /TEXT="creationTimeStamp" metaData
	image.acqTime = str2num(metaData[V_value][1]) 
	//print "Offset: ", ExtractTimeOffset()
	image.acqTime -= ExtractTimeOffset()
	image.sAcqTime = secs2time(image.acqTime + date2secs(1970,1,1), 3)
	//print image.sAcqTime, secs2date(image.acqTime + date2secs(1970,1,1), 3)
	
	killwaves/Z V_value, V_startPos // cleanup before leaving
	
	FindValue /TEXT="sampleName" metaData
	image.sSampleName = metaData[V_value][1]
	
	FindValue /TEXT="dataSetName" metaData
	image.sDataSetName = metaData[V_value][1]
	
	FindValue /TEXT="creationComment" metaData
	image.sCreationComment = metaData[V_value][1]
	
	setdatafolder saveDFR
end

function AppendToTiledLayout(imageNumber)
	variable imageNumber // default for sharp is 22 in units of points, equals 0.75cm
	STRUCT page page
	InitPage(page)
	variable columnIndex
	variable rowIndex
	string graphName
	variable left, top, right, bottom
		 	
	//print imageNumber, ceil(imageNumber / columns), imageNumber - columns * (ceil(imageNumber / columns)-1)
	
	rowIndex = ceil(imageNumber / page.columns)
	columnIndex = imageNumber - page.columns * (ceil(imageNumber / page.columns)-1)
	
	left = (2 * columnIndex - 1) * page.imageHSpacing / 2 - page.imageWidth / 2 + page.margin + page.hOffset
	top = (2 * rowIndex - 1) * page.imageVSpacing / 2  - page.imageWidth / 2 + page.margin + page.vOffset
	right = (2 * columnIndex - 1) * page.imageHSpacing / 2  + page.imageWidth / 2 + page.margin + page.hOffset
	bottom = (2 * rowIndex - 1) * page.imageVSpacing / 2 + page.imageWidth / 2 + page.margin + page.vOffset
	//print left, top, right, bottom
	graphName = "Graph" + num2istr(imageNumber-1)
	AppendLayoutObject/R=(left, top, right, bottom)/F=0/T=1/W=Layout0 graph  $graphName
end

function AppendParameterText(image, underline)
	STRUCT image &image
	variable underline
	string textStr = ""
	
	textStr +=  "\\sa+02\\X0" + image.sBrickletID
	textStr += "  \\X1 " + image.sRunScanCycle
	textStr += " \\X2" + image.sVoltage
	textStr += " \\X3" + image.sCurrent
	textStr += " \\X4" + image.sLoopGain
	textStr += " \\X5   " + image.sAngle
	textStr += " \\X6    " + image.sSpeed
	textStr += " \\X7\Z06" + image.sOffsetX + ";" + image.sOffsetY + "\Z08"
	//textStr += " \\X7\\S     " + image.sOffsetX + "\\M\\B\\X7     " + image.sOffsetY + "\\M"
	//textStr += " \\X7\\y+15\\Z06     " + image.sOffsetX + "\\Z08\\y-30\\Z06\\X7     " + image.sOffsetY + "\\Z08\\y+15"
	//textStr += " \\X7  \\y+50\\Z05" + image.sOffsetX +"\\Z09\\y-50\\y-50\\Z05\\X7  " + image.sOffsetY +"\\Z09\\y+50"
	textStr += "\\X8" + image.sAcqTime
	textStr += selectstring(underline, "", "\\y-13\\L0401\\y+13") //underlines odd lines to enhance readability
	
	//AppendText /W=Layout0 /N=text0 "\\sa+04\\X0     000  \\X1 232-344 \\X2+10.234 \\X3333.999 \\X410.32 \\X5  234.5 \\X6    1234.32 \\X7  203.238 \\X823:32"
	AppendText /W=Layout0 /N=text0 textStr
	
	//print image.sBrickletID
end

function PrintDataOverview(startID, endID)
	variable startID, endID
	variable brickletID = startID
	variable imagePerSheet
	variable last2DZBricklet
	string graphName
		
	STRUCT errorCode errorCode //init structure for MFR error handling
	initStruct(errorCode)
	
	STRUCT image image
	
	// create overview table for all bricklets
	MFR_createOverViewTable/KEYS="brickletID;scanCycleCount;runCycleCount;sequenceID;dimension;channelName;spatialInfo.originatorKnown"
	if(V_flag != errorCode.SUCCESS)
		MFR_GetXOPErrorMessage
	endif
	MFR_GetResultFileMetaData
	if(V_flag != errorCode.SUCCESS)
		MFR_GetXOPErrorMessage
	endif	
	// Ok, this is a bad design thing: we should NOT load all the bricklets because we can easily suck up all the available
	// memory. Here's what we can do to slim things:
	// - createOverViewTable BEFORE loading anything
	// - while we iterate, we check if the bricklet is z AND 2D
	// - in case, we open it
	// - we clean up the loaded bricklets after each sequence of 10 (i.e. 1 page of layout)
	
	do  //cycle on sheets of layout
		CreatePrintLayout() // create a layout
		
		imagePerSheet = 1
		do // cycle on bricklets
			 if(Is2DzBricklet(brickletID) == 0)
				last2DZBricklet = brickletID
				MFR_GetBrickletData/R=(brickletID)
				if(V_flag != errorCode.SUCCESS)
					MFR_GetXOPErrorMessage
				endif
				MFR_GetBrickletMetaData/R=(brickletID)
				if(V_flag != errorCode.SUCCESS)
					MFR_GetXOPErrorMessage
				endif
				image.brickletID = brickletID
				GetImageParameters(image)
				RowByRowBackground(brickletID, 0) // remove background
				DisplayzImage(image) 
				AppendToTiledLayout(imagePerSheet) //use 22pt as margin, should be ok for sharp printer. to be geralized one day...
//				append parameters to a textbox
				AppendParameterText(image, mod(imagePerSheet, 2))
				imagePerSheet += 1
			endif
			brickletID += 1
		while((imagePerSheet <= 10) && (brickletID <= endID))
		AppendExperimentData(last2DZBricklet)
		//PrintLayout Layout0
		
		//string fileNameStr
		//fileNameStr = "Layout-bID" + num2str(brickletID) + ".pdf"
		//SavePICT/WIN=Layout0/B=1/C=0/EF=0/E=-8 as fileNameStr
		
		//KillAllBrickletDataFolders()
		
//		This is the "emergency" manual image placement		
//		AppendLayoutObject/R=(34,32,221,219)/F=0/T=1/W=Layout0 graph Graph0
//		AppendLayoutObject/R=(229,32,416,219)/F=0/T=1/W=Layout0 graph Graph1
//		AppendLayoutObject/R=(424,32,611,219)/F=0/T=1/W=Layout0 graph Graph2
//		AppendLayoutObject/R=(619,32,806,219)/F=0/T=1/W=Layout0 graph Graph3
//		AppendLayoutObject/R=(34,212,221,399)/F=0/T=1/W=Layout0 graph Graph4
//		AppendLayoutObject/R=(229,212,416,399)/F=0/T=1/W=Layout0 graph Graph5
//		AppendLayoutObject/R=(424,212,611,399)/F=0/T=1/W=Layout0 graph Graph6
//		AppendLayoutObject/R=(619,212,806,399)/F=0/T=1/W=Layout0 graph Graph7
//		AppendLayoutObject/R=(34,392,221,579)/F=0/T=1/W=Layout0 graph Graph8
//		AppendLayoutObject/R=(229,392,416,579)/F=0/T=1/W=Layout0 graph Graph9
//		print brickletID, imagePerSheet
//		Execute /Q "Tile/A=(3,4)/O=1" // cheap and shitty solution...

	while(brickletID < endID)

	
	return 0
end