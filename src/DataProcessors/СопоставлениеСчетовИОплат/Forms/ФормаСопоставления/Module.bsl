//////////////////////////////////////////////////////////////////////////////////
//  Design by GRish!                                                 23/04/2019
//
//  Сопоставление платежей и дел
//    при необходимость уточняються Контрагенты как ИП,
//    Данные в платеже обновляються по сопоставленому делу 
//
//    создаеться документы Чеков для физ лиц при оплате через клиент-банк или терминал
//

procedure SetVisualItems()
	Items.СоздатьЧеки.Visible = Объект.СопоставленныеДокументы.Count()<>0;
endprocedure

&AtServer
procedure СопоставитьServer()
	period = Объект.ПериодОтбора;
	listPP = Обработки.СопоставлениеСчетовИОплат.GetListPP(period.ДатаНачала, period.ДатаОкончания);
	//listPP = Объект.Платежи.Выгрузить();
	
	list = Обработки.СопоставлениеСчетовИОплат.GetCollateList(listPP);
	
	Объект.СопоставленныеДокументы.Clear();
	for each rec in list do
		newRow = Объект.СопоставленныеДокументы.Add();
		newRow.Дело               = rec.Дело;
		newRow.ПлатежноеПоручение = rec.ПлатежноеПоручение;
		
		CaclRow(newRow);
	endDo;	
	
	 SetVisualItems();
endprocedure

&AtServerNoContext
procedure CaclRow(rowData)
	if not ValueIsFilled(rowData.Дело) then
		
		rowdata.КодСостояния = -1;
		
	elsif rowData.Дело = rowData.ПлатежноеПоручение.Договор then
		
		rowdata.КодСостояния = 0;
			
	elsif  rowData.Дело.Контрагент <> rowData.ПлатежноеПоручение.Плательщик then
		
		if rowData.overPay then
			rowdata.КодСостояния = 2;
		else
			rowdata.КодСостояния = 1;
		endif;	
		
	elsif ValueIsFilled(rowData.ПлатежноеПоручение.Договор) and rowData.Дело<>rowData.ПлатежноеПоручение.Договор then
		
		rowdata.КодСостояния = 3;
		
	endif;
	rowData.Контрагент        = rowData.ПлатежноеПоручение.Плательщик;
	rowData.КонтрагентСтрокой = rowData.ПлатежноеПоручение.ПлательщикСтрокой;
	rowData.НазначениеПлатежа = rowData.ПлатежноеПоручение.НазначениеПлатежа;
	
endprocedure	

