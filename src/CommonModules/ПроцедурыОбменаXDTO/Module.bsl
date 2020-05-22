////////////////////////////////////////////////////////////////////////////////////////////
//                                                           Design by GRish!  14/06/2012
//
//  Процедуры кодирования пакетов данных на основе XDTO пакета : ExchangeCustomers
//
//  engine: coreXDTO

//Грузит указанные правила из шаблона
// параметры:
//   nameSection - string - имя секции
//   nameXDTO    - string - имя типа XDTO
//   namespace   - string - имя пространства имен
//   Template    - SpreadsheetDocument - макет с правилами
//
//  возвращает структуру правил
function LoadTransformation(nameSection="", nameXDTO="", namespace="", Template = undefined) export
	rTransformation = new structure("namespace,XDTOType,Rules",,,);
	
	if Template = undefined then
		message("nameSection:"+nameSection);
		message("nameXDTO:"+nameXDTO);
		message("namespace:"+namespace);
		raise "не инициализирован шаблон правил";
	endif;	
	
	transformationControl = template.Area("Transformations");
	QBuilder = new QueryBuilder;
	QBuilder.DataSource = new DataSourceDescription(transformationControl);
    QBuilder.Execute();
	curTransformation = QBuilder.Result.Select();  
	if nameSection<>"" then
		rFilter = new structure("имяПравила",nameSection);
	else
		rFilter = new structure("XDTOType",nameXDTO);
		if namespace<>"" then
			rFilter.Insert("namespace",namespace);
		endif;	
	endif;
	
	if curTransformation.FindNext( rFilter ) then
		
		FillPropertyValues(rTransformation, curTransformation);
		
		rangeControl = template.Area("Rules");
		QBuilderR = new QueryBuilder;
		QBuilderR.DataSource = new DataSourceDescription(rangeControl);
		QBuilderR.Execute();
		
		rTransformation.Rules = LoadRules(QBuilderR, curTransformation.имяПравила, curTransformation);
	endif;
	
	return rTransformation;
endfunction

// 
//
//GRish--  (+)getTypeXDTO  обработчик определения типа значения свойства, 
//         только для свойств неопределенного типа или объединений
function LoadRules(QBuilder ,nameRule, curTransformation)
	aRules  = new array;
	rFilter = new structure("имяПравила",nameRule);
	curRule = QBuilder.Result.Choose();  
	
	While curRule.FindNext( rFilter ) do
    	//чтений строк правила 
		rule=new structure("objProperty,XDTOProperty,Rules,getProperty,setProperty,getTypeXDTO,namespace,XDTOType,type");
		FillPropertyValues(rule, curRule);
		aRules.Add(rule);
		
		if ValueisFilled(curRule.Rule) then
			rule.Rules=LoadRules(QBuilder, curRule.Rule, curTransformation);
			//поиск в трансформациях, для поддержки нетипизированных свойств
			curTransformation.Reset();
			rFilterR = new structure("имяПравила",curRule.Rule);
			if curTransformation.FindNext(rFilterR) then
				rule.namespace = curTransformation.namespace;
				rule.XDTOType  = curTransformation.XDTOType;
			endif;	
		endif;	
	endDo;	
	
	return aRules;
endfunction	

//кодирует объект в XDTO
// Параметры:
//     obj       - Произвольный - источник данных, что угодно
//     Transformation - structure - правила трансформации объекта в XDTO
//                                  structure(namespace,XDTOType,Rules[](
//                                      structure(objProperty,XDTOProperty,Rules[]...,getProperty,setProperty,setType));
// Возвращаемое значение:
//     XDTOobject - созданный и заполненный объект
function Obj2XDTO(obj,Transformation, Factory=undefined) export
	if Factory=undefined then
		Factory = XDTOFactory;
	endif;	
	
	//получим объект
	objXDTO = GetObjectXDTO(Transformation.namespace,Transformation.XDTOType, Factory);
	                                                  //  XDTOFactory.Type("http://www.w3.org/2001/XMLSchema","string"), type("XDTOO...
	UpdateXDTO(obj,objXDTO,Transformation.Rules, Factory, type("XDTOObjectType"), new TypeDescription("string,number,boolean,date,binarydata"));	
	
	return objXDTO;
