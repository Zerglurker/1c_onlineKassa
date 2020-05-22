
//DEBUG: запрос токена
&AtServerNoContext
function Login(params)
	return Обработки.ПечатьЧековOnline.Login(params);
	//baseUrl  = "online.schetmash.com";  // https://
	//resource = "/lk/api/v1"+"/token";
	////user="test_api";
	////pass="123456";
	////IDмагазина=42;
	//user       = params.логин;
	//pass       = params.пароль;
	//IDмагазина = params.IDмагазина;	
	//
	//ssl = new OpenSSLSecureConnection(); 
	////Новый СертификатКлиентаWindows(СпособВыбораСертификатаWindows.Выбирать),
	////Новый СертификатыУдостоверяющихЦентровWindows() 
	//json = new JSONWriter;
	//json.SetString();
	//
	//WriteJSON(json, new structure("login,password",user,pass));
	//
	//textJSON = json.Close();
	//			
	//req = ПроцедурыОбменаXHTML.POST(textJSON, baseUrl, resource, user, pass,,ssl);
	//
	//if Find(req, "{")>0 then
	//	jsonR = new JSONReader;
	//	jsonR.SetString(req);
	//	req = ReadJSON(jsonR,true);
	//	
	//	return req["token"];
	//endif;	
	//
	//return req;
endfunction	

//печать чека на ККМ online
//
&AtServer
function PrintCashServer(params, Чек)
	return  Обработки.ПечатьЧековOnline.PrintCash(params, Чек);
	//if Чек.Обработан then
	//	req = new structure("code", 0);
	//endif;	
	//
	//baseUrl  = "online.schetmash.com";  // https://
	////resource = "/lk/api/v1"+"/";

	//user       = params.логин;
	//pass       = params.пароль;
	//IDмагазина = params.IDмагазина;	
	//
	//// мы сначало сохраняем в регистр, потом по регистру обновляем статусы чеков
	//idrequest=Обработки.ПечатьЧековOnline.ПроверитьЧекВОбработке(Чек);
	//if idrequest<>undefined then
	//	return new structure("id,status",idrequest,"acccept");
	//endif;	
	//
	//token = Login(params);
	//
	//ssl = new OpenSSLSecureConnection(); 
	//
	//if token<>undefined then
	//	rec = new structure("timestamp,external_id,receipt",Чек.Date, Чек.Number,);
	//	rec.receipt = new structure("attributes,items, total, payments", 
	//		new structure("email,phone", Чек.Контрагент.емайл, Чек.Контрагент.телефон),
	//		new array,
	//		0,
	//		new array
	//	);
	//	total = 0;
	//	for each row in Чек.Товары do 
	//		rRow = new structure("name,price,quantity,sum,tax,tax_sum", row.Услуга, row.Сумма, 1, row.Сумма, "none", 0);
	//		rec.receipt.items.Add(rRow);
	//		total = total + row.Сумма;
	//	endDo;
	//	rec.receipt.total = total;
	//	
	//	tbl = Чек.Товары.unload();
	//	tbl.GroupBy("ВидОплаты","Сумма");
	//	for each row in tbl do 
	//		rrow = new structure("type,sum",ОбщегоНазначенияOnline.ПолучитьПорядковыйНомерЗначенияПеречисления(row.ВидОплаты), row.Сумма);
	//		rec.receipt.payments.Add(rrow);
	//	endDo;

	//	json = new JSONWriter;
	//	json.SetString();
	//	
	//	WriteJSON(json, rec);
	//	
	//	textJSON = json.Close();
	//	
	//	resource = Обработки.ПечатьЧековOnline.GetResourceCashbox(token, Чек.ТипОперации, IDмагазина); 
	//	
	//	req = ПроцедурыОбменаXHTML.POST(textJSON, baseUrl, resource, user, pass,,ssl);
	//	
	//	if Find(req, "{")>0 then
	//		jsonR = new JSONReader;
	//		jsonR.SetString(req);
	//		req = ReadJSON(jsonR); //As structrure

	//		if req.Property("status") and req.status = "accept" then
	//			Обработки.ПечатьЧековOnline.ЗарегестрироватьЧекВОбработке(Чек, req.id);
	//		endif;
	//	else
	//		req = new structure("code", -1);
	//	endif;	
	//	req.Insert("json",textJSON);
	//	return req;
	//endif;
	//
	//return  new structure;
