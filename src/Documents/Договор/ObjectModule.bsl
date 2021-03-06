////////////////////////////////////////////////////////////////////
//
//
//
//



Процедура ПередЗаписью(Отказ, РежимЗаписи, РежимПроведения)
	if ОбменДанными.Загрузка then
		return;
	endif;
	
	OnlineCashboxКлиентСервер.ПодсчитатьИтоговыеСуммы(Сумма, СуммаНДС, Квитанции);	
	
	КвитанцияСтрокой = "";
	for each row in Квитанции do
		КвитанцияСтрокой = КвитанцияСтрокой +?( StrLen(КвитанцияСтрокой)>0,"; ","") + row.Услуга;
	endDo;
	
	КонтрагентСтрокой = Контрагент.Наименование;
	
КонецПроцедуры

Процедура ПриЗаписи(Отказ)
	if ОбменДанными.Загрузка then
		return;
	endif;
	
	if DeletionMark then
		query = new query;
		query.Text = 
		"ВЫБРАТЬ
		|	t.НомерКвитанции КАК НомерКвитанции,
		|	t.Договор КАК Договор
		|ИЗ
		|	РегистрСведений.НомераКвитанций КАК t
		|ГДЕ
		|	t.Договор = &Ref
		|
		|ДЛЯ ИЗМЕНЕНИЯ";
		
		query.SetParameter("Ref", Ref);
		tblКвитанции = query.Execute().Unload();
		for each row in tblКвитанции do
			rec = РегистрыСведений.НомераКвитанций.СоздатьМенеджерЗаписи();
			rec.НомерКвитанции = row.НомерКвитанции;
			rec.Договор        = Ref;
			rec.Delete();
		endDo;
		
	else	
		//продублируем в регистр № квитанций
		for each row in Квитанции do
			if row.НомерКвитанции<>0 then
				rec = РегистрыСведений.НомераКвитанций.СоздатьМенеджерЗаписи();
				rec.НомерКвитанции = row.НомерКвитанции;
				rec.Договор        = Ref;
				rec.Write(true);
			endif;
		endDo;	
	endif;
	
КонецПроцедуры