endfunction	

//TODO:читает объекты из XDTO
// Параметры:
//     objXDTO          - ОбъектXDTO - исходный объект XDTO
//     Transformation   - structure - правила трансформации объектаXDTO в нужный объект 
//                        structure(typename,   //имя типа: ссылки на объект, массив, структура, таблица значений
//                          Rules[] (
//                             structure(objProperty,XDTOProperty,    // obj[""] <- xdto[""]
//                                  IsFind,                      //это Поле поиска 
//                                  type|transformation(...),    //тип (если нет доступа к metadata) |правило для трансформации значения свойства
//                                  BeforeSet,AfterSet))         //обработчики событий при заполнении свойства
//						       BeforeSet,AfterSet,AfterWrite);      //обработчики событий при заполнении объекта
//
//                    
// Возвращаемое значение:
//    Объект    
function XDTO2Obj(objXDTO, Transformation) export
	//поищем существующий
	//
	objRef = AssignToType(objXDTO, type(Transformation.typename), ,Transformation.Rules);
	if not ValueIsFilled(objRef) then
		obj = undefined;
	else
		obj = objRef.GetObject();
	endif;
	//заполним
	//
	// и вернем
	return obj;
endfunction	

//Заполнение свойств XDTO объекта 
//  параметры:
//    obj      - исходный объект
//    objXDTO  - заполняемый объект XDTO
//    Rules    - массив правил заполнения
//    Factory  - Фабрика XDTO
//
//    typeXDTOObject = type("XDTOObjectType")
//    simpleTypes    = new TypeDescription("string,number,boolean,date,binarydata")
//
//GRish--  (+)getTypeXDTO   обработчик определения типа значения свойства, 
//         только для свойств неопределенного типа или объединений
function UpdateXDTO(obj,objXDTO,Rules, Factory, typeXDTOObject, simpleTypes)
	typeXDTO=objXDTO.Type();
	//typeName= "";
	Value   =undefined;

	//namespace = typeXDTO.namespaceURI;
	for each Rule in Rules do
		
		propertyXDTO=typeXDTO.Properties.get(Rule.XDTOProperty);
		//получим исходное значение
		if Rule.objProperty	= "[]" then
			Value=obj;
		elsif ValueIsFilled(Rule.objProperty) then
			Value=GetObjProperty(obj,Rule.objProperty);
		else 
			Value="";
		endif;
		//обработчик "getProperty"
		if ValueIsFilled(Rule.getProperty) then
			Value = RunGetProperty(obj, Rule.getProperty, Value);
		endif;
		
		typeProperty   = propertyXDTO.Type;
		if typeProperty.Name = "anyType" and Rule.XDTOType<>undefined then
			typeProperty  = Factory.Type(Rule.namespace, Rule.XDTOType);
		endif;
		
		//GRish--  (+)getTypeXDTO
		if ValueIsFilled(Rule.getTypeXDTO) then
			typeProperty  = RunGetTypeXDTO(Rule.getTypeXDTO, Value, typeProperty, Factory);
		endif;	
		
		//заполним свойство XDTO объекта
		if propertyXDTO.UpperBound=-1 or propertyXDTO.UpperBound>1 then
			//Ожидаеться входной объект iterator
			
			if TypeOf(Value) = type("QueryResultSelection") then
				//cursor
				While Value.Next() do                             // typeXDTOstring, F...
					rowXDTO = GetPropertyXDTO(Value,Rule,typeProperty, Factory, typeXDTOObject, simpleTypes);
					objXDTO[Rule.XDTOProperty].Add(rowXDTO);
					//обработчик "setProperty"
					if ValueIsFilled(Rule.setProperty) then
						RunSetProperty(Value, Rule.setProperty, objXDTO, rowXDTO, Factory);
					endif;
				endDo;	
			else
				//table value| table part
				for each row in Value do                          // typeXDTOstring, F...
					rowXDTO = GetPropertyXDTO(row,Rule,typeProperty, Factory, typeXDTOObject, simpleTypes);
					objXDTO[Rule.XDTOProperty].Add(rowXDTO);
					//обработчик "setProperty"
					if ValueIsFilled(Rule.setProperty) then
						RunSetProperty(row, Rule.setProperty, objXDTO, rowXDTO, Factory);
					endif;
				endDo;	
			endif;
		else
			//обычное свойство                                               // typeXDTOstring, F...
			objXDTO[Rule.XDTOProperty] = GetPropertyXDTO(Value,Rule,typeProperty,  Factory, typeXDTOObject, simpleTypes);
			//обработчик "setProperty"
			if ValueIsFilled(Rule.setProperty) then
				RunSetProperty(Value, Rule.setProperty, objXDTO, objXDTO[Rule.XDTOProperty], Factory);
			endif;
		endif;	
	endDo;
	
	return objXDTO;