endfunction	

//Получить данные обработанных чеков
//
//
&AtServerNoContext
Процедура ReportCashServer(params)
	Обработки.ПечатьЧековOnline.ReportCash(params);	
	//baseUrl  = "online.schetmash.com";  // https://
	//user       = params.логин;
	//pass       = params.пароль;
	//IDмагазина = params.IDмагазина;	
	//
	//token = Login(params);
	//ssl = new OpenSSLSecureConnection(); 
	//
	//if token<>undefined then
	//	
	//	query = new query;
	//	query.Text =
	//	"ВЫБРАТЬ
	//	|	t.Чек КАК Чек,
	//	|	t.Чек.ТипОперации as ТипОперации,
	//	|	t.id КАК id,
	//	|	t.Дата КАК Дата
	//	|ИЗ
	//	|	РегистрСведений.ЧекиВОбработке КАК t
	//	|";
	//	
	//	for each row in query.Execute().Unload() do
	//	
	//		resource = Обработки.ПечатьЧековOnline.GetResourceRepot(token, row.Чек.ТипОперации, row.ID, IDмагазина); 
	//		
	//		req = ПроцедурыОбменаXHTML.GET("", baseUrl, resource, user, pass,,ssl);
	//		if Find(req, "{")>0 then
	//			jsonR = new JSONReader;
	//			jsonR.SetString(req);
	//			req = ReadJSON(jsonR); //As structrure
	//			
	//			if req.Property("status") and req.status = "success" then
	//				beginTransaction();
	//				
	//				ЧекОбъект = row.Чек.GetObject();
	//				ЧекОбъект.Обработан = true;
	//				ЧекОбъект.ФискальныйНомер    = req.payload.fiscal_document_number;
	//				ЧекОбъект.ФискальныйАттрибут = req.payload.fiscal_document_attribute;
	//				
	//				ЧекОбъект.Write();
	//				
	//				Обработки.ПечатьЧековOnline.ОчиститьЧекВОбработке(row.Чек);
	//				
	//				CommitTransaction();
	//			endif;
	//		endif;	
	//		
	//	endDo;
	//endif;
	
КонецПроцедуры

//получить параметры соединения с online-кассой
//
&AtServerNoContext
function GetLoginParamsServer()
	return Обработки.ПечатьЧековOnline.GetLoginParams();	
endfunction	

//Отправить Чек в online-кассу
//
&НаСервере
Процедура PrintOnlineCashНаСервере()
	
	json = new ЗаписьJSON;
	json.SetString(new JSONWriterSettings(
		JSONLineBreak.Unix,              //перенос строк
		Chars.Tab,                       //отступ
		false,                           //use  ""
		JSONCharactersEscapeMode.None,   //ЭкранированиеСимволов
		false,                           //экранировать <>
		false,                           //экранировать &
		true,                            //экранировать "
		true,                            //экранировать разделители строк
		false)                           //экранировать /
	);
	
	json.WriteStartObject();//ЗаписатьНачалоОбъекта
	
	json.WritePropertyName("timestamp"); //ЗаписатьИмяСвойства
	json.WriteValue( WriteJSONDate(CurrentDate(), JSONDateFormat.ISO) ); // ЗаписатьЗначение
	//ВариантЗаписиДатыJSON
	 
	json.WriteEndObject();
	
	textBody = json.Close(); 
	
КонецПроцедуры

//////////////////////////////////////////////////////
//  Обработчики команд формы
//

&НаКлиенте
Процедура PrintOnlineCash(Команда)
	//PrintOnlineCashНаСервере();           
	//DEBUG:
	params = new structure("логин,пароль,IDмагазина","test_api","123456",42);
	
	res = PrintCashServer(params, Объект.Чек);
	if res.Property("code", КодОшибки) then
		res.Property("message", ТекстОшибки);
		res.Property("json", textJSON);
	endif;	
КонецПроцедуры

&НаКлиенте
Процедура Report(Команда)
	params = GetLoginParamsServer();
	if params = undefined then
		message("Необходима настройка соединения с online-кассой");
		return;
	endif;	
	ReportCashServer(params);
КонецПроцедуры

