///////////////////////////////////////////////////////////////////////////
//   
//

function LoadRules( template ) export
	recRule = new structure("Delimeter,FirstSection,Sections,FormatDate","","",new map);
	
	//recRule.ver          = template.Area(2,2,,).Text;
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

//читаем реестр
//
//TODO: записываем платежки только после фиксации =
//      и определения сводной платежки от ПАО сбербанк 
function ReadReestr(reader, rules) export
	paramsPP = Константы.НастройкиИмпортаПП.Get().Get();
	
	aDocs = new array;
	//правила для поиска платежки 
	ruleFind = new array;
	ruleFind.Add(new structure("objProperty,XDTOProperty,IsFind","Номер","Номер",true));
	ruleFind.Add(new structure("objProperty,XDTOProperty,IsFind","Дата","Дата",true));
	
	aSimpleTypes = new array;
	aSimpleTypes.Add(type("number"));
	aSimpleTypes.Add(type("string"));
	aSimpleTypes.Add(type("date"));
	aSimpleTypes.Add(type("boolean"));
	
	node = Rules.Sections[ Rules.firstSection ];
	NameNode =  Rules.firstSection;
	AvailableNodes = new map;
	AvailableNodes.Insert( Rules.firstSection, Rules.Sections[ Rules.firstSection ]); 
	Delimeter = Rules.Delimeter;
	
	if paramsPP.UseRegExpPP then
		RegExp = new COMObject("VBScript.RegExp");// создаем объект для работы с регулярными выражениями
		RegExp.MultiLine  = true;  // true — текст многострочный, false — одна строка
		RegExp.Global     = false; // true — поиск по всей строке, false — до первого совпадения
		RegExp.IgnoreCase = false; // true — игнорировать регистр строки при поиске
	endif;
	
	text = reader.ReadLine();
	//у формата Сбер нет префикса строки
	//  есть только маркер контрольной строки "=nn"
	//перфикса в [0] нету!!: aVals[idx] -> aVals[idx-1]
	While text<>undefined do
		
		aVals    = StrSplit( text, Delimeter, true);
		
		if Left(aVals[0], 1) = "=" then
			aVals[0] = Mid(aVals[0],2); 
			NameNode = "=";
		endif;
		nextNode = AvailableNodes[NameNode];
		 
		if nextNode <> undefined then
			node = nextNode;
			AvailableNodes = new map;
			if node.nextSection<>"" then
				AvailableNodes.Insert( node.nextSection, Rules.Sections[ node.nextSection ]); 
			endif;
			if node.extSection<>"" then
				AvailableNodes.Insert( node.extSection, Rules.Sections[ node.extSection ]); 
			endif;
			
			//разбор данных строки 
			//заполнение rowData значениями приведенными к нужным типам
			rowData = new structure;
			for idx = 0 to node.Params.Count()-1 do
				param = node.Params[idx];
				
				if param.role<>"" then   
					typeValue=type(param.typeName);
					if typeValue = type("date") then
						value = ПроцедурыОбменаXDTO.AssignToDate(aVals[idx], Rules.FormatDate); 
					else	
						value = ПроцедурыОбменаXDTO.AssignToType(aVals[idx], typeValue);
						if not ValueIsFilled(value) and aSimpleTypes.Find(typeValue)=undefined then
							value = aVals[idx];  //объект по коду не найден, вставим исходное значение, для обработчиков
						endif;	
					endif;
					rowData.insert(param.role, value);
				endif;
			endDo;	
				
			//обработчики разбора rowData
			if node.Action = "NewPP" then
				
				docObject = undefined;
				//собираем синтетический номер платежки
				rowData.insert("Номер", rowData.Номер1 + rowData.Номер2);
				
				refDoc = ПроцедурыОбменаXDTO.AssignToType( rowData, type("ДокументСсылка.ПлатежноеПоручение"), ,ruleFind);
				if not ValueIsFilled(refDoc) then
					docObject = Документы.ПлатежноеПоручение.СоздатьДокумент();
				else
					docObject = undefined; //refDoc.GetObject();
					message("ранее загружен:"+refDoc);
				endif;
				//eventNewPP(aDocs, docObject, rowData, paramsPP, RegExp);
			elsif node.Action = "UpdateKor" then
				
				eventUpdateKorr(aDocs, rowData, paramsPP, RegExp);
			endif;
			
			
			//обработчики после разбора
			if node.ActionAfter = "UpdatePP" then
				
				//применяем считанные данные строки
				if docObject <> undefined then
					FillPropertyValues(docObject, rowData);
				endif;
				
				eventUpdatePP(aDocs, docObject, rowData, paramsPP, RegExp);
				
			endif;

		else
			message("неожиданная секция файла:
			|предыдущая секция:"+node.Section);
			break;
		endif;
		 
		text = reader.ReadLine();
	endDo;
	
	return aDocs;
endfunction


//Event: создании новой платежки
procedure eventUpdatePP(aDocs, docObject, rowData, paramsPP, RegExp)
	
	if docObject <> undefined then
		//docObject.FillПлательщик(paramsPP.РазделительВПлательщик, paramsPP.ПозицияВПлательщик);
		
		//if paramsPP.UseRegExpPP then        
		//	docObject.FillRegExpНомера(RegExp, paramsPP.RegExpКвитанция, paramsPP.RegExpДело);  //, paramsPP.RegExpGroupКвитанция, paramsPP.RegExpGroupДело
		//else
		//	docObject.FillНомера(paramsPP.РазделительВНазначении, paramsPP.ИменаДело, paramsPP.ИменаКвитанции);
		//endif;
		
		//if paramsPP.ПризнакСводнойПлатежки<>"" then
		//	docObject.СводнаяПлатежка = Find(docObject.НазначениеПлатежа, paramsPP.ПризнакСводнойПлатежки)>0;
		//endif;	
		
		//docObject.Write();
		aDocs.Add(docObject);  // .Ref
	endif;

endprocedure

//Event: при чтении итоговой секции
//
procedure eventUpdateKorr(aDocs, rowData, paramsPP, RegExp)
	//правила для поиска суммовой платежки ПАО сбербанк
	ruleFindKorr = new array;
	ruleFindKorr.Add(new structure("objProperty,XDTOProperty,IsFind","Номер","НомерКорр",true));
	ruleFindKorr.Add(new structure("objProperty,XDTOProperty,IsFind","Дата","ДатаКорр",true));

	aDocs_ = aDocs;
	aDocs = new array;
	refDocKorr = ПроцедурыОбменаXDTO.AssignToType( rowData, type("ДокументСсылка.ПлатежноеПоручение"), ,ruleFindKorr);
	if ValueIsFilled(refDocKorr) then
		//TODO: обновим в загруженных платежках НомерСчетаКонтрагента
		//                                      БанкКонтрагента
		for each  docObject in  aDocs_  do
			if docObject<>undefined then
				docObject.НомерСчетаКонтрагента = refDocKorr.НомерСчетаКонтрагента;
				docObject.БанкКонтрагента       = refDocKorr.БанкКонтрагента;
				docObject.Основание             = refDocKorr;
				
				docObject.Write();
				aDocs.Add(docObject.Ref);
			endif;
		endDo;
	else
		message("необходимо сначала загрузить сводный платеж "+rowData.НомерКорр+" от " +rowData.ДатаКорр +" из ПАО Сбербанк");
	endif;
	

endprocedure
