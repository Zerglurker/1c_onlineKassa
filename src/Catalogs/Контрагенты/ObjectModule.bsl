
Процедура ПередЗаписью(Отказ)
	if ОбменДанными.Загрузка then
		return;
	endif;
	
	if not ValueIsFilled(Owner) then
		Owner = Справочники.ЮрФиз.ФизЛицо;
	endif;
	
	if Owner = Справочники.ЮрФиз.ФизЛицо then
		
		ЮрФизЛицо = Перечисления.ЮрФизЛицо.ФизЛицо;
		
	elsif Owner = Справочники.ЮрФиз.ЮрЛицо then
		
		ЮрФизЛицо = Перечисления.ЮрФизЛицо.ЮрЛицо;
		
	endif;	
КонецПроцедуры
