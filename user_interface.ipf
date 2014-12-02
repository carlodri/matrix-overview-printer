#pragma rtGlobals=3		// Use modern global access method.

// Author: Thomas Braun  (thomas <dot> braun <ähht> virtuall <minus> zuhause <doott> de)
// Version: see MFR_GetVersion; print V_XOPVersion
// License: LGPLv3 or later

// Purpose: This demo experiment shows the capabilities of the MatrixFileReader XOP

static StrConstant resultFileSuffix = ".mtrx"
static StrConstant preferencesFolder = "root:Packages:MatrixFileReader:BasicGUI"

Constant debugMode = 1;

static Structure errorCode
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
EndStructure


static Function initStruct(errorCode)
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

static Function/DF createDFWithAllParents(dataFolder)
	string dataFolder

	variable i
	string partialPath="root"
	for(i=1; i < ItemsInList(dataFolder,":"); i+=1) // skip root, as this exists always
		partialPath += ":"
		partialPath += StringFromList(i,dataFolder,":")
		if(!DataFolderExists(partialPath))
			NewDataFolder/O $partialPath
		endif
	endfor
	
	return $dataFolder
end

Function BeforeFileOpenHook(refNum,fileName,path,type,creator,kind)
	Variable refNum,kind
	String fileName,path,type,creator
	
	Struct errorCode errorCode
	initStruct(errorCode)

	Fstatus refNum

	if(cmpstr(type,resultFileSuffix) == 0)
		
		MFR_OpenResultFile/K S_path + S_filename
	
		if( V_flag == errorCode.SUCCESS)
			updatePanel()
		else
			MFR_GetXOPErrorMessage
		endif
	endif
	
	return 1
End

Function execFunction (B_Struct) : ButtonControl
	STRUCT WMButtonAction &B_Struct
	
	Struct errorCode errorCode
	initStruct(errorCode)
	
	// Tell Igor not to invoke ButtonProc again until this invocation is finished
	B_Struct.blockReentry = 1
	
	if(B_Struct.eventCode == 2) // you want buttons to act on mouse up

		variable bricklets

		DFREF saveDFR = GetDataFolderDFR()
		createDFWithAllParents(preferencesFolder)
			
		SetDataFolder preferencesFolder
	
		NVAR brickletID, startBrickletID, endBrickletID, numBricklets
		SVAR resultFileName, resultFilePath, lastResultFileName, lastResultFilePath

		SetDataFolder saveDFR
	
		if( cmpstr(B_Struct.ctrlName,"createOverView") == 0 )

			MFR_createOverViewTable/KEYS="brickletID;scanCycleCount;runCycleCount;sequenceID;dimension;channelName;spatialInfo.originatorKnown"
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif

		elseif( cmpstr(B_Struct.ctrlName,"EditOverView") == 0 )
			wave/Z wv = overViewTable
			if(waveExists(wv))
				Edit/K=1 wv.ld
			else
				print "Overview wave does not exist"
			endif
					
		elseif(cmpstr(B_Struct.ctrlName,"allBrickletData") == 0)
		
			MFR_GetBrickletData
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif
			MFR_GetBrickletMetaData
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif

		elseif(cmpstr(B_Struct.ctrlName,"brickletData") == 0)

			MFR_GetBrickletData/R=(brickletID)
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif
			MFR_GetBrickletMetaData/R=(brickletID)
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif

		elseif(cmpstr(B_Struct.ctrlName,"brickletRawData") == 0)
	
			MFR_GetBrickletRawData/R=(brickletID)
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif
			MFR_GetBrickletMetaData/R=(brickletID)
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif

		elseif(cmpstr(B_Struct.ctrlName,"reportBug") == 0)
	
			NewNoteBook/F=0/N=reportBug as "Report a MatrixfileReader Bug"
			MFR_GetReportTemplate 
			Notebook reportBug, setData=S_value
			
		elseif(cmpstr(B_Struct.ctrlName,"checkforUpdate") == 0)
	
			MFR_checkForNewBricklets
			startBrickletID = V_startBrickletID
			endBrickletID = V_endBrickletID
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif

			MFR_GetBrickletCount
			numBricklets = V_count

		elseif(cmpstr(B_Struct.ctrlName,"getNewBrickletData") == 0)
	
			MFR_GetBrickletData/R=(startBrickletID,endBrickletID)
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif

			MFR_GetBrickletMetaData/R=(startBrickletID,endBrickletID)
			if(V_flag != errorCode.SUCCESS)
				MFR_GetXOPErrorMessage
			endif
		
		// print z topography data overview
		elseif(cmpstr(B_Struct.ctrlName,"printDataOverview")  == 0)
			
			if( numbricklets ==0 )
				DoAlert /T="Error" 0, "No result file has been opened."
			else
				PrintDataOverview(startBrickletID,endBrickletID)
			endif
		
		// kill all data-related data folders
		
		elseif(cmpstr(B_Struct	.ctrlName,"killAllDF") == 0)
			KillAllBrickletDataFolders()
		
		elseif(cmpstr(B_Struct.ctrlName,"openFile") == 0)
			variable refNum

			MFR_OpenResultFile
			if( V_flag == errorCode.SUCCESS )
				// prepare start and endBrickletID for printing overview of all data
				startBrickletID = 1
				MFR_GetBrickletCount
				endBrickletID = V_count
				updatePanel()
			else
				MFR_GetXOPErrorMessage
			endif
			
		elseif(cmpstr(B_Struct.ctrlName,"reOpenFile") == 0)
	
			MFR_OpenResultFile lastResultFilePath + "\\" + lastResultFileName
			if( V_flag == errorCode.SUCCESS )
				updatePanel()
			else
				MFR_GetXOPErrorMessage
			endif	
			
		elseif(cmpstr(B_Struct.ctrlName,"closeFile") == 0)
			MFR_CloseResultFile
			if( V_flag == errorCode.SUCCESS )
				lastResultFileName = resultFileName
				lastResultFilePath = resultFilePath
			else
				MFR_GetXOPErrorMessage
			endif
			resultFileName = ""
			resultFilePath = ""
			numBricklets=0
		endif

	endif
	
	return 0
