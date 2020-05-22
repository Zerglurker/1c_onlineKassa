///////////////////////////////////////////////////////////////////////////
// design by GRish!                                         16/04/2019
//
//  загрузка дел
//
//
//

//получить список доступных полей
//
function GetFieldNames() export
	list = new array;
	list.Add("Договор.Дата");                    //find
	list.Add("Договор.Номер");                   //find
	list.Add("Договор.id");
	//list.Add("Договор.Филиал");        //->
	//list.Add("Договор.Контрагент");    //->
	list.Add("Договор.Квитанции.НомерКвитанции");
	list.Add("Договор.Квитанции.Услуга");
	list.Add("Договор.Квитанции.ДатаУслуги");
	list.Add("Договор.Квитанции.Сумма");
	list.Add("Договор.Квитанции.СуммаНДС");
	
	list.Add("Договор.Филиал.Код");             //find
	list.Add("Договор.Филиал.Наименование");
	
	list.Add("Договор.Контрагент.Type");        //owner
	list.Add("Договор.Контрагент.Код");         //find
	list.Add("Договор.Контрагент.Наименование");
	list.Add("Договор.Контрагент.Адрес");
	list.Add("Договор.Контрагент.телефон");
	list.Add("Договор.Контрагент.емайл");
	
	return list;
endfunction	

//получим соотвествие столбцов и полей для заполнения
//  и проверим заполнение настройки
//параметры:
//   rowdata - array      - заголовки стобцов 
//   tbl	 - ValueTable - таблица соотвествий {IdParameter, nameField}
//
//
//Результат:
//  map,   [nameField] -> idx
//  undefined  - если не установлены соотвествия для всех потребных полей
function getMapFields(rowdata, tbl)
	map = new map;
	names = GetFieldNames();
	
	text = "незаполнены настройки для полей";
	isError = false;
	for each row in tbl do
		
		idx = rowdata.Find(row.IdParameter);  
		if idx<>undefined then
			map.Insert(row.nameField, idx);
		else
			text = text + "
			|"+row.nameField+" - ненайден сопоставленный столбец";
			isError = true;
		endif;
		
		i = names.Find(row.nameField);
		if i<>undefined then
			names.Delete(i);
		endif;
	endDo;
	
	if names.Count()>0 or isError then
		for each field in names do
			text = text + "
			|"+field+" - нет настройки сопоставления";
		endDo;	
		message(text);
		return undefined;
	endif;
	
	return map;
endfunction	

