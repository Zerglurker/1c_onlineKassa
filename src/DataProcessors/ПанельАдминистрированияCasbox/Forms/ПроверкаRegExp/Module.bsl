
&НаСервере
Процедура testRegExpНаСервере()
	
	regExp = new COMObject("VBScript.RegExp");// создаем объект для работы с регулярными выражениями
	regExp.MultiLine  = true;  // true — текст многострочный, false — одна строка
	regExp.Global     = false; // true — поиск по всей строке, false — до первого совпадения
	regExp.IgnoreCase = false; // true — игнорировать регистр строки при поиске
	
	regExp.Pattern = Expression;
	matches = regExp.Execute(testText);
	if matches.count()>0 
		and matches.Item(0).SubMatches.count()>= RegExpGroup then 
		result  = matches.Item(0).SubMatches.Item(RegExpGroup);
	else
		result  = "-ненайдено-";
	endif;
	
КонецПроцедуры

&НаКлиенте
Процедура testRegExp(Команда)
	
	testRegExpНаСервере();
	
КонецПроцедуры

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	
	FillPropertyValues(thisObject, Параметры,"Expression,RegExpGroup");
	Памятка.Вывести(  GetCommonTemplate("ПамяткаRegExp_table")  );
	//Памятка.УстановитьHTML(GetCommonTemplate("ПамяткаRegExp").GetText(), new structure);
	//Памятка.ПолучитьТекст()
КонецПроцедуры

&НаКлиенте
Процедура showHelp(Команда)
	
КонецПроцедуры
