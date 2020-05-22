

procedure ЗаполнитьСправочникНДС() export
	
	SetParamsНДС(Справочники.НДС.none,  0,  false);	
	SetParamsНДС(Справочники.НДС.vat0,  0,  true);	
	SetParamsНДС(Справочники.НДС.vat10, 10, true);	
	SetParamsНДС(Справочники.НДС.vat110,10, true, 110);	
	SetParamsНДС(Справочники.НДС.vat118,18, true, 180);	
	SetParamsНДС(Справочники.НДС.vat18, 18, true);	
	SetParamsНДС(Справочники.НДС.vat20, 20, true);	
	
endprocedure	

procedure SetParamsНДС(ref, persent, use, delitel = 1)
	objНДС = ref.GetObject();
	objНДС.процентНДС   = persent;
	objНДС.Делитель     = delitel;
	objНДС.Рассчитывать = use;
	
	objНДС.Write();
endprocedure	