///////////////////////////////////////////////////////////////////////////
// design by GRish!                                         16/04/2019
//
//  загрузка дел
//
//
//

&AtServer
procedure SetVisualItems()
		
	items.Загрузка.visible  = state=0;
	items.Результат.visible = state=1;
	
	items.actReadFile.visible       = state=0;
	items.actReadFile.DefaultButton = state=0;
	
	items.actPrev.visible = state = 1;
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
		
		Docs.Clear();
		for each doc in aDocs do
			newRow = Docs.Add();
			newRow.Дело = doc;
		endDo;
		
		state = 1;
		SetVisualItems();
	endIf;	
endprocedure

&AtClient
procedure actChooseFile(res, ext) export
	if res<>undefined and res.count()>0 then
		ИмяФайла = res[0];
		ShowContent();
	endIf;	
endprocedure

&AtClient
procedure ShowContent()
	ПредпросмотрФайла = "";
	try
		reader = new TextReader(ИмяФайла, codePage);
		str = "";
		
		idx = 0;
		While str<>undefined and idx<10 do
			if idx>0 then
				ПредпросмотрФайла = ПредпросмотрФайла + str +"
				|";
			endif;
			
			str = reader.ReadLine();
			idx = idx + 1;
		endDo;
		if idx = 10 then
			ПредпросмотрФайла = ПредпросмотрФайла + "
				|.... ";
		endif;	
	except
	endtry;
endprocedure	

&AtServer
function ReadFile()
	Rules = Константы.НастройкиИмпортаДел.Get().Get();
	if Rules=undefined then
		message("Сначало необходимо настроить обработку загрузки!");
		return new array;
	endif;	
	codePage   = Rules.codePage;
	binaryData = GetFromTempStorage(Объект.URLTempstorage);
	reader     = new textReader(binaryData.OpenStreamForRead(), codePage);
	
	aDocs =  Обработки.ЗагрузкаДел.ReadCSV(reader, Rules);
	
	return aDocs;
endfunction

&AtClient
procedure actSaveParams(res, ext) export

	//LoadSettings();

endprocedure	

///////////////////////////////////////////////////////////////////////////
//   Обработчики событий формы
//

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
		
	Rules = Константы.НастройкиИмпортаДел.Get().Get();
	if Rules=undefined then
		codePage = "utf-8";
	else
		codePage = Rules.codePage;
	endif;
	SetVisualItems();
	
КонецПроцедуры

&НаКлиенте
Процедура ПриОткрытии(Отказ)
	if ИмяФайла <> "" then
		ShowContent();	
	endif;
КонецПроцедуры

///////////////////////////////////////////////////////////////////////////
//   Обработчики команд формы
//


&НаКлиенте
Процедура actParams(Команда)
	
	params = new structure("Секция","configИмпортДел");
	handler = new NotifyDescription("actSaveParams", ThisObject, new structure);
	OpenForm("Обработка.ПанельАдминистрированияCasbox.Форма.НастройкиОбработокЗагрузки",params,thisObject,,,handler); //,FormWindowOpeningMode.LockOwnerWindow
	
КонецПроцедуры

&НаКлиенте
Процедура actPrev(Команда)
	state = 0;
	SetVisualItems();
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаПриИзменении(Элемент)
	ShowContent();	
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаНачалоВыбора(Элемент, ДанныеВыбора, СтандартнаяОбработка)
	file = new File(ИмяФайла);
	
	dlg = new FileDialog(РежимДиалогаВыбораФайла.Открытие);
	dlg.Directory    = file.Path;
	dlg.FullFileName = ИмяФайла;
	dlg.Filter = "Файл выгрузки начислений по платным услугам(CSV)|*.CSV";
	
	handler = new NotifyDescription("actChooseFile",ThisObject);
	dlg.Show(handler);	

КонецПроцедуры

&НаКлиенте
Процедура actReadFile(Команда)
	
	if ИмяФайла <> "" then 
		file = new File(ИмяФайла);
		handler = new NotifyDescription("actBeginLoadFile",ThisObject,ИмяФайла);
		file.BeginCheckingExistence(handler);
	endif;	
	
КонецПроцедуры