&AtServer
procedure СоздатьЧекиServer()
	IsBeginTransaction = false;
	КонтрагентНаселение = Константы.Население.Get();
	
	for each row in Объект.СопоставленныеДокументы	do
		//Обработать нужно все платежки
		if  ValueIsFilled(row.Дело) 
			and ValueIsFilled(row.ПлатежноеПоручение) 
			and not row.ПлатежноеПоручение.Обработано then
			
			CashV = undefined;
			try
				textError = "ошибка начала транзакции";
				BeginTransaction();
				IsBeginTransaction = true;
				//определим по счету необходимость создания Чека
				if OnlineCashboxКлиентСервер.ЭтоСчетЮрЛица(row.ПлатежноеПоручение.НомерСчетаКонтрагента) then
					//if ValueIsFilled(row.Дело)
					//  мы не должны обработать платеж от физ лица без договора
					if row.Дело.Контрагент.ЮрФизЛицо = Перечисления.ЮрФизЛицо.ЮрЛицо then
						IsNeedCash = false;
					elsif not row.Дело.Контрагент.ИП and row.ПлатежноеПоручение.НомерСчетаКонтрагента<>"" then
						//если надо обновим контрагента  ФизЛицо -> ИП
						textError = "неудалось обновить Контрагента";
						if  row.Дело.Контрагент <> КонтрагентНаселение then
							objКонтрагент = row.Дело.Контрагент.GetObject();
							objКонтрагент.ИП = true;
							objКонтрагент.Write();
						endif;
					endif;
					//если счет пуст, то возможно ложное срабатывание как Юр
					IsNeedCash = row.Дело.Контрагент.ЮрФизЛицо = enums.ЮрФизЛицо.ФизЛицо 
					             and not row.Дело.Контрагент.ИП; 
					//false;
				else
					if not ValueIsFilled(row.Дело) and not ValueIsFilled(row.ПлатежноеПоручение.Плательщик) then
						CommitTransaction();
						IsBeginTransaction = false;
						continue;
					endif;	
					IsNeedCash = true;
				endif;	
				//обрабатываем платежку
				textError = "неудалось обновить Платежное поручение";
				objPP = row.ПлатежноеПоручение.GetObject();
				objPP.Договор    = row.Дело; 
				objPP.Плательщик = row.Дело.Контрагент;
				objPP.Обработано = true;
				objPP.Write( РежимЗаписиДокумента.Проведение);
				
				textError = "неудалось проверить существование чека";
				CashV = OnlineCashboxСервер.GetCashVoucherForPP(row.ПлатежноеПоручение); 
				
				//генерируем чек
				if IsNeedCash and not ValueIsFilled(CashV) then
					//if  then
					textError = "неудалось создать Чек";
					objCash = Documents.КассовыйЧек.CreateDocument();
					objCash.Fill(row.ПлатежноеПоручение);
					objCash.Date = CurrentDate();
					if  row.Дело.Квитанции.Count()>0 then
						//распределяем сумму
						//пропорционально всем квитанциям
						aSumm    = ОбщегоНазначения.РаспределитьСуммуПропорциональноКоэффициентам(row.ПлатежноеПоручение.Сумма,    row.Дело.Квитанции.UnloadColumn("Сумма"),2); 
						aSummNDS = ОбщегоНазначения.РаспределитьСуммуПропорциональноКоэффициентам(row.ПлатежноеПоручение.СуммаНДС, row.Дело.Квитанции.UnloadColumn("Сумма"),2); 
						idx = 0;
						objCash.Товары.Clear();
						for each rowC in row.Дело.Квитанции do
							
							newRow = objCash.Товары.Add();
							newRow.Услуга = rowC.Услуга;
							newRow.ВидОплаты = enums.ВидОплаты.ЭлектронныйПлатеж;
							newRow.Сумма     = aSumm[idx];
							if aSummNDS<>undefined then
								newRow.СуммаНДС  = aSummNDS[idx];
							endIf;
							idx = idx + 1;
						endDo;
					else
						objCash.Товары.Clear();
						newRow = objCash.Товары.Add();
						newRow.Услуга = "Услуги по договору №"+row.Дело.Номер;
						newRow.ВидОплаты = enums.ВидОплаты.ЭлектронныйПлатеж;
						newRow.Сумма     = row.ПлатежноеПоручение.Сумма;
						newRow.СуммаНДС  = row.ПлатежноеПоручение.СуммаНДС;
					endif;
					objCash.Write(DocumentWriteMode.Posting, );
					CashV = objCash.ref;
					//endif;
				elsif IsNeedCash then	
					message("для " + row.ПлатежноеПоручение + " уже был создан чек " + CashV);
				endif;
				CommitTransaction();
				IsBeginTransaction = false;
				
				row.Чек = CashV;
			except
				if IsBeginTransaction then
					IsBeginTransaction = false;
					RollbackTransaction();
				endif;
				
				textInfo  = "";
				errorInfo = errorInfo();
				While errorInfo<>undefined do
					textInfo = textInfo + errorInfo.SourceLine +" >> "+ errorInfo.Description;
					errorInfo = errorInfo.Cause;
				endDo;	
				message = new UserMessage;
				message.ПутьКДанным = "Объект";
				message.Field = "СопоставленныеДокументы["+row.НомерСтроки+"]";
				message.Текст = "строка["+row.НомерСтроки+"]: "+textError+"
				|"+ textInfo;
				message.ИдентификаторНазначения = thisObject.UUID; 
				message.Message();
				
				
			endtry;
			
		endif;
		
		CaclRow(row);
	endDo;
	
endprocedure

//Создать дело под платежку от населения
//
&AtServerNoContext
procedure СоздатьДелоServer(rowData)
	if not ValueIsFilled(rowData.ПлатежноеПоручение) then 
		return;
	endif;
	
	beginTransaction();
	
	objДело = Документы.Договор.CreateDocument();
	objДело.Дата = CurrentDate();
	objДело.Номер= OnlineCashboxКлиентСервер.ResizeCode( Left(Format(rowData.ПлатежноеПоручение.Дата,"ДФ=ddMMyy")+rowData.ПлатежноеПоручение.Номер,10),11);
	
	objДело.Контрагент = Константы.Население.get();
	objДело.Сумма      = rowData.ПлатежноеПоручение.Сумма;
	objДело.СуммаНДС   = rowData.ПлатежноеПоручение.СуммаНДС;
	
	rowКвитанция = objДело.Квитанции.Add();
	rowКвитанция.ДатаУслуги     = rowData.ПлатежноеПоручение.Дата;
	rowКвитанция.НомерКвитанции = OnlineCashboxКлиентСервер.ResizeCode(Format(rowData.ПлатежноеПоручение.Дата,"ДФ=yyMMdd")+rowData.ПлатежноеПоручение.Номер,15);
	rowКвитанция.Услуга         = "Услуга МФЦ";
	rowКвитанция.Сумма          = rowData.ПлатежноеПоручение.Сумма;
	rowКвитанция.СуммаНДС       = rowData.ПлатежноеПоручение.СуммаНДС;
	
	objДело.Write();
	rowData.Дело = objДело.Ref;
	
	CommitTransaction();
	
	CaclRow(rowData);
