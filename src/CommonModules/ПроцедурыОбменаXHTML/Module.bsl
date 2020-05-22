////////////////////////////////////////////////////////////////////////////////
//   Design by GRish!                                           21/02/2014
// 
// 


//MSScriptControl.ScriptControl JScript  encodeURI(url)
//
Функция comUrlEncode(url="") export
	return EncodeString( url, StringEncodingMethod.URLEncoding);     
	//.URLEncoding Кодировать в URL кодировке. 
	//.URLInURLEncoding  кодировать строку URL в URL кодировке. Спецсимволы URL ( !#$%'()*+,/:;=?@[] ) не кодируются.
	
	////до ver 8.3.3:
	//ScrCtrl = new COMОбъект("MSScriptControl.ScriptControl"); 
	//ScrCtrl.Language="JScript"; 
	//return ScrCtrl.Run( "encodeURIComponent", url); 
КонецФункции 

function URLDecode(url) export
	
	return DecodeString(url, StringEncodingMethod.URLEncoding);
	
endfunction

//Кодирует тело XML запроса
//параметры:
//   Obj    	- объект для кодирования
//   nameRule	- имя секции правил в общем макете 
//	 template   - макет с правилами в формате для ПроцедурыОбменаXDTO.LoadTransformation
//результат:
//   строка XML 
function CreateXML(Obj, nameRule, template) export
	
	if Template = undefined then
		message("nameRule:"+nameRule);
		raise "не инициализирован шаблон правил";
	endif;
	
	transformation = ПроцедурыОбменаXDTO.LoadTransformation(nameRule,,,template); 
	objXDTO = ПроцедурыОбменаXDTO.Obj2XDTO(Obj, transformation, XDTOFactory);
	
	wrt = new XMLWriter;
	wrt.SetString();
	XDTOFactory.WriteXML(wrt,objXDTO);
	
	return wrt.Close();
endfunction

//Заполнение объекта
//Параметры:
//  readXML    - чтениеXML
//  pointer_   - объект
//  Rules      - соотвествие - правила заполнения
//                map(имя узла, structure(name     = имя заполняемого реквизита  "name" или "nameContainer.name", 
//                                                     чтобы нормально читать XML c дублирующимися именами узлов для разных объектов
//                               ("." - на месте, "[]"-добавить строку, "реквезит", "реквезит[]" - добавить строку в реквезит),
//                                                   type     = тип значения,
//                                                   isObj    = true - свойство объектного типа, доступны на запись только его реквезиты, 
//                                                              переводит pointer на него,
//													 SetParam = обработчик "после установки реквизита" 
//                                                              переменные: pointer - указывает на текущий заполняемый объект
//                                                                          property - значение объектного свойства(или строки для тч)
//                                                   )
// Заполняет переданный объект данными из XML, при чтении использует правила чтобы определить что заполнять.
// Структура заполняемых объектов должны быть примерно похожей. При заполнении по заполняемому объекту перемещяеться виртуальный
// указатель, что позволяет заполнять табличные части
procedure UpdateObj(readXML, pointer_, Rules, iMess=0) export
	
	sSetParam     = undefined;
	sEndParam     = undefined;
	sFindProperty = undefined;
	
	for each vrule in Rules do
		if vrule.Value.Property("SetParam") then
			vrule.Value.Insert("SetParam",);
		endif;
		if	vrule.Value.Property("FindProperty") then
		   	vrule.Value.Insert("FindProperty",);
		endif;
	endDo;					
	
	pointerSTACK = new ValueTable;
	pointerSTACK.Columns.Add("name");
	pointerSTACK.Columns.Add("rule");
	pointerSTACK.Columns.Add("pointer");
	pointerSTACK.Columns.Add("NameProperty");
		
	idxSTACK = 0;
	curSTACK = pointerSTACK.Add();
	curSTACK.pointer = pointer_;
	preSTACK = curSTACK;
	
	While readXML.Read() do
		if readXML.NodeType=XMLNodeType.StartElement then
			//начало элемента: готовимся его читать
			if idxSTACK = pointerSTACK.Count()-1 then
				pointerSTACK.Add();
			endif;
			preSTACK = curSTACK;
			idxSTACK = idxSTACK + 1;
			curSTACK = pointerSTACK[idxSTACK];
			curSTACK.name = readXML.name;
			if preSTACK.pointer<>undefined then
				rule = Rules[preSTACK.name+"."+readXML.name];
				if rule=undefined then
					rule = Rules[readXML.name];
				endif;
				curSTACK.rule = rule;
				if rule<>undefined then
					if rule.isObj then
						//переключаемся заполняемое свойство объект/тч
						if rule.name="[]" then
							curSTACK.pointer = preSTACK.pointer.Add();//pointer = pointer.Add();
						elsif rule.name="." then
							//остаться на месте
							curSTACK.pointer = preSTACK.pointer;
						else
							if Find(rule.name,"[]")>0 then
								name = Left(rule.name,Find(rule.name,"[]")-1);
								curSTACK.pointer = preSTACK.pointer[name].Add();
							else	
								curSTACK.pointer = preSTACK.pointer[rule.name];
							endif;
						endif;
					else
						curSTACK.pointer = preSTACK.pointer;
						curSTACK.NameProperty = rule.name;
					endif;	
					if curSTACK.rule.property("SetParam",sSetParam) then
						pointer = curSTACK.pointer;
						Execute(sSetParam);
					endif;	
				endif;	
			endif;
			if iMess>0 then //DEBUG
				iMess =iMess - 1;
				message("+"+idxSTACK+" "+rule+" "+curSTACK.name+"  cur="+curSTACK.pointer +" pre="+preSTACK.pointer );
			endif;

		elsif	readXML.NodeType=XMLNodeType.EndElement then
			//конец элемента восстанавливаем указатель на изменяемый объект назад
			if curSTACK.name <> readXML.name then
				raise "Сбой счетчика idx="+idxSTACK+" nameSTACK="+curSTACK.name+" XML="+readXML.name;
			endif;
			if curSTACK.rule<>undefined and curSTACK.rule.property("EndElement",sSetParam) then
				pointer = curSTACK.pointer;
				Execute(sSetParam);
			endif;	
			curSTACK.pointer = undefined;
			curSTACK.rule    = undefined;
			if iMess>0 then //DEBUG
				iMess =iMess - 1;
				message("-"+idxSTACK+" "+curSTACK.name+"  pointer="+preSTACK.pointer);
			endif;

			idxSTACK = idxSTACK - 1;
			curSTACK=pointerSTACK[idxSTACK];
		elsif  readXML.NodeType=XMLNodeType.Text then
			value = readXML.value;
			value_= undefined;
			if curSTACK.rule <> undefined then
				if curSTACK.rule.type <> undefined then 
					value_ = ПроцедурыОбменаXDTO.AssignToType(value,curSTACK.rule.type,,); 
				endif;
				if curSTACK.NameProperty<>"" then  
					if iMess>0 then //DEBUG
						iMess =iMess - 1;
						message("         text["+curSTACK.name+"]  pointer="+preSTACK.pointer+"["+curSTACK.NameProperty+"]");
					endif;
					try
						if typeOf(value_) = type("number") then
							curSTACK.pointer[curSTACK.NameProperty] = value_;    
						else	
							curSTACK.pointer[curSTACK.NameProperty] = ?(ValueIsFilled(value_) ,value_,value); 
						endif;
					except
						if iMess>-20 then 
							iMess =iMess - 1;
							message("  "+idxSTACK+"  text["+curSTACK.name+"]  pointer="+preSTACK.pointer+"["+curSTACK.NameProperty+"]");
							message(""+errorInfo().Description);  
						endif;
					endtry;
				endif;
				if curSTACK.rule.property("SetParam",sSetParam) then
					pointer = curSTACK.pointer;
					Execute(sSetParam);
				endif;	
			endif; //curSTACK.rule
		elsif  readXML.NodeType=XMLNodeType.Attribute then
			//для аттрибута все сразу
			if curSTACK.pointer <> undefined then
				rule = Rules[curSTACK.name+"."+readXML.name];
				if rule=undefined then
					rule = Rules[readXML.name];
				endif;
				value = readXML.value;
				if rule.type  <> undefined then
					rule.Property("FindProperty",sFindProperty);
					value = ПроцедурыОбменаXDTO.AssignToType(value, rule.type,,sFindProperty);
				endif;	
				if rule.name<>"" then
					curSTACK.pointer[rule.name] = value;
				endif;
				if rule.Property("SetParam",sSetParam) then
					pointer = curSTACK.pointer;
					Execute(sSetParam);
				endif;	
			endif;
		else
			
		endif;	
	endDo;
	
