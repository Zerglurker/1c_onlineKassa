
&AtServer
procedure LoadSettings()
	params = Константы.НастройкиИмпортаПП.get().get();
	if params<>undefined then
		FillPropertyValues(Объект, params);
	else
		//Объект.РежимРаботы = "PP3";
	endif;
	
	SetVisualItems();
	
endprocedure

&AtServer
procedure SetVisualItems()
	//isPP3 = Объект.РежимРаботы = "PP3";
	isPP3 = true;
		
	items.ЗагрузкаPP3.visible = isPP3 and state=0;
	//items.ЗагрузкаExcel.visible = not isPP3  and state=0;
	items.Результат.visible  = state = 1;
	
	items.actReadFilePP3.visible       = isPP3  and state=0;
	items.actReadFilePP3.DefaultButton = isPP3  and state=0;
	
	items.actPrev.visible = state = 1;
endprocedure	

&AtServer
function ReadFile()
	verFormata = Объект.ВерсияФормата;
	if not ValueIsFilled(verFormata) then
		verFormata = "TXPP170701";
	endif;
	
	template = Обработки.ЗагрузкаПлатежныхПоручений.ПолучитьМакет(verFormata);
	rules    = Обработки.ЗагрузкаПлатежныхПоручений.LoadRules( template );
	
	binaryData = GetFromTempStorage(Объект.URLTempstorage);
	reader     = new textReader(binaryData.OpenStreamForRead());
	
	aDocs = Обработки.ЗагрузкаПлатежныхПоручений.ReadPP3(reader, rules);
	
	return aDocs;
endfunction

&AtClient
procedure actSaveParams(res, ext) export
	//if res=true then
	LoadSettings();
	//endIf;	
endprocedure	

&AtClient
procedure BeginLoadFile()
	if ИмяФайла <> "" then 
		file = new File(ИмяФайла);
		handler = new NotifyDescription("actBeginLoadFile",ThisObject,ИмяФайла);
		file.BeginCheckingExistence(handler);
	endif;	
endprocedure

&AtClient
procedure actBeginLoadFile(isExist,fileName) export
	if isExist then
		aFiles = new array;
		aFiles.Add(new TransferableFileDescription( fileName, Объект.URLTempstorage));
		
		handler = new NotifyDescription("actLoadFile",ThisObject);
		BeginPuttingFiles(handler,aFiles,,false, UUID);	
	endIf;
endprocedure

//Запуск разбора файла
&AtClient
procedure actLoadFile(res, ext) export
	if res<>undefined and res.count()>0 then
		Объект.URLTempstorage = res[0].Хранение;
		ИмяФайла = res[0].Имя;
		
		aDocs = ReadFile();
		
		//отчет о созданных документах
		Docs.Clear();
		for each doc in aDocs do
			newRow = Docs.Add();
			newRow.ПлатежноеПоручение = doc;
		endDo;
		
		state = 1;
		SetVisualItems();
	endIf;	
endprocedure

&AtClient
procedure actChooseFile(res, ext) export
	if res<>undefined and res.count()>0 then
		ИмяФайла = res[0];
	endIf;	
endprocedure

///////////////////////////////////////////////////////////////////////////
//   Обработчики событий формы
//

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	
	LoadSettings();
	
КонецПроцедуры

&НаКлиенте
Процедура ПриОткрытии(Отказ)
	
КонецПроцедуры

///////////////////////////////////////////////////////////////////////////
//   Обработчики команд формы
//

&НаКлиенте
Процедура actParams(Команда)
	
	params = new structure("Секция","configИмпортПП");
	handler = new NotifyDescription("actSaveParams", ThisObject, new structure);
	OpenForm("Обработка.ПанельАдминистрированияCasbox.Форма.НастройкиОбработокЗагрузки",params,thisObject,,,handler); //,FormWindowOpeningMode.LockOwnerWindow
	
КонецПроцедуры

&НаКлиенте
Процедура actReadFilePP3(Команда)
	
	BeginLoadFile();
	
КонецПроцедуры

&НаКлиенте
Процедура actPrev(Команда)
	state = 0;
	SetVisualItems();
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаНачалоВыбора(Элемент, ДанныеВыбора, СтандартнаяОбработка)
	file = new File(ИмяФайла);
	
	dlg = new FileDialog(РежимДиалогаВыбораФайла.Открытие);
	dlg.Directory    = file.Path;
	dlg.FullFileName = ИмяФайла;
	dlg.Filter = "(PP3/5)|*.PP?";
	
	handler = new NotifyDescription("actChooseFile",ThisObject);
	dlg.Show(handler);	

	//BeginPuttingFiles(handler, ,dlg,true, UUID);
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаПриИзменении(Элемент)

КонецПроцедуры
