/////////////////////////////////////////////////////////////////////////////////////
// design by GRish!                                                    01/04/2019
//  
// методы общие для нескольких объектов
//  
//

/////////////////////////////////////////////////////////////////////////////////////
//  Работа с CSV файлом
//

procedure SetIdColumsCSV(list) export
	
	Константы.ПоляФайлаCSV.Set(new ValueStorage(list));
	
endprocedure

function  GetIdColumsCSV() export
	
	storage = Константы.ПоляФайлаCSV.Get();
	if storage<>undefined then
		list = storage.Get();
		if list<>undefined then
			return list;
		endif;
	endif;
	
	return new array;	
	
endfunction

/////////////////////////////////////////////////////////////////////////////////////
//  Движения регистра накопления
//

Процедура ОбработкаПроведенияДокументов(Источник, Отказ, РежимПроведения) Экспорт
	
	if TypeOf(Источник) = type("ДокументОбъект.Договор") then
		moving = Источник.RegisterRecords.ВзаиморасчетыПоДелам;    
		moving.Clear();
		
		tbl = Источник.Квитанции.Unload();
		tbl.GroupBy("","Сумма,СуммаНДС");
		for each row in tbl do
			newRow = moving.Add();
			
			FillPropertyValues(newRow, row);
			
			newRow.Period = Источник.Date;
			newRow.Договор = Источник.Ref;
			newRow.RecordType = AccumulationRecordType.Receipt;
		endDo;
		moving.Write = true;
		
	elsif TypeOf(Источник) = type("ДокументОбъект.ПлатежноеПоручение") then
		moving = Источник.RegisterRecords.ВзаиморасчетыПоДелам;    
		moving.Clear();
		//(+) Сводные платежки от ПАО Сбербанк
		if ValueIsFilled(Источник.Договор) and not Источник.СводныйПлатеж then
			newRow = moving.Add();
			
			newRow.Period = Источник.Date;
			
			newRow.Договор    = Источник.Договор;
			newRow.Сумма      = Источник.Сумма;
			newRow.СуммаНДС   = Источник.СуммаНДС;
			
			newRow.RecordType = AccumulationRecordType.Expense;
		endif;
		
		moving.Write = true;
	endif;	
	
КонецПроцедуры


/////////////////////////////////////////////////////////////////////////////////////
//
//

//получить кассовый чес создаанный для платежки
//
function GetCashVoucherForPP(Платеж) export
	return Documents.КассовыйЧек.FindByAttribute("Основание", Платеж);
endfunction	