//Читаем поток текстового файл
//  строим документы платежек
//					
//  reader    -
//  Rules     - {Delimeter, Rules[]{
//					
//              }, maskDate}
//
function ReadCSV(reader, Rules) export
	aDocs = new array;
	
	docObject  = undefined;
	
	rulesДело = new array;                               
	rulesДело.Add(new structure("objProperty,XDTOProperty,IsFind","Дата","Дата",true));
	rulesДело.Add(new structure("objProperty,XDTOProperty,IsFind","Номер","Номер",true));
	
	typeDate  =type("date");
	typeString=type("string");
	typeNumber=type("number");
	
	isFirstRow = true;
	idsParams  = new array;
	mapFields  = new map;
	CountColumns = 0;
	text = reader.ReadLine();
	idxLine = 1;
	While text<>undefined do
		rowdata = СтроковыеФункцииКлиентСервер.РазложитьСтрокуВМассивПодстрок(text, Rules.Delimeter);
		if isFirstRow then
			idsParams = rowdata;
			CountColumns = rowdata.Count();
			
			if Rules.Rules.Count()=0 then
				OnlineCashboxСервер.SetIdColumsCSV(rowdata);
				message("Список доступных полей в CSV файле обновлен");
				break;
			endif;	
			
			mapFields = getMapFields(rowdata,Rules.Rules);
			if mapFields=undefined then
				break;
			endif;	
		else
			if CountColumns = rowdata.Count() then
				//чтение строки данных
				//mapParams = new map;
				//for idx=0 to rowdata.Count()-1 do			
				//endDo;
				recTemplateRow = new structure("Дата,Номер,id,Филиал,Контрагент,Квитанции",typeDate,typeString,typeNumber,
					new structure("Код,Наименование",typeNumber,typeString),
					new structure("Type,Код,Наименование,Адрес,телефон,емайл",type("СправочникСсылка.ЮрФиз"),typeString,typeString,typeString,typeString,typeString),
					new structure("НомерКвитанции,Услуга,ДатаУслуги,Сумма,СуммаНДС",typeNumber,typeString,typeDate,typeNumber,typeNumber));
					
				recДело = CreateRecRow(rowdata, mapFields, "Договор", recTemplateRow, Rules.maskDate);
				
				RefДоговор = ПроцедурыОбменаXDTO.AssignToType(recДело, type("ДокументСсылка.Договор"),,rulesДело);
				isNewDoc   = false;
				if ValueIsFilled(RefДоговор) then
					
					docObject = RefДоговор.GetObject();
					
					if aDocs.Find(RefДоговор)=undefined then
						docObject.Квитанции.Clear();
						isNewDoc = true;
					endif;	
					
				else		
					docObject = Документы.Договор.СоздатьДокумент();
					isNewDoc  = true;
				endif;
				
				FillPropertyValues(docObject, recДело,,"Филиал,Контрагент,Квитанции");
				docObject.Филиал     = GetСтруктураФилиалов(recДело.Филиал);
				docObject.Контрагент = GetКонтрагенты(recДело.Контрагент);
				if ValueIsFilled(recДело.Квитанции.НомерКвитанции) then
					rowКвитанция = docObject.Квитанции.Add();
					FillPropertyValues( rowКвитанция,  recДело.Квитанции);
				endif;
				
				docObject.Write();
				try
					docObject.Write(DocumentWriteMode.Posting);
				except
					message("ошибка при проведении:" + docObject.ref);
				endtry;
				
				if isNewDoc then
					aDocs.Add(docObject.ref);
				endif;
				//
			else
				message("нарушение целостности файла в строке "+ Format(idxLine,"ЧГ=0") + ": " + CountColumns+" заголовков <> " + rowdata.Count()+ " значений");
			endif;
		endif;
		
		isFirstRow = false;
		idxLine = idxLine + 1;
		text = reader.ReadLine();
	endDo;
	
	return aDocs;
endfunction	

////////////////////////////////////////////////////////////////////////////
//     Service procedures & functions
//

//переформатируем строку в иерархическую структуру пригодныю для простого заполнения объектов "на основании"
//
function CreateRecRow(rowdata, mapFields, prefix, recTemplate, maskDate)
	recResult = new structure;
	for each keyVal in recTemplate do
		if typeof(keyVal.Value)=type("structure") then
			value = CreateRecRow(rowdata, mapFields, prefix+"."+keyVal.key, keyVal.Value, maskDate);
		else
			value = rowdata[ mapFields[prefix+"."+keyVal.key] ];
			if keyVal.Value = type("date") then
				value = ПроцедурыОбменаXDTO.AssignToDate( value, maskDate);
			else	
				value = ПроцедурыОбменаXDTO.AssignToType( value, keyVal.Value);
			endif;
		endif;
		recResult.Insert( keyVal.key, value );
	endDo;
	
	return  recResult;
endfunction	

//Создадим экземпляр Контрагента
//
function GetКонтрагенты(recParams)
	//rules = new array;
	//rules.Add(new structure("objProperty,XDTOProperty,IsFind","Код","Код",true));
	//rules.Add(new structure("objProperty,XDTOProperty,IsFind","Owner","Type",true));
	
	Ref = ПроцедурыОбменаXDTO.AssignToType(recParams.Код, type("СправочникСсылка.Контрагенты"),recParams.Type,); //rules
	if  not ValueIsFilled(Ref) then
		obj = Справочники.Контрагенты.СоздатьЭлемент();
		FillPropertyValues(obj, recParams);
		obj.Owner = recParams.Type;
		
		obj.Write();
		Ref = obj.Ref;
	endif;	
	
	return Ref;	
	
endfunction	

//Создадим экземпляр Филиала
//
function GetСтруктураФилиалов(recParams)
	
	Ref = ПроцедурыОбменаXDTO.AssignToType(recParams.Код, type("СправочникСсылка.СтруктураФилиалов"));
	if not ValueIsFilled(Ref) then
		obj = Справочники.СтруктураФилиалов.СоздатьЭлемент();
		FillPropertyValues(obj, recParams);
		
		obj.Write();
		Ref = obj.Ref;
	endif;	
	
	return Ref;	
	
endfunction	