End

Function updatePanel()

		DFREF prefDir = createDFWithAllParents(preferencesFolder)
	
		NVAR/SDFR=prefDir brickletID, startBrickletID, endBrickletID, numBricklets
		SVAR/SDFR=prefDir resultFileName, resultFilePath, lastResultFileName, lastResultFilePath

		MFR_GetResultFileName			
		resultFileName = S_fileName
		resultFilePath = S_dirPath
		
		variable localNumBricklets
		MFR_GetBrickletCount
		numBricklets = V_count
	
end

Function myPanel()

	string myPanel="MatrixFileReader"

	DoWindow/K $myPanel
	NewPanel/N=$myPanel  /W=(256,92,827,500)/K=1
	
	variable width=100, height=20, widthOffset=130, heightOffset=23
	variable widthZero=5, heightZero=5

	DFREF saveDFR = GetDataFolderDFR()
	createDFWithAllParents(preferencesFolder)
			
	SetDataFolder preferencesFolder
	
	variable/G brickletID,startBrickletID,endBrickletID, numBricklets
	string/G resultFileName,resultFilePath,lastResultFileName,lastResultFilePath
	
	SetDataFolder saveDFR
	
	variable/G V_MatrixFileReaderDouble=0, V_MatrixFileReaderDebug=0, V_MatrixFileReaderFolder=1, V_MatrixFileReaderOverwrite=1,V_MatrixFileReaderCache=1

	// information group
	variable infoBoxWidth=5.6*width,infoBoxHeight=4.5*heightOffset
	GroupBox infoBox,win=$myPanel, title="Information", size={infoBoxWidth,infoBoxHeight},pos={widthZero,heightZero}
	SetVariable filePath,noedit=1,win=$myPanel,title="Result file path",value=resultFilePath,size={5.5*width,height},pos={2*widthZero,heightZero+heightOffset},bodyWidth=4.5*width
	SetVariable fileName,noedit=1,win=$myPanel,title="Result file name",value=resultFileName,size={5.5*width,height},pos={2*widthZero,heightZero+2*heightOffset},bodyWidth=4.5*width
	SetVariable numBricklets,noedit=1,win=$myPanel,title="Total bricklet count",value=numBricklets,size={1.5*width,height},pos={2*widthZero,heightZero+3*heightOffset},limits={0,0,0},bodyWidth=50

	// all bricklets group
	variable allBrickletsBoxWidth=1.1*width, allBrickletsBoxHeight=4.5*heightOffset
	GroupBox allBrickletsBox,win=$myPanel,title="All Bricklets", size={allBrickletsBoxWidth,allBrickletsBoxHeight},pos={widthZero,2*heightZero+infoBoxHeight}
	Button allBrickletData,proc=execFunction,win=$myPanel,title="Get all data",size={width,height},pos={2*widthZero,3*heightZero+infoBoxHeight+1.8*heightOffset}

	// result file group
	variable resultFileBoxWidth=3*widthZero+4.3*width, resultFileBoxHeight=4.5*heightOffset
	width *=1.3
	widthOffset = width+10
	GroupBox resultFileBox,win=$myPanel,title="Result file", size={resultFileBoxWidth,resultFileBoxHeight},pos={2*widthZero+allBrickletsBoxWidth,2*heightZero+infoBoxHeight}
	Button openFile,proc=execFunction,win=$myPanel,title="Open",size={width,height},pos={3*widthZero+allBrickletsBoxWidth,2*heightZero+heightOffset+infoBoxHeight}
	Button reOpenFile,proc=execFunction,win=$myPanel,title="Reopen last file",size={width,height},pos={3*widthZero+allBrickletsBoxWidth+widthOffset,2*heightZero+heightOffset+infoBoxHeight}
	Button closeFile,proc=execFunction,win=$myPanel,title="Close",size={width,height},pos={3*widthZero+allBrickletsBoxWidth+2*widthOffset,2*heightZero+heightOffset+infoBoxHeight}
	Button checkforUpdate,proc=execFunction,win=$myPanel,title="Check for new bricklets",size={width,height},pos={3*widthZero+allBrickletsBoxWidth,2*heightZero+3*heightOffset+infoBoxHeight}
	Button createOverView,proc=execFunction,win=$myPanel,title="Create overview table",size={width,height},pos={3*widthZero+allBrickletsBoxWidth+widthOffset,2*heightZero+3*heightOffset+infoBoxHeight}
	Button editOverView,proc=execFunction,win=$myPanel,title="Edit overview table",size={width,height},pos={3*widthZero+allBrickletsBoxWidth+2*widthOffset,2*heightZero+3*heightOffset+infoBoxHeight}
	Button killAllDF,proc=execFunction,win=$myPanel,title="Kill all DF",size={width,height},pos={3*widthZero+allBrickletsBoxWidth+2*widthOffset,2*heightZero+2*heightOffset+infoBoxHeight}

	// misc group
	width=100; widthOffset=width+30
	variable miscBoxWidth=allBrickletsBoxWidth, miscBoxHeight=7*heightOffset
	variable miscVertPos=3*heightZero+infoBoxHeight+allBrickletsBoxHeight,miscHorPos=widthZero
	variable bodyWidth = 30
	
	GroupBox miscBox,win=$myPanel,title="Settings", size={miscBoxWidth,miscBoxHeight},pos={miscHorPos,miscVertPos}
	SetVariable DPWaves,noedit=1,win=$myPanel,title="Use FP64",value=V_MatrixFileReaderDouble,size={width,height},pos={miscHorPos+widthZero,miscVertPos+heightOffset},limits={0,1,1},bodyWidth=bodyWidth
	SetVariable sepFolders,noedit=1,win=$myPanel,title="Use Folders",value=V_MatrixFileReaderFolder,size={width,height},pos={miscHorPos+widthZero,miscVertPos+2*heightOffset},limits={0,1,1},bodyWidth=bodyWidth
	SetVariable enableDebug,noedit=1,win=$myPanel,title="Enable debug",value=V_MatrixFileReaderDebug,size={width,height},pos={miscHorPos+widthZero,miscVertPos+3*heightOffset},limits={0,1,1},bodyWidth=bodyWidth
	SetVariable overwriteWaves,noedit=1,win=$myPanel,title="Overwrite Wvs",value=V_MatrixFileReaderOverwrite,size={width,height},pos={miscHorPos+widthZero,miscVertPos+4*heightOffset},limits={0,1,1},bodyWidth=bodyWidth
	SetVariable cacheData,noedit=1,win=$myPanel,title="Cache Data",value=V_MatrixFileReaderCache,size={width,height},pos={miscHorPos+widthZero,miscVertPos+5*heightOffset},limits={0,1,1},bodyWidth=bodyWidth
	Button reportBug,proc=execFunction,win=$myPanel,title="Report bug",size={width,height},pos={miscHorPos+widthZero,miscVertPos+6*heightOffset}

	// one bricklet group
	variable oneBrickletBoxWidth=2*width, oneBrickletBoxHeight=7*heightOffset
	variable oneBrickletVertPos=miscVertPos,oneBrickletHorPos=2*widthZero+miscBoxWidth
	
	GroupBox oneBrickletBox,win=$myPanel,title="Actions for one Bricklet", size={oneBrickletBoxWidth,oneBrickletBoxHeight},pos={oneBrickletHorPos,oneBrickletVertPos}
	SetVariable brickletID,win=$myPanel,title="Bricklet ID",value=brickletID,size={width,height},pos={oneBrickletHorPos+0.5*width,oneBrickletVertPos+heightOffset}
	Button brickletData,proc=execFunction,win=$myPanel,title="Get data",size={width,height},pos={oneBrickletHorPos+0.5*width,oneBrickletVertPos+2*heightOffset}
	Button brickletRawData,proc=execFunction,win=$myPanel,title="Get raw data",size={width,height},pos={oneBrickletHorPos+0.5*width,oneBrickletVertPos+3*heightOffset}

	// range bricklet group
	width=120; widthOffset = width+30
	variable rangeBrickletBoxWidth=2*width, rangeBrickletBoxHeight=7*heightOffset
	variable rangeBrickletVertPos=oneBrickletVertPos,rangeBrickletHorPos=oneBrickletHorPos+oneBrickletBoxWidth+widthZero
	
	GroupBox rangeBrickletBox,win=$myPanel,title="Actions for a series of Bricklets", size={rangeBrickletBoxWidth,rangeBrickletBoxHeight},pos={rangeBrickletHorPos,rangeBrickletVertPos}
	SetVariable startBrickletID,win=$myPanel,title="Start Bricklet ID",value=startBrickletID,size={width,height},pos={rangeBrickletHorPos+0.5*width,rangeBrickletVertPos+heightOffset}
	SetVariable endBrickletID,win=$myPanel,title="End Bricklet ID",value=endBrickletID,size={width,height},pos={rangeBrickletHorPos+0.5*width,rangeBrickletVertPos+2*heightOffset}
	Button getNewBrickletData,proc=execFunction,win=$myPanel,title="Get new data",size={width,height},pos={rangeBrickletHorPos+0.5*width,rangeBrickletVertPos+3*heightOffset}
	Button printDataOverview,proc=execFunction,win=$myPanel,title="Print z-topo overview",size={width,height},pos={rangeBrickletHorPos+0.5*width,rangeBrickletVertPos+4*heightOffset}
	
	
	variable impressumHorPos = widthZero, impressumVerPos=miscVertPos+miscBoxHeight+heightZero
	DrawPict/W=$myPanel impressumHorPos,impressumVerPos, 0.02, 0.02, procGlobal#copyLeftPict
	TitleBox tb1,title="Thomas Braun (thomas dot braun ähht virtuell minus zuhause doott de)",pos={impressumHorPos+20,impressumVerPos},frame=0

