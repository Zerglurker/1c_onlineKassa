///////////////////////////////////////////////////////////////////
//
//

///////////////////////////////////////////////////////////////////
//  серисные процедуры и функции
//

&AtServer
procedure РаспаковатьНастройкиИмпортаПП(storageParams) export
	
	if storageParams<>undefined then
		recParams = storageParams.Get();
		if recParams <> undefined then
			FillPropertyValues(thisObject, recParams);
			try
				for each row in recParams.RegExpДело do
					newRow = tblRegExpДело.Add();
					FillPropertyValues( newRow, row);
				endDo;
				for each row in recParams.RegExpКвитанция do
					newRow = tblRegExpКвитанция.Add();
					FillPropertyValues( newRow, row);
				endDo;
			except
			endtry;
			return;
		endif;
	endif;
	
	//настройка по умолчанию
	ВерсияФормата = "TXPP170701";
	РазделительВПлательщик = "//";
	ПозицияВПлательщик     = 2;
	//РазделительВНазначении.Clear();
	//РазделительВНазначении.Add(":");
	РазделительВНазначении = ";";
	ПризнакСводнойПлатежки = "эл.реестр";
	
	rowExpr=tblRegExpДело.Add();
	rowExpr.RegExpression   = "(квитанции\s)(\d{3,15})(.*)";
	rowExpr.idxGroup        = 1;
endprocedure

&AtServer
procedure РаспаковатьНастройкиИмпортаДел(storageParams) export
	
	if storageParams<>undefined then
		
		recParams = storageParams.Get();
		if recParams <> undefined then
			try
				thisObject.ДелоРазделительСтолбцовCSVфайла = recParams.Delimeter;
				ДелоСоотвествиеПолей.Clear();
				for each rule in recParams.Rules do
					row = ДелоСоотвествиеПолей.Add();
					fillPropertyValues(row, rule);
				endDo;
				
				thisObject.МаскаДатыCSVфайла        = recParams.maskDate;
				thisObject.ДелоКодировкаФайла       = recParams.codePage;
			except
			endtry;
		
			return; //все ОК
		endif;
	endif;
	
	//настройка по умолчанию
	thisObject.ДелоРазделительСтолбцовCSVфайла = "|";
	thisObject.МаскаДатыCSVфайла               = "DD.MM.YYYY hh:mm:ss";
	thisObject.ДелоКодировкаФайла              = "utf-8";
	
	thisObject.ДелоСоотвествиеПолей.Clear();
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"delo_dat",  "Договор.Дата");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"delo_id",   "Договор.id");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"delo_num",  "Договор.Номер");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"kvit_num",  "Договор.Квитанции.НомерКвитанции");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"kvit_dat",  "Договор.Квитанции.ДатаУслуги");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"pusl_naz",  "Договор.Квитанции.Услуга");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"kvit_costk","Договор.Квитанции.Сумма");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"kvit_nds",  "Договор.Квитанции.СуммаНДС");
	
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"ids_open", "Договор.Филиал.Код");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"isp_naz",  "Договор.Филиал.Наименование");
	
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"zak_id",   "Договор.Контрагент.Код");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"zak_name", "Договор.Контрагент.Наименование");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"zak_type", "Договор.Контрагент.ЮрФизЛицо");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"zak_adr",  "Договор.Контрагент.Адрес");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"zak_tel",  "Договор.Контрагент.телефон");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"zak_email","Договор.Контрагент.емайл");
	SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"zak_type", "Договор.Контрагент.Type");
	//SetДелоСоотвествиеПолей(thisObject.ДелоСоотвествиеПолей	,"", "", false);
	
endprocedure

&AtClientAtServerNoContext
procedure SetДелоСоотвествиеПолей(tbl, IdParameter, nameField);
	
	newRow=tbl.Add();
	
	newRow.IdParameter = IdParameter;
	newRow.nameField   = nameField;
	//newRow.isFind      = isFind;
	
endprocedure	

&AtServer
function СформироватьНастройкиИмпортаДел() export
	
	recParams= new structure("Delimeter, Rules, maskDate, codePage", 
		thisObject.ДелоРазделительСтолбцовCSVфайла,
		new array,
		thisObject.МаскаДатыCSVфайла, 
		thisObject.ДелоКодировкаФайла);
		
	for each row in ДелоСоотвествиеПолей do
		recParams.Rules.Add(new structure("IdParameter,nameField", row.IdParameter, row.nameField)); 
	endDo;
	
	return new ValueStorage(recParams);	
