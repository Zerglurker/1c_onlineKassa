////////////////////////////////////////////////////////////////////
//
//
//
//


Процедура ПередЗаписью(Отказ, РежимЗаписи, РежимПроведения)
	if ОбменДанными.Загрузка then
		return;
	endif;
	
	if not ValueIsFilled(ДатаЗагрузки) then
		ДатаЗагрузки = CurrentDate();
	endif;	
КонецПроцедуры

////////////////////////////////////////////////////////////////////
//
//

procedure FillПлательщик( Delimeter, iCount) export
	typeКонтрагент = type("СправочникСсылка.Контрагенты");
	//Rules = new array;
	//Rules.Add(new structure("objProperty,XDTOProperty,IsFind"));
	
	
	list = СтроковыеФункцииКлиентСервер.РазложитьСтрокуВМассивПодстрок( ПлательщикСтрокой, Delimeter, true);
	//iCount = 0;
	isExist= false;
	//for each a in list do
	if list.Count()>0 and list.Count()-1 >= iCount then
		refКонтрагент = ПроцедурыОбменаXDTO.AssignToType(list[iCount-1], typeКонтрагент,,);
		if ValueIsFilled(refКонтрагент) then
			//if Плательщик = refКонтрагент then
			//	isExist = true;
			//endif;	
			////iCount = iCount + 1;
			Плательщик = refКонтрагент;
		endif;
	endif;	
	//endDo;	
	
endprocedure

procedure FillНомера(Delimeter, NamesContract, NamesInvoice) export
	typeДоговор = type("ДокументСсылка.Договор");
	//if Delimeters.Count()>0 then
	//	Delimeter =  Delimeters[0];
	//else
	if Delimeter="" then
		message("Не настроен разбор платежного поручения!");
		return;
	endif;
	list = СтроковыеФункцииКлиентСервер.РазложитьСтрокуВМассивПодстрок( НазначениеПлатежа, Delimeter, true);
	//iCount = 0;
	for each keypar in list do
		for each NameInvoice in NamesInvoice do
			if NameInvoice<>"" then
				
				idxInvoice = Find(keypar, NameInvoice);
				if idxInvoice>0 then
					НомерКвитанции = Mid(keypar, idxInvoice + StrLen(NameInvoice));
					
					break;
				endif;	
			endIf;	
		endDo;
		for each  NameContract in  NamesContract do
			if NameContract<>"" then
				idxContract = Find(keypar, NameContract);
				if idxContract>0 then
					
					НомерДоговора = Mid(keypar, idxContract + StrLen(NameContract));
					Договор = ПроцедурыОбменаXDTO.AssignToType(НомерДоговора, typeДоговор,,);
					if ValueIsFilled(Договор) then
						Контрагент = Договор.Контрагент;
					endif;
					
					break;
				endIf;
			endif;	
		endDo;
	endDo;
	
endprocedure

////параметры
//   regExp   = СOMObject "VBScript.RegExp"
//   RegExpInvoice ТаблициЗначений
procedure FillRegExpНомера(regExp, RegExpInvoice, RegExpContract) export     //,idxInvoice, idxContract

	typeДоговор = type("ДокументСсылка.Договор");
	for each filter in RegExpInvoice do
		if filter.RegExpression<>"" then
			regExp.Pattern = filter.RegExpression;	
			matches = regExp.Execute(НазначениеПлатежа);
			
			if matches.count()>0 
				and matches.Item(0).SubMatches.count()>= filter.idxGroup then
				
				НомерКвитанции  = matches.Item(0).SubMatches.Item(filter.idxGroup);
				break;
			endif;	
		endIf;
	endDo;
	
	for each filter in RegExpContract do
		if filter.RegExpression<>"" then
			regExp.Pattern = filter.RegExpression;
			matches = regExp.Execute(НазначениеПлатежа);
			
			if matches.count()>0 
				and matches.Item(0).SubMatches.count()>= filter.idxGroup then
				
				НомерДоговора = matches.Item(0).SubMatches.Item(filter.idxGroup);
				Договор = ПроцедурыОбменаXDTO.AssignToType(НомерДоговора, typeДоговор,,);
				
				if ValueIsFilled(Договор) then
					Контрагент = Договор.Контрагент;
				endif;
				
				break;
			endif;	
		endif;
	endDo;
	
endprocedure
	