End


// PNG: width= 1055, height= 1055
Picture copyLeftPict
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"9!!!"9#R18/!3>n`<WE+""EQn$<!Wa8#^cngL]@DT$#iF<ErZ1@M?!
	VWM?,N"0N\;T!#]lI=EIJ[Aor6*Eb,5pGBYZRDJO<'@;od1DfTK[mQ;Bf!".j[6pXdsSF)ksN)`pka
	$8a0#qW[rW)[e0Ti>;U9oQ?6\?T^W25D/t>Nn?rr7)XR.&AZp&#I:e5EZjXN(L"rCi!iidUE>W;^2a
	6BH%]U%hgP,.Kktf9%Cd2nmdC6+*4#YQFH>=R="A6pVND1o)<ptbaeLcHgWn8B'))A4]N]h>V@c2$j
	L#EoE0MmHc'b\Dul=--5/KBMucENO*g>ng,k1.jN7t$F)EW"!&+H_"3Y]rEtW^8fF&\ghI"Dk7PlS@
	B[4.W^o%a:*^nkTG0qT)1BbLcHLKa+U[1rZ)UP!qbCOdA;"k&t`G,OkIt<4XJG["R-OSEpaEq8B")E
	H4J?Jqp!S/$(ZN@r]6D!22J["W0@-EmW%9`Mo/qMtkn8;XlV?IE2!pg&e947+R4<;GLjJDqe=nuo)p
	.Ign3)?+Qj6Wg'BZOrX9F2-]:-Jc]X!DAo<o?RVN*$3i!Oh-%gZ\MkkM/1-'\Eu)iu@5>if4of^ScU
	'#sJml!"0Ee#NGFq#es#Qf("%D&b#\;W4bZL]D@(GjR`"M#5/.gJRsu9>o*:k+8X;NmmB?i.Ao[D(#
	k133T.6Z0''-?R+HEnoNrHrlj@cCNai,m<@Z@G9o);&`W2p!l#dFh-VpD(N+YnI5>&R?aou0OiLg2]
	fFdY1r!>&Z"Ahh43#M:F29$X>T5RT"`<,B`@!0is[2A5pTP"ts$3:U('!j&P#-9Hr&EUFR#JII(h)n
	\@'jjD<DqIKd$d_m1#fcCY"oU)dYe^L%M\D#crFB+Y^-R;ko#T_uL%/8^0nEapTN-"Rg%Jj0JYbdS4
	#1bJ_mld+3<[RL'=?pX.(9TJ0&"B,!S8@3B=6!*\U]G0&hOGr"h#._fJ\;i/WA:jVprH'[*#Jfk5:b
	O7LChU&("MlE$O"qTrsLJFJ,JJfK%Og*!:(sqSsPs"/#;Dmo?eh7F&Fbi+'PMJbK/&"2>3E%BdZ1-M
	`]nPgu0aoEr0h+<,@!D#,Jt\+b?Wl+^+Y3SUgPma7q#i#ZD9q?:i[W)rqsr[%&Fi4V.aESHG`D/\*O
	$c,K?^$<3R)rQ2'-1'NI<r<3\o>#4*osQDHVJ$RQcq<LsK@%M(=sX4\"2DqaW(-\Gn5)O"]!6)WG+(
	Z`%LTTbmPfs+%n"XQp9tX8RJ\OR?R4QqU>LJsdj3):R4rKFgI3<23e5O"-dP3^QK4s"i+bVA-X)kgD
	A?hNLj";Q1(NZA8.9po5gA?l^tU(6\&BK%iCbko!,^fc=I(<IGW2oB0,gM:ps6`=)+!RTIl_O&'kg-
	S]lm67it^KIi(kX!VA5^,L,/n?hB;QIgjqp8CQfoJb:naaJ`A$V,V<@)5*?L;m6U$"VP!t5%0J>U3!
	4*"(gqJM%G[?P[+,AKbEIA(\=V9FUV5O]?RaaZl%d&[`jS=a@UP7<Y1qAafLtPa],m:V:VeQW7t2Fe
	&.[\`.f,.Hb%@gf&hKj3"2E9'H3>!43uTt+4@FXLTliPQ/8ibr/EcO3^l9i)9EU1kJ[SFTn/?qR?,U
	)!*Ws+dHj9?g1QH"-+Okah-]q?eR/Y9YA)+sFEKqGF)]OA%Jtdn((]m8@Vedo:r>t_b8gc9r!dKHEa
	W]OsJi3j>,kDDqJHj=ek;lMek=C!Bh]`p%3)]Pp>JMW!+7XMbe`RRL_Pi+L']9rb2[S3B;UGpX"htb
	f5_k2`E=(D)HmaMPWYgeMr!c7Y_b&4H<]%IJ1)U.\&,[ZI@9s"]@KAAS^IQE>Xh+pf^`[hE\jb<$8^
	L3\)X]O4pM`U;Sg!Y*AHNsFaJe,XN,gdG:a\RKHBlWi2COk;o^3PM5>T'-H9Rface".32_4"^Jh2[7
	NDp44kSH68=hV5a!89PWZd)6FQ`!(YHo3\IXWb=JZuk#KIo>fdOSt!C[ah_@qk"h^Wl[o&m8l)c0k-
	5i'(KV3V84d+TT/28!p&VEStV]&RfTY`,N()nQ9\(R!T,`@)^Be1pL"f#0V4TM[G#lo?Na]b[O[6Jp
	K*o,:E`"u=rMG,om#rO/)-%.&SGfkAIZb58P>@.XbsIrH.00#6RjKt8RpBO)S5C^.A\eb,k([7ihs/
	Fjs?si`ia_nd*=)*WA;/%ChEcCA(M3(9k_Dr/oT*_CP9r9%\6[lapM<Z%1-<89A3BCQ0D"Q]6>+GB^
	FGY6P?iV;GZVngbbg$mAeW"%;dqF]hh)%1t'eRV(u$tb;9I4BiSZpaVp=eQUg4=Vm:n4eH'N1]$K$3
	FDmUZ[pM.9cLh8]1,cUlVQoGt9drKjVlVYU6_?"@Ee8/u)JSP!;:";o9*7dtE6\mp+4dkfI"1&IXcg
	[KPB3l2I)4J5f*5kBkj1@]L"pL/Q7QrX&+DGD4-3&<?So4!dO&eN1&uZ[m5/uL$Mg<!cc7*kHPQ<hk
	N)KZPABP'R4:eGHiG2KRO\b+i!5sCFZ\gafWY-4lFg8k2kj)o)6\=rn4aQ_TKZ6YIV`[rVZG_fiEMK
	b3Tlu!VFE(=VacY/:O;K-lE=mXEK@fK^D&FAnK)_.b+bVMO6q`W[MD8(no')u&](JhKQ0(_q0RY,7k
	i;03jJV_n":\(1QP$[;OqanXI7F,47^k_,)`$p^j0hfr3UWYJpn]MCGR;V1\oVC":ZBZ/*HcNS;l23
	/jAGZFS;)"nNB@<*T\iOPa7AlU!b!fIF6,_X;P]p%0Nic&\/qWCC(!fEoD./)KjcZMEUDQrk]pV/ml
	ShctU+-A).=dV$)=Uipt[?$D"Z<$=,koe[0!tB&do5TaLo_ocC;V2<m=/+[oC3I2%NB.2ja5Pq&g=5
	t0?Y?@dQ_NlfhQ@2oCc<\5<EbA@B2f1*!E>qJ/E/PBCK:EZRmH%C,0eE%3m4#^R"FNs1WN6Y]bq<1l
	G>r)N2cE0k+A`nNCP=CtcrFrBN<1a!9&k[:a.VrpfEo'b4Pj@*2HD=3WI4&])Z?,p22-Z=Fp>(D-SU
	7N?FO,(rn]m-bfsn^SasRCt,D,J-3>aTDJ@?,le`[MtBB(##FNHKR(D/WfCe.::690WT)"`\C`Z8S!
	[#HoH9k=.@-$^C803a&P+?%YmjokLTkYF6OisTCb&u1'p#.f\.X3*nZ(>8_(5ah7Qd!oJcZO:("D]5
	4_\EM!KZnUuuZL-\@nR\Leo4F5DND9%N(Acc]ITNKg_Q^+[`[r4N=pbRdUW?B'-_3_-ET?$P'U#7gk
	OXK?E^><G5Z2.u_Je.CVH/!aGf37Ch0>1EFL.6W8Ieb\.k#e%Khd[<J6N8K.=i)ca_+0/XY1u6!Ot>
	S+OtL;;'he@j6XtFVKiP?J@>Z<3Jk.s/dkI1ECIJAV_k%m^`,N\Sl\tLNM-bLjZlIh2ajoZE`r/["e
	J[-#$M)@[HNf<MW,j;LokSS8)L4IaZ6gM=`'0A(CP="Wt?HlWs=dAEqakJ:DBl@5^>UfP&kLQ;Sc`D
	GS'aX2&;WKEXMLa;-RtH;0FE=-"okjcHQM65QDeD?3[AHSOA'<pAtT4pQoo^&WKBng.ZP4ocbp5_8%
	Q5T4_NhhXK9ZGh/dS\#7LbLth6/i,LEHVCFt5"6W&C)o2GN4TGH^!(fUS7'8jaJc
	ASCII85End
End