endprocedure

////////////////////////////////////////////////////////////////////
//    Команды формы
//


&НаКлиенте
Процедура Сопоставить(Команда)
	
	СопоставитьServer();
	
	Items.СопоставленныеДокументы.Refresh();
	
КонецПроцедуры

&НаКлиенте
Процедура СоздатьЧеки(Команда)
	СоздатьЧекиServer();
КонецПроцедуры

&НаКлиенте
Процедура СоздатьДело(Команда)
	idRow   = Items.СопоставленныеДокументы.CurrentRow;
	rowdata = Items.СопоставленныеДокументы.RowData(idRow);
	if not ValueIsFilled(rowdata.Дело) then
		recData = new structure("КодСостояния,ПлатежноеПоручение,Дело,Контрагент,КонтрагентСтрокой,НазначениеПлатежа,overPay");
		FillPropertyValues(recData, rowdata);
		
		СоздатьДелоServer(recData);
		
		FillPropertyValues(rowdata, recData, "КодСостояния,Дело,Контрагент,КонтрагентСтрокой,НазначениеПлатежа");
	else
		message = new UserMessage;
		message.TargetID = UUID;
		message.DataPath = "Объект";
		message.Field    = "СопоставленныеДокументы["+rowdata.НомерСтроки+"].Дело";
		message.Text     = "Уже есть сопоставленное дело!";
		message.Message();
	endif;	
КонецПроцедуры

////////////////////////////////////////////////////////////////////
//    Обработчики элементов формы
//

&НаКлиенте
Процедура СопоставленныеДокументыДелоПриИзменении(Элемент)
	idRow   = Items.СопоставленныеДокументы.CurrentRow;
	rowdata = Items.СопоставленныеДокументы.RowData(idRow);
	
	recData = new structure("КодСостояния,ПлатежноеПоручение,Дело,Контрагент,КонтрагентСтрокой,НазначениеПлатежа,overPay");
	FillPropertyValues(recData, rowdata);
	
	CaclRow(recData);
	
	FillPropertyValues(rowdata, recData, "КодСостояния,Контрагент,КонтрагентСтрокой,НазначениеПлатежа");
КонецПроцедуры

&НаКлиенте
Процедура СопоставленныеДокументыПлатежноеПоручениеПриИзменении(Элемент)
	idRow   = Элемент.CurrentRow;
	rowdata = Элемент.RowData(idRow);
	
	recData = new structure("КодСостояния,ПлатежноеПоручение,Дело,Контрагент,КонтрагентСтрокой,НазначениеПлатежа");
	FillPropertyValues(recData, rowdata);
	CaclRow(recData);
	FillPropertyValues(rowdata, recData, "КодСостояния,Контрагент,КонтрагентСтрокой,НазначениеПлатежа");
КонецПроцедуры

////////////////////////////////////////////////////////////////////
//  обработчики событий формы
//

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	Items.СопоставленныеДокументыДело.ChoiceForm               = "Обработка.СопоставлениеСчетовИОплат.Форма.ОтборДел";
	Items.СопоставленныеДокументыПлатежноеПоручение.ChoiceForm = "Обработка.СопоставлениеСчетовИОплат.Форма.ОтборПП";
	
	SetVisualItems();
КонецПроцедуры


&НаКлиенте
Процедура СопоставленныеДокументыДелоНачалоВыбора(Элемент, ДанныеВыбора, СтандартнаяОбработка)
	idRow   = Items.СопоставленныеДокументы.CurrentRow;
	rowdata = Items.СопоставленныеДокументы.RowData(idRow);
	
	//aParams = Новый Массив();
	//if ValueIsFilled(rowdata.Контрагент) then
	//	aParams.Добавить(Новый ПараметрВыбора("Отбор.Контрагент" , rowdata.Контрагент));
	//endif;
	//Items.СопоставленныеДокументыДело.ПараметрыВыбора = new FixedArray(aParams);
	params = new structure;
	params.Insert("CurrentRow", rowdata.Дело);
	params.Insert("ChoiceMode", true);
	params.Insert("MultipleChoice", false);
	
	if ValueIsFilled(rowdata.Контрагент) then
		params.Insert("Отбор" , new structure("Контрагент",rowdata.Контрагент));
	endif;
	params.Insert("НазначениеПлатежа", rowdata.НазначениеПлатежа);
	params.Insert("ПлательщикСтрокой", rowdata.КонтрагентСтрокой);
	
	OpenForm("Обработка.СопоставлениеСчетовИОплат.Форма.ОтборДел", params, Элемент );
	
	СтандартнаяОбработка = false;
КонецПроцедуры


