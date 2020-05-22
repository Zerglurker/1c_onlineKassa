///////////////////////////////////////////////////////////////////////////////////
//
// Обмен данными с сервисом касс: online.schetmash.com
// Основная форма
//
//



//////////////////////////////////////////////////////////////////////////////////
//        сервисные процедуры и функции
//

&AtServerNoContext
procedure ExecServer()
	params = Обработки.ПечатьЧековOnline.GetLoginParams();
	if params = undefined 
		or not params.property("IDмагазина") 
		or not ValueIsFilled(params.IDмагазина) then
		
		message("Необходима настройка соединения с online-кассой");
		return;
	endif;	
	
	token = Обработки.ПечатьЧековOnline.Login(params);
	aCash = Обработки.ПечатьЧековOnline.ПолучитьЧекиДляПечати();
	for each Cash in aCash do
		res = Обработки.ПечатьЧековOnline.PrintCash(params, Cash, token);
		
		if res.property("code") and res.code=-1 then
			message = new UserMessage;
			message.УстановитьДанные(Cash);
			message.Text ="ошибочные данные в чеке:"+Cash;
			message.Message();
		endif;	
	endDo;
	
endprocedure	

&AtServerNoContext
procedure ReportCashServer(IsNotEnd)
	
	params = Обработки.ПечатьЧековOnline.GetLoginParams();
	aCash = Обработки.ПечатьЧековOnline.ReportCash(params);
	IsNotEnd = aCash.Count()<>0;
	
endprocedure

&AtClient
procedure ReportCash()
	
	ИдетОбработка = false;
	IsNotEnd      = false;
	
	ReportCashServer(IsNotEnd);
	Items.Список.Refresh();
	
	if IsNotEnd then
		AttachIdleHandler("ReportCash", 15, true);
	endif;
endprocedure	

//////////////////////////////////////////////////////////////////////////////////
//         Обработчики команд формы
//

&НаКлиенте
Процедура Обработать(Команда)
	if ИдетОбработка then
		return;
	endif;
	
	ExecServer();
	
	Items.Список.Refresh();
	
	ИдетОбработка = true;
	AttachIdleHandler("ReportCash", 20, true);
	
КонецПроцедуры

//////////////////////////////////////////////////////////////////////////////////
//         Обработчики элементов формы
//

&НаКлиенте
Процедура СписокВыбор(Элемент, ВыбраннаяСтрока, Поле, СтандартнаяОбработка)
	
	if ValueIsFilled(ВыбраннаяСтрока) then
		params = new structure("Key",ВыбраннаяСтрока); 
		OpenForm("Документ.КассовыйЧек.ФормаОбъекта", params);	
	endif;	
	
КонецПроцедуры

