//////////////////////////////////////////////////////////////////////////////////
// Design by GRish!                                                   01/04/2019 
//                                     
//   Серверные процедуры и функции общего назначения:     online cashbox
//
//



//получисть имя метаданных для значения перечисления
//
function ПолучитьНаименованиеЗначенияПеречисления(value) export
	meta  = value.Metadata(); 
	enum_ = enums[meta.name];
	for each v in meta.EnumValues do
		if enum_[v.Name] = value  then
			return v.Name;
		endif;	
	endDo;
	return value;
endfunction

//получисть порядковый номер значения перечисления
//  нумерация с 1
function ПолучитьПорядковыйНомерЗначенияПеречисления(value) export
	meta  = value.Metadata(); 
	enum_ = enums[meta.name];
	idx = 1;
	for each v in meta.EnumValues do
		if enum_[v.Name] = value  then
			Value = v.Name;
			return idx;
		endif;	
		idx = idx + 1; 
	endDo;
	return 0;
endfunction

////////////////////////////////////////////////////
//
//