endfunction

&AtServer
function СформироватьНастройкиИмпортаПП() export
	
	recParams = new structure("ВерсияФормата,РазделительВПлательщик,ПозицияВПлательщик,РазделительВНазначении,ИменаДело,ИменаКвитанции,
	|UseRegExpPP,RegExpДело,RegExpКвитанция,ПризнакСводнойПлатежки");  // ,RegExpGroupДело,RegExpGroupКвитанция
	FillPropertyValues(recParams,thisObject);
	
	recParams.RegExpДело      = tblRegExpДело.Unload();
	recParams.RegExpКвитанция = tblRegExpКвитанция.Unload();
	
	return new ValueStorage(recParams);	
endfunction

procedure setVisualItems()
	Items.ГруппаСтандартПарсингПП.Visible = not UseRegExpPP;
	Items.ГруппаRegExpПарсингПП.Visible   = UseRegExpPP;
endprocedure

///////////////////////////////////////////////////////////////////
//  Обработчики элементов формы
//

&НаКлиенте
Процедура UseRegExpPPПриИзменении(Элемент)
	setVisualItems();	
КонецПроцедуры

&НаКлиенте
Процедура testRegExp(Команда)
	if RegExpression<>"" then
		params = new structure("Expression,RegExpGroup",RegExpression,idxGroup);
	elsif tblRegExpКвитанция.Count() > 0 then
		params = new structure("Expression,RegExpGroup",tblRegExpКвитанция[0].RegExpression,tblRegExpКвитанция[0].idxGroup);
	elsif tblRegExpДело.Count() > 0 then
		params = new structure("Expression,RegExpGroup",tblRegExpДело[0].RegExpression,tblRegExpДело[0].idxGroup);
	else
		params = new structure("Expression,RegExpGroup");
	endif;
	
	OpenForm("Обработка.ПанельАдминистрированияCasbox.Форма.ПроверкаRegExp", params);
КонецПроцедуры

///////////////////////////////////////////////////////////////////
//  Обработчики событий формы
//

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	
	if НаборКонстант.ЗаголовокСистемы = "" then
		
		НаборКонстант.ЗаголовокСистемы = "онлан-касса";
		
	endif;
	
	if Параметры.Секция<>"" then
		itm = Items[Параметры.Секция];
		itm.Show();
	endif;
	
	Items.ДелоСоотвествиеПолейПолеОбъекта.ChoiceList.LoadValues( Обработки.ЗагрузкаДел.GetFieldNames());
	
	Items.ДелоСоотвествиеПолейСтолбецCSV.ChoiceList.LoadValues(OnlineCashboxСервер.GetIdColumsCSV());
	
КонецПроцедуры

&НаСервере
Процедура ПередЗаписьюНаСервере(Отказ, ТекущийОбъект, ПараметрыЗаписи)
	
	 Константы.НастройкиИмпортаДел.Set(СформироватьНастройкиИмпортаДел());
	 Константы.НастройкиИмпортаПП.Set(СформироватьНастройкиИмпортаПП());
	 
КонецПроцедуры

&НаСервере
Процедура ПриЧтенииНаСервере(ТекущийОбъект)

	РаспаковатьНастройкиИмпортаДел(Константы.НастройкиИмпортаДел.Get());
	РаспаковатьНастройкиИмпортаПП( Константы.НастройкиИмпортаПП.Get());
	
	setVisualItems();
КонецПроцедуры

&НаКлиенте
Процедура ПриЗакрытии(ЗавершениеРаботы)
	
	
КонецПроцедуры

&НаКлиенте
Процедура tblRegExpДелоПриАктивизацииСтроки(Элемент)
	//idRow = Элемент.CurrentRow;
	RegExpression = Элемент.CurrentData.RegExpression;
	idxGroup      = Элемент.CurrentData.idxGroup;
КонецПроцедуры

&НаКлиенте
Процедура tblRegExpКвитанцияПриАктивизацииСтроки(Элемент)
	//idRow = Элемент.CurrentRow;
	if Элемент.CurrentData<>undefined then
		RegExpression = Элемент.CurrentData.RegExpression;
		idxGroup      = Элемент.CurrentData.idxGroup;
	endif;
КонецПроцедуры