endfunction	

//Получает значение XDTO на основе переданного значения
//  параметры:
//    value        - исходное значение
//    Rule         - правило заполнения 
//    typeProperty - тип генерируемого XDTO объекта/значения
//    Factory        - ФабрикаXDTO - Фабрика XDTO
//    typeXDTOObject - Type - type("XDTOObjectType")
//    simpleTypes    - TypeDescription - new TypeDescription("string,number,boolean,date")
//
function GetPropertyXDTO(obj, Rule, typeProperty, Factory, typeXDTOObject, simpleTypes)

	valueXDTO=undefined;

	if TypeOf(typeProperty) = typeXDTOObject then
		valueXDTO = GetObjectXDTO(, typeProperty, Factory);
		
		if Rule.Rules<>undefined then               //typeXDTOstring,
			UpdateXDTO(obj,valueXDTO,Rule.Rules, Factory,typeXDTOObject, simpleTypes);
		else
			//message(""+obj);
			//message("typeProperty.Name:"+typeProperty.Name);
			//message("Rule.objProperty:" +Rule.objProperty);
			try
				FillPropertyValues(valueXDTO, obj);
			except
				#if Client then
					info = ErrorInfo();
					sMessage ="XDTOproperty:"+Rule.XDTOProperty+"
					|OBJproperty:"+Rule.objProperty+"
					|value:"+obj+"
					|";
					While info<>undefined Do
						sMessage = sMessage +  info.Description + "
						|";
						
						info = info.Cause;
					endDo;	
					message(sMessage);
				#endif
			endtry;
			
		endif;	
	else
		try
			//для объектных свойств
			if Rule.Rules<>undefined then
				
				if Rule.Rules[0].objProperty	= "[]" then
					Value=obj;
				elsif ValueIsFilled(Rule.Rules[0].objProperty) then
					Value=GetObjProperty(obj,Rule.Rules[0].objProperty);
				else 
					Value="";
				endif;
				
				//обработчик "getProperty"
				if ValueIsFilled(Rule.Rules[0].getProperty) then
					Value = RunGetProperty(obj, Rule.Rules[0].getProperty, Value);
				endif;
			else
				//GRish --> вызов //обычное свойство obj = obj[nameProperty]
				Value=obj;
			endif;
			
			if simpleTypes.ContainsType(TypeOf(Value)) then
				valueXDTO = GetValueXDTO( ,typeProperty , Value, Factory);
			else
				valueXDTO = GetValueXDTO( ,typeProperty , String(Value), Factory);
			endif;	
		except
			#if Client then
				info = ErrorInfo();
				sMessage ="XDTOproperty:"+Rule.XDTOProperty+"
				|OBJproperty:"+Rule.objProperty+"
				|value:"+Value+"
				|";
				While info<>undefined Do
					sMessage = sMessage +  info.Description + "
					|";
					
					info = info.Cause;
				endDo;	
				message(sMessage);
			#endif
		endtry;	
		
	endif;
	
	return 	valueXDTO;
endfunction	

function RunGetProperty(obj, expression, Value)

	try 
		if Find(expression,";")>0 then
			execute (expression);
		else
			Value = Eval(expression);	
		endif;
		
		return Value;
	except
		message(ErrorDescription());
		message("-----------------------------------------");
		message(expression);
		return undefined;
	endtry
	
endfunction

