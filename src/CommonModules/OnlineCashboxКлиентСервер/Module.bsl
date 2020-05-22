/////////////////////////////////////////////////////////////////////////////////////
// Общие Процедуры и функции, выполняемые на клиенте и сервере
//
//


procedure ПодсчитатьИтоговыеСуммы(Сумма, СуммаНДС, Квитанции) export
	Сумма = 0;
	СуммаНДС = 0;
	for each row in Квитанции do
		Сумма    = Сумма + row.Сумма;
		СуммаНДС = СуммаНДС + row.СуммаНДС;
	endDo;	
	
endprocedure

//опеределим юр лицо  по расчетному счету
//
function ЭтоСчетЮрЛица(НомерСчета ) export
	Счет = TrimAll(НомерСчета);
	
	if Find(Счет,"407")=1 then
		return true; //ИП
	elsif Find(Счет,"409")=1 then
		return false; //физ лица банкомат/интернет банк
	elsif Find(Счет,"3")=1 then
		return false; //наличные в терминале
	elsif Find(Счет,"000")=1 then
		return false; //глюк банка
	endif;
	
	return true;  //все прочие
endfunction	

/////////////////////////////////////////////////////////////////////////////////////
//  работа с номерами документов и справочников
//

// Разбирает строку, выделяя из нее префикс и числовую часть.
//
// Параметры:
//  Code            - Строка. Разбираемая строка;
//  NumberPart      - Число. Переменная, в которую возвратится числовая часть строки;
//  Mode            - Строка. Если "Number", то возвратит числовую часть, иначе - префикс.
//
// Возвращаемое значение:
//  Префикс строки
//
function GetPrefixCode(Val Code, NumberPart = "", Mode = "") export

	Code    = TrimAll(Code);
	Prefix 	= Code;
	Letgth  = StrLen(Code);

	For iC = 1 To Letgth Do
		try
			NumberPart = Number(Code);
		except
			Code = Right(Code, Letgth - iC);
			continue;
		endTry;

		If (NumberPart > 0) И (StrLen(Format(NumberPart, "NG=0")) = Letgth - iC + 1) Then 
			Prefix = Left(Prefix, iC - 1);

			While Right(Prefix, 1) = "0" Do
				Prefix = Left(Prefix, StrLen(Prefix) - 1);
			endDo;

			break;
		else
			Code = Right(Code, Letgth - iC);
		endIf;

		If NumberPart < 0 Then
			NumberPart = - NumberPart
		endIf;

	endDo;

	If Mode = "Number" Then
		Return(NumberPart);
	else
		Return(Prefix);
	endIf;
      
endfunction //ПолучитьПрефиксЧислоНомера() 

// Приводит номер (код) к требуемой длине. При этом выделяется префикс
// и числовая часть номера, остальное пространство между префиксом и
// номером заполняется нулями.
// Функция может быть использована в обработчиках событий, программный код 
// которых хранится в правила обмена данными. Вызывается методом Выполнить()
//
// Параметры:
//  Cod          - преобразовываемая строка;
//  newLength    - требуемая длина строки.
// 	PrefixReason - операции с префиксом "" -не изменять(def), "delete" -удалить, "change" - заменить
//  newPrefix    - новый префикс
//
// Возвращаемое значение:
//  Строка       - код или номер, приведенная к требуемой длине.
// 
function ResizeCode(Cod, newLength, PrefixReason=undefined, newPrefix =undefined) export
	
	Cod       = TrimAll(Cod);   //"00003  " = Код
	oldLength = StrLen(Cod);
	
	NumberPart   = "";
	
	prefix       = GetPrefixCode(Cod, NumberPart);
	prefixLength = StrLen(prefix);
	
	compensation =0;
	if PrefixReason="delete" then
		prefix="";
		compensation = - prefixLength;
	elsif PrefixReason="uppend" then
		prefix=prefix + newPrefix;
		compensation = StrLen(newPrefix);
	elsif PrefixReason="insert" then
		prefix=newPrefix + prefix;
		compensation = StrLen(newPrefix);
	elsif PrefixReason="change" then
		prefix=newPrefix;
		compensation = StrLen(newPrefix) - prefixLength;
	endif;
	
	if oldLength + compensation > newLength then
		//обрезаем     prefixLen = 3,  oldLength = 6, newLength= 5   --> pos = 5 = 3 +(6-5) + 1
		Cod ="" + prefix + Mid(Cod, prefixLength + (oldLength - newLength + compensation) + 1, oldLength);
	elsif	oldLength + compensation < newLength then
		//добавляем
		Cod ="" + prefix + Format( Number(NumberPart),"ND="+String(newLength - prefixLength - compensation)+";NLZ=;NG="+String(newLength-prefixLength - compensation)+",0");
	endif;	
	
	Возврат(Cod);
	
endfunction // ПривестиНомерКДлине()
