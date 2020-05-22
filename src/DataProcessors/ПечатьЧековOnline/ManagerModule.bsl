//////////////////////////////////////////////////////////////////////////////////
// Обмен данными с сервисом касс: online.schetmash.com
//
//
//

//////////////////////////////////////////////////////////////////////////////////
// сервисные процедуры
//

//формируем строку запроса
//  http://online.schetmash.com/lk/api/v1/{shopid}/{operation}?token={token}
//
function GetResourceCashbox(token, ТипОперации, id=undefined) export
	
	if id=undefined then
		id = Constants.IDмагазина.Get();
	endif;  
	id_ = Format(id,"ЧГ=0");
	
	operation = ОбщегоНазначенияOnline.ПолучитьНаименованиеЗначенияПеречисления(ТипОперации); 
	
	return "/lk/api/v1/"+id_+"/"+operation+"?token="+token;
	
endfunction

//формируем строку запроса
//  http://online.schetmash.com/lk/api/v1/{shopid}/report/{id}?token={token}
//
function GetResourceRepot(token, ТипОперации, id, idShop=undefined) export
	
	if idShop=undefined then
		idShop=Constants.IDмагазина.Get(); 
	endif;
	idShop_ = Format(idShop,"ЧГ=0");
	id_ = Format(id,"ЧГ=0");
	
	operation = ОбщегоНазначенияOnline.ПолучитьНаименованиеЗначенияПеречисления(ТипОперации); 
	
	return "/lk/api/v1/"+idShop_+"/report/"+id_+"?token="+token;
	
endfunction

//////////////////////////////////////////////////////////////////////////////////
// сетевой обмен
//

