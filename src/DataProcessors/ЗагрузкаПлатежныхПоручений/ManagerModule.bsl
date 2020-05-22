///////////////////////////////////////////////////////////////////////////
// design by GRish!                                         27/03/2019
//
//  загрузка платежных поручений
//
//
//

//список режимов работы загрузки
//
function GetModesOperate() export
	
	aModes = new array;
	aModes.Add("PP3");
	//aModes.Add("ExcelStandart");
	//aModes.Add("ExcelSber");
	
	return aModes;
	
endfunction

//Читает макет с правилами и строит управляющие структуры для чения Формата PP3
//
//Возвращаемое значение:
//	structure	-	{"Delimeter"   - string - разделитель,
//                    firstSection - string - имя первой секции
//                    Sections	- map["имя секции"] -> structure{"Section,nextSection,extSection,ActionBefore,ActionAfter,Params" }  
//                         Section - string - сигнальный признак секции
//                         nextSection- string - имя следующей секции
//                         extSection - string - имя доп. следующей секции
//                         ActionBefore - string - действие перед чтением строки
//                         Action       - string - действие после разбора строки
//                         ActionAfter  - string - действие после заполненич документа
//                         Params  - array {IdParameter,role,typeName}
//                               IdParameter
//                               role - заполняемое поле в документе, или структуре
//                               typeName
//
function LoadRules(template) export
	
	recRule = new structure("Delimeter,FirstSection,Sections,ver,FormatDate","","",new map);

	recRule.ver          = template.Area(2,2,,).Text;
	recRule.Delimeter    = template.Area(3,2,,).Text;
	recRule.FormatDate   = template.Area(4,2,,).Text;
	

	areaSections = template.Area("Sections");
	QBuilder = new QueryBuilder;
	QBuilder.DataSource = new DataSourceDescription(areaSections);
    QBuilder.Execute();
	curSections = QBuilder.Result.Select(); 
	
	areaParameters = template.Area("Parameters");
	QBuilderP = new QueryBuilder;
	QBuilderP.DataSource = new DataSourceDescription(areaParameters);
    QBuilderP.Execute();
	
	rFilter = new structure("Section");
	While curSections.Next() do
		if recRule.FirstSection = "" then
			recRule.FirstSection =  curSections.Section;
		endif;	
		rec = new structure("Params,Section,nextSection,extSection,ActionBefore,Action,ActionAfter",new array);
		FillPropertyValues(rec, curSections);
		recRule.Sections.Insert(curSections.Section, rec);
		
		rFilter.Section = curSections.Section;
		curParam = QBuilderP.Result.Select();
		While curParam.FindNext( rFilter ) do
			recP = new structure("IdParameter,role,typeName");
			FillPropertyValues(recP, curParam);
			rec.Params.Add(recP);
		endDo;	
	endDo;	
	
	return recRule;
endfunction	