function RunGetTypeXDTO( expression, Value, TypePropertyXDTO, Factory)

	try 
		if Find(expression,";")>0 then
			execute (expression);
		else
			TypePropertyXDTO = Eval(expression);	
		endif;
		
		return TypePropertyXDTO;
	except
		message(ErrorDescription());
		message("-----------------------------------------");
		message(expression);
		return undefined;
	endtry
	
endfunction

function RunSetProperty(source, expression, objXDTO, propertyXDTO, Factory)

	try 
		if Find(expression,";")>0 then
			execute (expression);
		else
			propertyXDTO = Eval(expression);	
		endif;
		
		return propertyXDTO;
	except
		message(ErrorDescription());
		message("-----------------------------------------");
		message(expression);
		return undefined;
	endtry
	
endfunction

//function SetXDTOProperty(Value, 
//ОписаниеТипов



////////////////////////////////////////////////////////
//  Сервисные процедуры и функции 
//


//получить значение свойства объекта (любой уровень вложенности)
//параметры:
//  obj   - объект 
//  name  - "property" | "property.property..." | "[]" = obj
//
function GetObjProperty(obj, name)
	iposComma=Find(name,".");
	if iposComma>0 then
		refobj=obj[Left(name,iposComma-1)];
		if ValueIsFilled(refobj) then
			
			return GetObjProperty(refobj,Mid(name,iposComma+1));
			
		endif;
	elsif name = "[]" then
		return obj;
	else
		return obj[name];
	endif;	
	
	return undefined;
endfunction

//разложить строку в массив параметров
//  string     - строка
//  delimeter  - разделитель (def=",")
//
function СтрокуВМассив(val string,delimeter=",") export
	a = new array;
	ipos =0;
	While StrLen(string)>0 do
		ipos = Find(string,delimeter);
		if ipos=0 then
			a.Add(string);
			string="";
		else
			a.Add(Left(string,ipos-1));
			string = mid(string,ipos+1, StrLen(string));
		endif;	
	endDo;	
	
	return a;
endfunction	

////////////////////////////////////////////////////////
//  Работа с XDTO
//

//получить тип XDTO
//
function GetTypeXDTO(namespace, typeName, Factory) export
	aTypeNames = СтрокуВМассив(typeName,".");
	typeXDTO = Factory.Type(namespace, aTypeNames[0]);
	
	aTypeNames.Delete(0);  //сдвинули элементы в массиве на -1
	if aTypeNames.Count()>0 then //
		if  typeOf(typeXDTO)= type("XDTOObjectType") then
			Collection = typeXDTO.Properties;
		else
			return undefined;
		endif;
	endif;	
	While aTypeNames.Count()>0 do
		if Collection = undefined then
			return undefined;
		endif;	
		Property = Collection.Get(aTypeNames[0]);
		if Property = undefined then
			return undefined;
		endif;
		typeXDTO = Property.Type;
		
		aTypeNames.Delete(0); //сдвинули элементы в массиве на -1
		if typeOf(typeXDTO)= type("XDTOObjectType") then
			Collection = typeXDTO.Properties;
		else
			Collection = undefined;
		endif;
	endDo;
	
	return typeXDTO;
endfunction

//получить пустой XDTO объект
//
function GetObjectXDTO(namespace, typeName, Factory=undefined) export
	if Factory=undefined then
		Factory = XDTOFactory;
	endif;	
	
	if TypeOf(typename)=type("string") then
		typeXDTO = GetTypeXDTO(namespace,typename, Factory);
	else
		typeXDTO = typename;
	endif; 
	if typeXDTO<>undefined then
		return Factory.Create(typeXDTO);
	endif;
	
	return undefined;
endfunction	

//получить приведенное значение типа XDTO
//   или пустое значение XDTO 
//
function GetValueXDTO(namespace,typeName,Value=undefined, Factory=undefined)
	if Factory=undefined then
		Factory=XDTOFactory;
	endif;	
	if TypeOf(typename)=type("string") then
		typeXDTO = GetTypeXDTO(namespace,typename, Factory);
	else
		typeXDTO = typeName;
	endif; 
	
	if typeXDTO<>undefined then
		return Factory.Create(typeXDTO,Value);
	endif;
	return undefined;
endfunction