//запрос токена
function Login(params) export               
	
	baseUrl  = "online.schetmash.com";  // https://
	resource = "/lk/api/v1"+"/token";
	user     = params.логин;
	pass     = params.пароль;
	
	
	ssl = new OpenSSLSecureConnection(); 

	json = new JSONWriter;
	json.SetString();
	
	WriteJSON(json, new structure("login,password",user,pass));
	
	textJSON = json.Close();
				
	req = ПроцедурыОбменаXHTML.POST(textJSON, baseUrl, resource, user, pass,,ssl);
	
	if Find(req, "{")>0 then    //в теле ответ JSON, прочтем его
		jsonR = new JSONReader;
		jsonR.SetString(req);
		req = ReadJSON(jsonR,true);  //As map
		
		return req["token"];  //если нету такого поля, то undefined
	else	
		message("токен не получен:
		|"+req);
		
		return undefined;     //иначе токен не получен
	endif;	
	
endfunction

//Отправить Чек в online-кассу
//
//ВозвращаемоеЗначение
//   структура    -  {code, status, json}
//{
// "timestamp":"07.06.2018 09:19:18", //дата оплаты
// "external_id":"sell_test.ru_16", //уникальный номер документа
// "service":
// {
//    "callback_url":"https://test.ru/api.php", // Адрес, на который придёт ответ от сервера
// },
// "receipt":
// {
//   "attributes":
//   {
//   "email":"Email покупателя",
//   "phone":"телефон покупателя"
//  },
//  "items":
//  [
//		{
//		"name":"Название товара",
//		"price":17, //Цена с учётом скидок
//		"quantity":2, //количество
//		"sum":34, //сумма
//		"tax":"vat18", //НДС, допустимые значения vat18, vat20, vat10, vat118, vat110, vat0, none
//		"tax_sum":2.59
//		}
//	],
//	"total":17, //сумма по чеку.
//	"payments":
//	[
//		{
//			"type":1, //Вид оплаты: 1 – электронный, 2 – аванс, 3 - кредит
//			"sum":17
//		}
//	]
//}
function PrintCash(params, Чек, token = undefined) export
	if Чек.Обработан then
		req = new structure("code", 0);
	endif;	
	
	baseUrl  = "online.schetmash.com";  // https://
	//resource = "/lk/api/v1"+"/";

	user       = params.логин;
	pass       = params.пароль;
	IDмагазина = params.IDмагазина;	
	
	// мы сначало сохраняем в регистр, потом по регистру обновляем статусы чеков
	idrequest=Обработки.ПечатьЧековOnline.ПроверитьЧекВОбработке(Чек);
	if idrequest<>undefined then
		return new structure("id,status",idrequest,"acccept");
	endif;	
	
	if token = undefined then 
		token = Login(params);
	endif;
	
	ssl = new OpenSSLSecureConnection(); 
	
	if token<>undefined then
		rec = new structure("timestamp,external_id,receipt",Чек.Date, Чек.Number,);
		rec.receipt = new structure("attributes,items, total, payments", 
			new structure("email,phone", Чек.Контрагент.емайл, Чек.Контрагент.телефон),
			new array,
			0,
			new array
		);
		//если пуст емайл и телефон
		if not ValueIsFilled(rec.receipt.attributes.email) and not ValueIsFilled(rec.receipt.attributes.phone) then
			rec.receipt.attributes.email=params.email;
		endif;
		total = 0;
		for each row in Чек.Товары do 
			//rRow = new structure("name,price,quantity,sum,tax,tax_sum", row.Услуга, row.Сумма, 1, row.Сумма, "none", 0);
			rRow = new structure("name,price,quantity,sum,tax,tax_sum", row.Услуга, row.Сумма, 1, row.Сумма, "vat20", round(row.Сумма*20/120,2));
			rec.receipt.items.Add(rRow);
			total = total + row.Сумма;
		endDo;
		rec.receipt.total = total;
		
		tbl = Чек.Товары.unload();
		tbl.GroupBy("ВидОплаты","Сумма");
		for each row in tbl do 
			rrow = new structure("type,sum",ОбщегоНазначенияOnline.ПолучитьПорядковыйНомерЗначенияПеречисления(row.ВидОплаты), row.Сумма);
			rec.receipt.payments.Add(rrow);
		endDo;

		json = new JSONWriter;
		json.SetString();
		
		WriteJSON(json, rec);
		
		textJSON = json.Close();
		
		resource = Обработки.ПечатьЧековOnline.GetResourceCashbox(token, Чек.ТипОперации, IDмагазина); 
		
		reqJSON = ПроцедурыОбменаXHTML.POST(textJSON, baseUrl, resource, user, pass,,ssl);
		
		if Find(reqJSON, "{")=1 then
			jsonR = new JSONReader;
			jsonR.SetString(reqJSON);
			req = ReadJSON(jsonR); //As structure

			if req.Property("status") then 
				if req.status = "accept" then
					Обработки.ПечатьЧековOnline.ЗарегестрироватьЧекВОбработке(Чек, req.id);
				else
					Обработки.ПечатьЧековOnline.ЗарегестрироватьОшибкуНаККТ(Чек, req.status, ?(req.property("message"), req.message, reqJSON)); 
				endif;
			endif;
		else
			req = new structure("code", -1);
		endif;	
		req.Insert("json",textJSON);
		return req;
	endif;
	
	return  new structure;
endfunction	

//Получить данные обработанных чеков
//
//пример ответа
//{
// "id": 243,
// "status": "success",
// "payload": {
// "total": 100,
// "fns_site": "www.nalog.ru",
// "fn_number": "9999078900012080",
// "shift_number": 4,
// "receipt_datetime": "22 Aug 2018 11:54:10 +0300",
// "fiscal_receipt_number": 2,
// "fiscal_document_number": 19,
// "ecr_registration_number": "0024546546059435",
// "fiscal_document_attribute": 2618445764
// },
// "timestamp": "22.08.2018 11:56:30"
//}
function ReportCash(params, token = undefined) export
	
	baseUrl  = "online.schetmash.com";  // https://
	user       = params.логин;
	pass       = params.пароль;
	IDмагазина = params.IDмагазина;	
	
	if token = undefined then 
		token = Login(params);
	endif;
	ssl = new OpenSSLSecureConnection(); 
	
	aCash = new array;
	
	if token<>undefined then
		
		query = new query;
		query.Text =
		"ВЫБРАТЬ
		|	t.Чек КАК Чек,
		|	t.Чек.ТипОперации as ТипОперации,
		|	t.id КАК id,
		|	t.Дата КАК Дата
		|ИЗ
		|	РегистрСведений.ЧекиВОбработке КАК t
		|";
		
		for each row in query.Execute().Unload() do
		
			resource = Обработки.ПечатьЧековOnline.GetResourceRepot(token, row.Чек.ТипОперации, row.ID, IDмагазина); 
			
			reqJSON = ПроцедурыОбменаXHTML.GET("", baseUrl, resource, user, pass,,ssl);
			if Find(reqJSON, "{")=1 then
				try 
					textError= "разбор JSON:"+reqJSON;
					jsonR = new JSONReader;
					jsonR.SetString(reqJSON);
					req = ReadJSON(jsonR); //As structrure
					
					if req.Property("status") then
						if req.status = "success" then
							aCash.Add(row.Чек);
							
							textError= "обновления состояния печати Чека:"+row.Чек;
							BeginTransaction();
							
							ЧекОбъект = row.Чек.GetObject();
							ЧекОбъект.Обработан = true;
							ЧекОбъект.ФискальныйНомер    = req.payload.fiscal_document_number;
							ЧекОбъект.ФискальныйАттрибут = req.payload.fiscal_document_attribute;
							//(+)
							ЧекОбъект.НомерЧека    = req.payload.fiscal_document_number;
							ЧекОбъект.НомерСмены   = req.payload.shift_number;
							
							ЧекОбъект.Write();
							
							Обработки.ПечатьЧековOnline.ОчиститьЧекВОбработке(row.Чек);
							
							CommitTransaction();
						else
							textError = "при отметке ошибки на ККТ";
							errorKKT = "json:" + reqJSON;
							if req.property("error") and req.error.property("message") then
								errorKKT = "при опросе:" +req.error.message;
							endif;
							Обработки.ПечатьЧековOnline.ЗарегестрироватьОшибкуНаККТ(row.Чек, req.status, errorKKT);
						endif;
					endif;
				except
					errInfo = errorInfo();
					message("Ошибка:"+textError+"
					|
					| "+errInfo.ModuleName+"["+errInfo.SourceLine+"]:"+errInfo.Description);
				endtry;
			else
				message("Ошибка на "+baseUrl+" при опросе состояния
				| 
				|"+ reqJSON );
			endif;	
			
		endDo;
	endif;
	
	return aCash;
endfunction

//////////////////////////////////////////////////////////////////////////////////
// работа с данными в БД
//

//проверим Чек в обработке, если да, то вернем id задания на обработку
//
function ПроверитьЧекВОбработке(Чек) export
	
	query = new query;
	query.Text=
	"ВЫБРАТЬ
	|	t.Чек КАК Чек,
	|	t.id КАК id
	|ИЗ
	|	РегистрСведений.ЧекиВОбработке КАК t
	|ГДЕ
	|	t.Чек = &Чек
	|
	|ДЛЯ ИЗМЕНЕНИЯ";
	
	query.SetParameter("Чек",Чек);
	
	for each res in query.Execute().Unload() do
		return res.id;
	endDo;	
	
	return undefined;
endfunction	

procedure ЗарегестрироватьЧекВОбработке(Чек, id, Дата=undefined) export
	if Дата=undefined then
		Дата=CurrentDate();
	endif;	
	
	record = РегистрыСведений.ЧекиВОбработке.СоздатьМенеджерЗаписи();
	record.Чек  = Чек;
	record.id   = id;
	record.Дата = Дата;
	record.Write(false);  //чек не должен дважды отправляться в обработку
endprocedure

procedure ЗарегестрироватьОшибкуНаККТ(Чек, Статус, ОшибкиНаККТ) export
	record = РегистрыСведений.ОшибкиНаККТ.СоздатьМенеджерЗаписи();
	record.period = CurrentDate();
	record.Чек  = Чек;
	if typeOf(Статус)=type("string") then
		record.Статус      = ПроцедурыОбменаXDTO.AssignToType(Статус, type("ПеречислениеСсылка.СтатусПечатиЧека"));
	else	
		record.Статус      = Статус;
	endif;
	record.ОшибкиНаККТ = ОшибкиНаККТ;
	record.Write(true); 
endprocedure

procedure ОчиститьЧекВОбработке(Чек) export
	record = РегистрыСведений.ЧекиВОбработке.СоздатьМенеджерЗаписи();
	record.Чек  = Чек;
	record.Delete();
endprocedure

function GetLoginParams() export
	
	//params = new structure("логин,пароль,IDмагазина","test_api","123456",42);
	params = new structure("логин,пароль,IDмагазина,email",Константы.логин.get(), Константы.пароль.get(), Константы.IDмагазина.get(), Константы.пустойEmail.Get());
	
	return params;
endfunction	

//получим необработанные и не находящиеся в работе чеки
//
function ПолучитьЧекиДляПечати() export
	query = new query;
	query.Text =
	"ВЫБРАТЬ
	|	d.Ссылка КАК Чек,
	|	d.Номер КАК Номер,
	|	d.Дата КАК Дата,
	|	d.Проведен КАК Проведен,
	|	d.Контрагент КАК Контрагент,
	|	d.ТипОперации КАК ТипОперации,
	|	d.КонтрольнаяСумма КАК КонтрольнаяСумма,
	|	iExec.id КАК idЗадания,
	|	iExec.Дата КАК ДатаПечати
	|ИЗ
	|	Документ.КассовыйЧек КАК d
	|		ЛЕВОЕ СОЕДИНЕНИЕ РегистрСведений.ЧекиВОбработке КАК iExec
	|		ПО d.Ссылка = iExec.Чек
	|ГДЕ
	|	НЕ d.Обработан
	|	И iExec.Чек ЕСТЬ NULL
	|	И НЕ d.ПометкаУдаления
	|	И d.Контрагент <> ЗНАЧЕНИЕ(Catalog.Контрагенты.emptyRef)";
	
	tbl = query.Execute().Unload();
	
	return tbl.UnloadColumn("Чек");		
endfunction	