
&НаСервереБезКонтекста
function СписокНомеровКвитанции()
	
	return new array;
	
endfunction

&AtClientAtServerNoContext
procedure CaclSum(Form)
	Summ = 0;
	
	for each row in Form.Объект.Товары do
		Summ = Summ + row.Сумма;
	endDo;
	Form.Сумма = Summ;
	
endprocedure	

&AtServer
procedure SetVisibleItems()
	Items.ГруппаФискальный.Visible = Объект.Обработан;
	ReadOnly = Объект.Обработан;
endprocedure	
////////////////////////////////////////////////////////////////////
//    обработчики элементов формы
//

&НаКлиенте
Процедура ТоварыПриОкончанииРедактирования(Элемент, НоваяСтрока, ОтменаРедактирования)
	CaclSum(thisObject);
КонецПроцедуры

&НаКлиенте
Процедура ТоварыНомерКвитанцииНачалоВыбораИзСписка(Элемент, СтандартнаяОбработка)
	list = СписокНомеровКвитанции();
	Элемент.СписокВыбора.LoadValues( list );
КонецПроцедуры


////////////////////////////////////////////////////////////////////
//  обработчики событий формы
//

&НаСервере
Процедура ПриЧтенииНаСервере(ТекущийОбъект)
	CaclSum(thisObject);
	SetVisibleItems();
КонецПроцедуры
