///////////////////////////////////////////////////////////////////////////
// design by GRish!                                         22/04/2019
//
//  Сопоставление дел и платежных поручений с созданием документов КассовыйЧек
//
//
//


//получим список платежек
//
function GetListPP(dateBegin, dateEnd) export
	query = new query;
	query.Text = 
	"SELECT
	|	t.Ref AS ПлатежноеПоручение,
	|	t.Сумма AS Сумма
	|FROM
	|	Document.ПлатежноеПоручение  AS t
	|WHERE
	|	NOT t.Обработано
	|	AND NOT t.СводныйПлатеж
	|	AND NOT t.DeletionMark
	|//dataB	AND t.Date >= &dateBegin
	|//dataE    AND t.Date <= &dateEnd
	|";
	
	if ValueIsFilled(dateBegin) then
		query.Text = StrReplace(query.Text,"//dataB","");
		query.SetParameter("dateBegin",dateBegin);
	endif;	
	if ValueIsFilled(dateEnd) then
		query.Text = StrReplace(query.Text,"//dataE","");
		query.SetParameter("dateEnd",dateEnd);
	endif;	
	
	tbl = query.Execute().Unload();
	
	return  tbl.UnloadColumn("ПлатежноеПоручение");
	
endfunction	

//получим список дел
//
//результат
//  array   -  {Дело,Сумма,СуммаНДС} где суммы неоплаченный остаток
function GetListDelo(dateBegin, dateEnd) export
	list = new array;
	
	query = new query;
	query.Text = "SELECT
	|	t.Ref AS Дело,
	|	SUM(c.Сумма) AS Сумма,
	|	SUM(c.СуммаНДС) AS СуммаНДС
	|INTO docs	
	|FROM
	|	Document.Договор  AS t
	|	LEFT JOIN Document.Договор.Квитанции AS c
	|      ON t.Ref = c.Ref
	|WHERE
	|	NOT t.DeletionMark
	|//dataB	AND t.Date >= &dateBegin
	|//dataE    AND t.Date <= &dateEnd
	|
	|GROUP BY
	|  t.Ref
	|
	|INDEX BY Дело
	|;
	|SELECT 
	|	t.Дело AS Дело,
	|	t.Сумма - SUM(p.Сумма) AS Сумма,
	|	t.СуммаНДС - SUM(p.СуммаНДС) AS СуммаНДС
	|FROM 
	|	docs As t
	|	LEFT JOIN Document.ПлатежноеПоручение As p
	|		ON t.Дело = p.Договор
	|			AND NOT p.DeletionMark
	|GROUP BY
	|	t.Дело, 
	|	t.Сумма, 
	|	t.СуммаНДС
	|";
	
	if ValueIsFilled(dateBegin) then
		query.Text = StrReplace(query.Text,"//dataB","");
		query.SetParameter("dateBegin",dateBegin);
	endif;	
	if ValueIsFilled(dateEnd) then
		query.Text = StrReplace(query.Text,"//dataE","");
		query.SetParameter("dateEnd",dateEnd);
	endif;	
	
	//tbl = query.Execute().Unload();
	//return  tbl.UnloadColumn("Дело"):
	cursor = query.Execute().Select();
	While cursor.Next() do
		list.Add(new structure("Дело,Сумма,СуммаНДС", cursor.Дело, cursor.Сумма, cursor.СуммаНДС));
	endDo;	
	
	return list;
endfunction	

//сопоставляем платежки и дела(счета)
//   
//
function GetCollateList(listPP) export
	mCollate = new map; //[ПП] -> {Дело} к которому соотнесена платежка
	mDelo    = new map; //[Дело] -> {+ПП.Сумма}
	overPay  = new map; //переплата
	list     = new array;
	
	// пытаемся сопоставить по разным условиям
	// + список всех пп отобранных по периоду
	query = new query;
	query.Text = 
	"ВЫБРАТЬ
	|	1 КАК idQuery,
	|	t.Ссылка КАК ПлатежноеПоручение,
	|	d.Ссылка КАК Дело
	|ИЗ
	|	Документ.ПлатежноеПоручение КАК t
	|		ВНУТРЕННЕЕ СОЕДИНЕНИЕ Документ.Договор КАК d
	|		ПО t.Договор = d.Ссылка
	|ГДЕ
	|	НЕ t.Обработано
	|	И НЕ t.ПометкаУдаления
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	2,
	|	t.Ссылка,
	|	d.Ссылка
	|ИЗ
	|	Документ.ПлатежноеПоручение КАК t
	|		ВНУТРЕННЕЕ СОЕДИНЕНИЕ Документ.Договор КАК d
	|		ПО t.Плательщик = d.Контрагент
	|			И t.Сумма <= d.Сумма
	|ГДЕ
	|	НЕ t.Обработано
	|	И НЕ t.ПометкаУдаления
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	3,
	|	t.Ссылка,
	|	NULL
	|ИЗ
	|	Документ.ПлатежноеПоручение КАК t
	|ГДЕ
	|	НЕ t.Обработано
	|	И НЕ t.ПометкаУдаления
	|	И t.Ссылка В(&listPP)
	|
	|УПОРЯДОЧИТЬ ПО
	|	idQuery,
	|	ПлатежноеПоручение,
	|	Дело";
	
	query.SetParameter("listPP", listPP);
	
	// заполняем таблицу, повторные строки с ПП отбрасываються (idQuery 1 -> 2 -> 3)
	cursor = query.Execute().Select();
	While cursor.Next() do
		docDelo = mCollate[cursor.ПлатежноеПоручение]; //[ПП] -> {Дело}
		if docDelo=undefined then
			if ValueIsFilled(cursor.Дело)  then
				SumD = ?( mDelo[cursor.Дело]<>undefined, mDelo[cursor.Дело], 0); 
				if SumD < cursor.Дело.Сумма or cursor.idQuery = 1 then
					mCollate[cursor.ПлатежноеПоручение] = cursor.Дело;
					SumD = SumD + cursor.ПлатежноеПоручение.Сумма; 
					mDelo[cursor.Дело] = SumD;
					list.Add(new structure("Дело,ПлатежноеПоручение,overPay",cursor.Дело,cursor.ПлатежноеПоручение,false));
					if SumD>cursor.Дело.Сумма then
						overPay.Insert(cursor.Дело, true);
					endif;	
				endif; 
			else
				list.Add(new structure("Дело,ПлатежноеПоручение,overPay",undefined,cursor.ПлатежноеПоручение,false));
				mCollate[cursor.ПлатежноеПоручение]=Документы.Договор.emptyRef();
			endif;
		endif;	
	endDo;
	
	for each a in list do
		if overPay[a.Дело] = true then
			a.overPay = true;
		endif;
	endDo;
	
	return list;
endfunction