Функция XMLДатаВремя(Значение)
	
	Если ЗначениеЗаполнено(Значение) Тогда
		Возврат Формат(Значение, "ДФ=yyyy-MM-dd'T'ЧЧ:мм:сс");
	КонецЕсли;	
	
	Возврат "0001-01-01T00:00:00";
		
КонецФункции // () 

Функция XMLДата(Значение)
	
	Если ЗначениеЗаполнено(Значение) Тогда
		Возврат Формат(Значение, "ДФ=yyyy-MM-dd");
	КонецЕсли;
	
	Возврат "0001-01-01";
		
КонецФункции // () 

////////////////////////////////////////////////////////
//  Работа с объектами
//

//Приведение данных к указанному типу
// Параметры:
//  Value  - ОбъектXDTO, ЗначениеXDTO - XDTO значение/Объект
//  type   - type        - тип выходного значения
//  Owner  - ЛюбаяСсылка - владелец, для подчиненных справочников (def=undefined)
//  Rules  - array,undefined - массив структур с правилами получения свойств для поиска. (def= empty)
//                             structure(objProperty,XDTOProperty,// obj[""] <- xdto[""]
//                                IsFind,                       //это Поле поиска 
//                                type|transformation(...),     //тип (если нет доступа к metadata) |правило для трансформации значения свойства
//                                BeforeSet,AfterSet));         //  обработчики событий при заполнении
//
// Возвращаемое значение:
//	Произвольный - приведенное значение 
function AssignToType(Value, type, Owner=undefined, Rules=undefined) export
	var obj;
	
	if  typeof(type)= type("String") then
	    type=type(type);
	endif;
	
	if TypeOf(Value)=type then
		return Value;
	endIf;
	
	try
		if type=type("boolean") then
			if ValueIsFilled(Value) then
				sss=Upper(TrimAll(Value));
				if sss="TRUE" or sss="ИСТИНА" or sss="ДА" or sss="T" then
					return true;
				elsif	sss="FALSE" or sss="ЛОЖЬ" or sss="НЕТ" or sss="F" then
					return false;
				endif;
				return undefined;
			else 
				return undefined;
			endif;
		elsif type=type("number") then
			if ValueIsFilled(Value) then
				return Number(TrimAll(Value));
			else
				return 0;
			endif;
		elsif type = type("string") then
			if ValueIsFilled(Value) then
				return string(Value);
			else 
				return "";
			endif;
		elsif type=type("Date") then
			return Date(Value);
		else 
			//определяем тип 
			metadataType=Metadata.FindByType(type);
			rFind = undefined;
			if Rules=undefined then
				sValue = string(Value);
			else
				rFind = new structure;
				for each Rule in Rules do
					if Rule.IsFind then
						rFind.Insert(Rule.objProperty , GetObjProperty(Value ,Rule.XDTOProperty));
					endif;	
				endDo;	
			endif;
			if Metadata.Enums.Contains(metadataType) then
				//ищем по имени
				Enum=Enums[metadataType.Name];
				if Enum<>undefined then
					return Enum[sValue];
				endif;	
			elsif	Metadata.Documents.Contains(metadataType) then
				//ищем по коду
				DocManager=Documents[metadataType.Name];
				if DocManager<>undefined then
					if rFind<>undefined then
						obj = FindObject(metadataType, rFind);
					else	
						obj=DocManager.FindByNumber(sValue);
					endif;
					return obj;
				endif;
			elsif	Metadata.ChartsOfAccounts.Contains(metadataType) then
				//ищем по коду и имени
				ChartsManager=Documents[metadataType.Name];
				if ChartsManager<>undefined then
					if rFind<>undefined then
						obj = FindObject(metadataType, rFind);
					else	
						
						obj=ChartsManager.FindByCode(sValue,Owner);
						if not ValueIsFilled(obj) then
							obj=ChartsManager.FindByDescription(sValue,true,Owner);
						endif;
					endif;
					return obj;
				endif;
			elsif	Metadata.Catalogs.Contains(metadataType) then
				//ищем по коду и имени
				CatManager=Catalogs[metadataType.Name];
				if CatManager<>undefined then
					if rFind<>undefined then
						obj = FindObject(metadataType, rFind, Owner);
					else	
						if not ValueIsFilled(obj) then
							obj=CatManager.FindByCode(sValue,false,,Owner);
						endif;
						if not ValueIsFilled(obj) then
							obj=CatManager.FindByDescription(sValue,true,,Owner);
						endif;
					endif;
					return obj;
				endif;
			endif;	
		endif;
			
		return Value;
	except
		message("Ошибка преобразования значения """+Value+""" к типу "+String(type));
		return undefined;
	endtry;
endfunction	

function FindObject(metadataType, rFind, Owner=undefined) 
	isDate=false;
		
	query = new query;
	Text = "SELECT 
	|t.ref AS REF
	|FROM ";
	
	if Metadata.Catalogs.Contains(metadataType) then
		Text = Text + "Catalog." + metadataType.Name;
		obj = Catalogs[metadataType.Name].emptyRef();
	elsif Metadata.ChartsOfAccounts.Contains(metadataType) then
		Text = Text + "ChartsOfAccount." + metadataType.Name;
		obj = ChartsOfAccounts[metadataType.Name].emptyRef();
	elsif Metadata.Documents.Contains(metadataType) then
		Text = Text + "Document." + metadataType.Name;
		obj = Documents[metadataType.Name].emptyRef();
		isDate=true;
	endif;
	Text=Text+" AS t   
	|WHERE ";
	docPeriodicity=Metadata.ObjectProperties.DocumentNumberPeriodicity;
	isNext = false;
	for each keyVal in	rFind do
		Text=Text+"
		|	"+?(isNext,"AND t.","t.")+keyVal.Key;
		if isDate and (UPPER(keyVal.Key)="DATE" or UPPER(keyVal.Key)="ДАТА") then
			Text=Text+" BETWEEN &"+ keyVal.Key+"SPeriod AND &"+ keyVal.Key+"EPeriod";
			if metadataType.NumberPeriodicity = docPeriodicity.Year then
				SPeriod = BegOfYear(keyVal.value);
				EPeriod = EndOfYear(keyVal.value);
			elsif	metadataType.NumberPeriodicity = docPeriodicity.Nonperiodical then
				SPeriod = '00010101';
				EPeriod = EndOfYear(keyVal.value);
			elsif	metadataType.NumberPeriodicity = docPeriodicity.Month then
				SPeriod = BegOfMonth(keyVal.value);
				EPeriod = EndOfMonth(keyVal.value);
			elsif	metadataType.NumberPeriodicity = docPeriodicity.Day then
				SPeriod = BegOfDay(keyVal.value);
				EPeriod = EndOfDay(keyVal.value);
			else //Quarter
				SPeriod = BegOfQuarter(keyVal.value);
				EPeriod = EndOfQuarter(keyVal.value);
			endif;	
			query.SetParameter(keyVal.Key+"SPeriod", SPeriod);
			query.SetParameter(keyVal.Key+"EPeriod", EPeriod);
		else	
			Text=Text+"=&"+ keyVal.Key;
			query.SetParameter(keyVal.Key, keyVal.value);
		endif;
		isNext = true;
	endDo;
	if ValueIsFilled(Owner) then
		Text=Text+"
		|	"+?(isNext,"AND ","")+"t.Owner=&Owner";
		query.SetParameter("Owner", Owner);
	endif;
	query.Text=Text;
	cursor=query.Execute().Select();
	if cursor.Next() then
		obj = cursor.Ref;
	endif;
	
	return obj;
endfunction	

//приведение строки в дату по маске формата
// Параметры:
//  Value  - string - значение даты в произвольном формате
//  mask   - string - маска формата
//          'YY' или 'YYYY' - год, 'MM' - месяц число, 'MON' - месяц строкой, 'DD' - день, 'h' - час, 'm' - мин, 's' - сек
//          остальные символы считаються разделителями, если части не разделены разделителем,
//          то определяються по позиции в исходной строке блоке
//	yearUnder2000 - число - (opt)интепретировать год меньше которого как 19хх, иначе 20хх
//  aMounts       - array(12) - (opt)строковые представления месяцов
//
// Возвращаемое значение:
//   дата
function AssignToDate(value, mask, yearUnder2000=30, aMounts=undefined) export
	
	sDate = trimAll(value);
	if sDate = "" then
		return '00010101';
	endif;

	YY = 1;
	MM = 1;
	DD = 1;
	h  = 0;
	m  = 0;
	s  = 0;
	
	sCharFormats = "YMONDhms";
	
	//разоберем маску на массив управляющих  структур
	// { "part,delimeter,length" }  
	aMask = new array;
	rPart = undefined;
	IsPart      = false;
	IsDelimeter = false; 
	idx=1;
	idFormatOld = 0;
	While idx<=StrLen(mask) do
		sC=mid(mask,idx,1);
		idFormat = Find(sCharFormats, sC);
		if idFormat>1 and idFormat<5 then idFormat=1 endIf;
		
		if rPart = undefined 
			or (idFormat>0 and not IsPart) 
			or (idFormat>0 and idFormat<>idFormatOld) then
			
			rPart = new structure("part,delimeter,length","","",0);
			IsPart = true;
			idFormatOld = idFormat;
			
			aMask.Add(rPart);
		endif;
		
		if idFormat>0 then
			if rPart.part<>sC then   //приведем part к односимвольному коду, кроме MON
				rPart.part = rPart.part + sC;
			endif;
			rPart.length = rPart.length + 1;
		else
			rPart.delimeter = rPart.delimeter + sC;
			IsPart = false;
			IsDelimeter = true;
		endif;	
		
		idx=idx+1;
	endDo;	
	if rPart.length = 1 and rPart.delimeter="" then
		rPart.delimeter = Chars.LF; //конец строки для последней части, если её длина 1 и после нет разделителя
	endif;	
	
	//чтение строки даты
	
	for each part in aMask do
		//конец разбираемой строки
		if sDate = "" then
			break;
		endif;
		
		if part.delimeter = Chars.LF then //отсечка по концу строки
			sPart = sDate;
			sDate = "";
		elsif part.delimeter <> "" then //отсечка по разделителю
			length = Find(sDate, part.delimeter)-1;
			if length > 0 then
				sPart = Left(sDate, length);
				sDate = Mid(sDate, length+StrLen(part.delimeter)+1); 
			else
				sPart = sDate;
				sDate = "";
			endif	
		else   //по длине
			sPart = Left(sDate, part.length); 
			sDate = Mid(sDate, part.length); 
		endif;
		
		if part.part = "Y" and part.length<4 then
			year = Number(sPart);
			if year<20 then
				YY = 1900+year;
			else
				YY = 2000+year;
			endif;
		elsif part.part = "Y" then
			YY = Number(sPart);
		elsif part.part = "M" then
			MM = Number(sPart);
		elsif part.part = "MON" then
			if aMounts=undefined then
				aMounts=new array;
				aMounts.Add("jan");
				aMounts.Add("feb");
				aMounts.Add("mar");
				aMounts.Add("apr");
				aMounts.Add("may");
				aMounts.Add("jun");
				aMounts.Add("jul");
				aMounts.Add("aug");
				aMounts.Add("sep");
				aMounts.Add("oct");
				aMounts.Add("nov");
				aMounts.Add("dec");
			endif;	
			MM = aMounts.Find(sPart)+1;
			if  MM = undefined then MM = 1 endif;
		elsif part.part = "D" then
			DD = Number(sPart);
		elsif part.part = "h" then
			h = Number(sPart);
		elsif part.part = "m" then
			m = Number(sPart);
		elsif part.part = "s" then
			s = Number(sPart);
		else
		endif;
		
	endDo;	
	
	return Date(YY,MM,DD,h,m,s);
endfunction

////////////////////////////////////////////////////////
//  Хлам
//

//безопасное получение значения свойства
//
//function GetProperty(struct,name,def=undefined)
//	try
//		if struct = undefined then
//			return def;
//		elsif typeOf(struct) = type("structure") then
//			if struct.Property(name) then
//				return struct[name];
//			endif;
//			return def;
//		else
//			return struct[name];
//		endif;
//	except
//		message("Ошибка получения свойства """+name+""" у параметра типа: "+String(struct));
//		return def;
//	endtry
//endfunction	