//Читаем поток текстового файл
//  строим документы платежек
//
//
//
function ReadPP3(reader, Rules) export
	paramsPP = Константы.НастройкиИмпортаПП.Get().Get();
	//ВерсияФормата,РазделительВПлательщик,ПозицияВПлательщик,
	//UseRegExpPP,
	//            РазделителиВНазначении,ИмяДело,ИмяКвитанции,
	//            RegExpДело,RegExpGroupДело,RegExpКвитанция,RegExpGroupКвитанция
	
	aDocs = new array;
	ruleFind = new array;
	ruleFind.Add(new structure("objProperty,XDTOProperty,IsFind","Номер","Номер",true));
	ruleFind.Add(new structure("objProperty,XDTOProperty,IsFind","Дата","Дата",true));
	
	node = Rules.Sections[ Rules.firstSection ];
	AvailableNodes = new map;
	AvailableNodes.Insert( Rules.firstSection, Rules.Sections[ Rules.firstSection ]); 
	
	Delimeter = Rules.Delimeter;
	
	//контрольные и общие переменные
	controlData = new structure("DatePP,CountPP,ControlSum,curSumm,IsExt,ver",'00010101',0,0);
	docObject   = undefined;
	ActionEnd   = "";
	
	if paramsPP.UseRegExpPP then
		RegExp = new COMObject("VBScript.RegExp");// создаем объект для работы с регулярными выражениями
		RegExp.MultiLine  = true;  // true — текст многострочный, false — одна строка
		RegExp.Global     = false; // true — поиск по всей строке, false — до первого совпадения
		RegExp.IgnoreCase = false; // true — игнорировать регистр строки при поиске
	endif;	
	text = reader.ReadLine();
	While text<>undefined do
		
		aVals    = StrSplit( text, Delimeter, true); 
		nextNode = AvailableNodes[aVals[0]];
		
		if nextNode <> undefined then
			node = nextNode;
			AvailableNodes = new map;
			if node.nextSection<>"" then
				AvailableNodes.Insert( node.nextSection, Rules.Sections[ node.nextSection ]); 
			endif;
			if node.extSection<>"" then
				AvailableNodes.Insert( node.extSection, Rules.Sections[ node.extSection ]); 
			endif;
			//начнем разбор секции
			//обработчики перед началом разбора
			if node.ActionBefore = "NewPP" then
				eventNewPP(aDocs, docObject, paramsPP, RegExp);
				
				docObject = Документы.ПлатежноеПоручение.СоздатьДокумент();
			endif;
			//разбор данных строки
			rowData = new structure;
			for idx = 1 to node.Params.Count() do
				param = node.Params[idx-1];
				
				if param.role<>"" then
					if type(param.typeName) = type("date") then
						value = ПроцедурыОбменаXDTO.AssignToDate(aVals[idx], Rules.FormatDate); 
					else	
						value = ПроцедурыОбменаXDTO.AssignToType(aVals[idx], type(param.typeName));
					endif;
					rowData.insert(param.role, value);
				endif;
			endDo;	
			//обработчики разбора
			if node.Action = "NewPP" then
				ActionEnd = "NewPP";
				eventNewPP(aDocs, docObject, paramsPP, RegExp);

				refDoc = ПроцедурыОбменаXDTO.AssignToType( rowData, type("ДокументСсылка.ПлатежноеПоручение"), ,ruleFind);
				if not ValueIsFilled(refDoc) then
					docObject = Документы.ПлатежноеПоручение.СоздатьДокумент();
				else
					docObject = undefined; //refDoc.GetObject();
					message("ранее загружен:"+refDoc);
				endif;
			endif;
			//применяем считанные данные строки
			if docObject <> undefined then
				FillPropertyValues(docObject, rowData);
			endif;	
			
			//обработчики после разбора
			if node.ActionAfter = "fillCotrol" then
				FillPropertyValues(controlData, rowData);
			endif;
			
		else
			message("неожиданная секция файла: "+aVals[0]+"
			|предыдущая секция:"+node.Section);
			break;
		endif;
		
		text = reader.ReadLine();
	endDo;	
	
	if ActionEnd = "NewPP" then
		eventNewPP(aDocs, docObject, paramsPP, RegExp);
	endif;	
	
	return aDocs;
endfunction	

//////////////////////////////////////////////////////////////////////////////////
//  Обработчики событий при загрузке
//

//Event: заполнить контроль
procedure eventFillCotrol()
	
endprocedure

//Event: при создании новой платежки -> обработать предыдущую
procedure eventNewPP(aDocs, docObject, paramsPP, RegExp)
	
	if docObject <> undefined then
		docObject.FillПлательщик(paramsPP.РазделительВПлательщик, paramsPP.ПозицияВПлательщик);
		
		if paramsPP.UseRegExpPP then        
			docObject.FillRegExpНомера(RegExp, paramsPP.RegExpКвитанция, paramsPP.RegExpДело);  //, paramsPP.RegExpGroupКвитанция, paramsPP.RegExpGroupДело
		else
			docObject.FillНомера(paramsPP.РазделительВНазначении, paramsPP.ИменаДело, paramsPP.ИменаКвитанции);
		endif;
		
		if paramsPP.ПризнакСводнойПлатежки<>"" then
			docObject.СводныйПлатеж = Find(Upper(docObject.НазначениеПлатежа), Upper(paramsPP.ПризнакСводнойПлатежки) )>0;
		endif;	
		
		docObject.Write();
		aDocs.Add(docObject.Ref);
	endif;

endprocedure

