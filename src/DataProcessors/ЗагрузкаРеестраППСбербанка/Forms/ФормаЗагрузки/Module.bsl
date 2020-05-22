

///////////////////////////////////////////////////////////////////////////
//   сервисные процедуры и обработки
//

&AtServer
procedure SetVisualItems()
		
	items.ЗагрузкаРеестра.visible = state=0;
	
	items.Результат.visible  = state = 1;
	
	items.actReadFile.visible       = state=0;
	items.actReadFile.DefaultButton = state=0;
	
	items.actPrev.visible = state = 1;
endprocedure	

&AtServer
function ReadFile(IsZip)
	
	verFormata = "RSber201906";
	
	template = Обработки.ЗагрузкаРеестраППСбербанка.ПолучитьМакет(verFormata);
	rules    = Обработки.ЗагрузкаРеестраППСбербанка.LoadRules( template );
	
	binaryData = GetFromTempStorage(Объект.URLTempstorage);
	if IsZip then
		rand = new RandomNumberGenerator; 
		s    = string( rand.RandomNumber(111,999));
		ZipArch    = new ZipFileReader(binaryData.OpenStreamForRead());
		pathExtras =  КаталогВременныхФайлов() + s +"\";
		ZipArch.ExtractAll(pathExtras, ZIPRestoreFilePathsMode.DontRestore);
		//читаем txt файлы
		reader     = new textReader(pathExtras + ZipArch.Items[0].Name);
	else
		reader     = new textReader(binaryData.OpenStreamForRead());
	endif;
	aDocs = Обработки.ЗагрузкаРеестраППСбербанка.ReadReestr(reader, rules);
	
	//удаляем распакованные файлы
	if IsZip then
		reader.Close();
		DeleteFiles(pathExtras, ZipArch.Items[0].Name);
	endif;
	
	return aDocs;
endfunction

&AtClient
procedure BeginLoadFile()
	if ИмяФайла <> "" then 
		file = new File(ИмяФайла);
		handler = new NotifyDescription("actBeginLoadFile",ThisObject,file);  // ИмяФайла
		file.BeginCheckingExistence(handler);
	endif;	
endprocedure

&AtClient
procedure actBeginLoadFile(isExist,file) export
	if isExist then       
		fileName = file.FullName;
		
		aFiles = new array;
		aFiles.Add(new TransferableFileDescription( fileName, Объект.URLTempstorage));
		
		handler = new NotifyDescription("actLoadFile",ThisObject, new structure("IsZip",UPPER(file.Extension) = ".ZIP"));
		BeginPuttingFiles(handler,aFiles,,false, UUID);	
	endIf;
endprocedure

//Запуск разбора файла
&AtClient
procedure actLoadFile(res, ext) export
	if res<>undefined and res.count()>0 then
		Объект.URLTempstorage = res[0].Хранение;
		ИмяФайла = res[0].Имя;
		
		aDocs = ReadFile(ext.IsZip);
		
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
	SetVisualItems();	
КонецПроцедуры

&НаКлиенте
Процедура ПриОткрытии(Отказ)
	
КонецПроцедуры

///////////////////////////////////////////////////////////////////////////
//   Обработчики элементов формы
//


&НаКлиенте
Процедура ИмяФайлаНачалоВыбора(Элемент, ДанныеВыбора, СтандартнаяОбработка)
	file = new File(ИмяФайла);
	
	dlg = new FileDialog(РежимДиалогаВыбораФайла.Открытие);
	dlg.Directory    = file.Path;
	dlg.FullFileName = ИмяФайла;
	if  UPPER(Right(ИмяФайла,4))=".TXT" then
		dlg.Filter = "реестр платежей сбербанка(txt)|*_*_*.txt|реестр платежей сбербанка(zip)|*_*_*.zip|";
	else	
		dlg.Filter = "реестр платежей сбербанка(zip)|*_*_*.zip|реестр платежей сбербанка(txt)|*_*_*.txt";
	endif;	
	//dlg.DefaultExt = ?( Left(Right(ИмяФайла,4),1)=".",Right(ИмяФайла,4),"");
	
	handler = new NotifyDescription("actChooseFile",ThisObject);
	dlg.Show(handler);	

	//BeginPuttingFiles(handler, ,dlg,true, UUID);
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаПриИзменении(Элемент)

КонецПроцедуры

///////////////////////////////////////////////////////////////////////////
//   Обработчики команд формы
//

&НаКлиенте
Процедура actReadFile(Команда)
	
	BeginLoadFile();
	
КонецПроцедуры

&НаКлиенте
Процедура actPrev(Команда)
	state = 0;
	SetVisualItems();
КонецПроцедуры