endprocedure

//Посылка запроса POST.XHTML
//
function POSTxml(textXML, baseURL,resourceURL, login, pass, headers=undefined) export
	connect  = new HTTPConnection(baseURL,,login,pass);
	if headers=undefined then
		headers = new Map;
	endif;
	headers.insert("Content-Type","application/x-www-form-urlencoded");
	
	httpReq  = new HTTPRequest(resourceURL,headers);
	XML = "xml=";
	XML = XML + comUrlEncode(textXML); //<-
	httpReq.SetBodyFromString(XML,TextEncoding.ANSI);  //  httpReq.GetBodyAsString();
	responce = connect.Post(httpReq);	
	responceXML = responce.GetBodyAsString();
	
	return responceXML;
endfunction	

//Посылка запроса POST
//  textBody  в кодировке UTF8
//
function POST(textBody, baseURL,resourceURL, login, pass, headers=undefined, ssl=undefined) export
	connect  = new HTTPConnection(baseURL,,login,pass,,,ssl);
	if headers=undefined then
		headers = new Map;
	endif;
	//headers.insert("Content-Type","application/x-www-form-urlencoded");
	
	httpReq  = new HTTPRequest(resourceURL,headers);
	
	httpReq.SetBodyFromString(textBody, TextEncoding.UTF8);  //  httpReq.GetBodyAsString();
	responce     = connect.Post(httpReq);	
	responceText = responce.GetBodyAsString();
	
	return responceText;
endfunction

function GET(textBody,baseURL,resourceURL, login, pass, headers=undefined, ssl=undefined) export 
	connect  = new HTTPConnection(baseURL,,login,pass,,,ssl);
	if headers=undefined then
		headers = new Map;
	endif;
	headers.insert("Content-Type","application/x-www-form-urlencoded");
	
	httpReq  = new HTTPRequest(resourceURL,headers);
    httpReq.SetBodyFromString(textBody,TextEncoding.UTF8);
	responce = connect.Get(httpReq);
	
	//if responce.StatusCode = 301 then    //moved permamently  Location=
	//elsif responce.StatusCode = 405 then // не тот запрос     Allow=
	//endif;	
	
	responceXML = responce.GetBodyAsString(); //HTTPResponse  "UTF-8"
	
	headers = responce.Headers;
	
	return responceXML;
endfunction	
