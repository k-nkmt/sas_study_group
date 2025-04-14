/* 
This draft is intended for educational or testing purposes only. 
Please refer to https://github.com/k-nkmt/sas_study_group/blob/main/Osaka_11th/README.md before using this code.
*/

%macro ipc_schema(table, libref = work, outpath = temp) ;
/*
  Generates a Arrow IPC schema for a given SAS dataset as a hexadecimal string.

  Parameters:
  - table: The name of the SAS table for which the schema is to be generated.
  - libref: The library reference where the table is located. Default is 'work'.
  - outpath: The output file path where the schema will be written. Default is temp.
             If changed,  the schema will be written with line breaks every 16 bytes.
*/
  filename _schema temp ;
  
  data _null_ ;
    dsid = open("&libref..&table.") ;
    nvars = attrn(dsid, "NVARS") ;
    call symputx("nvars", nvars) ;
    call symputx("nobs",  attrn(dsid, "NOBS")) ;
  
    do i = 1 to nvars; 
      call symputx(cats("varname", i), varname(dsid, i)) ;
      call symputx(cats("vartype", i), vartype(dsid, i)) ;
    end ;
    rc = close(dsid) ;
  run ;

  filename _vcolumn temp ;
  %let field_offsets = ;
  %let fields_len = 0 ;

  %do i = 1 %to &nvars. ;
    data _null_ ;
      %if &&vartype&i. = N %then %do ;
        call symputx("type_id", "03") ;
        type_vlen = 8 ;
        call symputx("type_hex", "0000060008000600 0600000000000200") ;
      %end ;
      %else %if &&vartype&i. = C %then %do ;
        call symputx("type_id", "05") ;
        type_vlen = 4 ;
        call symputx("type_hex", "0400040004000000") ;
      %end ;
  
      repeat = 8 - mod(lengthn("&&varname&i."), 8) ;
      pad = ifc(repeat > 0, repeat("00", repeat-1), "") ;
      call symputx("name_hex", cats(put("&&varname&i.", $hex.), pad)) ;
      
      name_len = lengthn("&&varname&i.") ;
      call symputx("name_len_hex", %num2hex(name_len, I)) ;
      call symputx("offset_to_type", %num2hex(16 + name_len + repeat + type_vlen, I)) ; 
  
      pos = 16 + 4 * (&nvars.+ 1 - &i. ) + &fields_len. ;
   
      call symputx("fields_len", &fields_len. + 44 + name_len + repeat + type_vlen * 2) ;
      call symputx("field_offset", %num2hex(pos, I)) ;
    run ;
  
    %let field_offsets = &field_offsets. &field_offset. ;
      
    proc stream outfile = _vcolumn mod ;
begin &streamdelim.;
1000140008000600 07000C0000001000
10000000000001&type_id. 10000000&offset_to_type.
0400000000000000 &name_len_hex.&name_hex.
&type_hex.
;;;;
    run ;
  %end ;

  data _null_ ;
    call symputx("schema_len_hex", %num2hex(48 + 4 * &nvars. + &fields_len., I)) ;
    call symputx("nvars_hex", %num2hex(&nvars., I));
  run ;

  proc stream outfile = _schema ;
begin &streamdelim.;
FFFFFFFF&schema_len_hex.
1000000000000A00 0C00060005000800
0A00000000010400 0C00000008000800
0000040008000000 04000000&nvars_hex.
&field_offsets.
&streamdelim. readfile _vcolumn ;
;;;;
  run ;

  %if &outpath. ^= temp %then %do ;
    filename _outref "&outpath."  ;
    %textout(_schema, _outref) ;
    filename _outref clear ;
    filename _schema clear ; 
  %end ;
  
  filename _vcolumn clear ; 
%mend ;


%macro ipc_rbatch(table, libref = work, outpath = temp) ;
/*
  Generates a Arrow IPC record batch for a given SAS dataset as a hexadecimal string.
  
  Parameters:
    - table: The name of the SAS dataset to process.
    - libref: The library reference where the dataset is located (default is 'work').
    - outpath: The output file path for the output record batch file (default is temp).

  Note:
    Uses %ipc_valid, %ipc_offset, and %ipc_value.
*/
  filename _rbatch temp lrecl = 1000000000 ;
  filename _values temp lrecl = 1000000 ;

  data _null_ ;
    file _values ;
    
    length valid_bit $8 pad $16 val node_list buffer_list $32767 ;
    
    dsid= open("&libref..&table.") ;
    nvars = attrn(dsid, "NVARS") ;
    call symputx("nvars", nvars) ;
    nobs = attrn(dsid, "NOBS") ;
    
    call symputx("nobs_hex", %num2hex(nobs, Q)) ;
    
    n_buffer = 0 ;
    body_pos = 0 ;
    node_list = %num2hex(nvars, I) ;
    
    do i = 1 to nvars ;
      type = vartype(dsid, i) ;
    
      if type = "C" then do ;
        n_buffer = n_buffer + 3 ;
        %ipc_valid(type = C) ;
        %ipc_offset ;
        %ipc_value(type = C) ;
      end ;
      else if type ="N" then do ;
        n_buffer = n_buffer + 2 ;
        %ipc_valid(type = N) ;
        %ipc_value(type = N) ;
      end ;  
    end ;
    
    buffer_list = catx(" ", %num2hex(n_buffer, I), buffer_list) ;

    call symputx("node_list", node_list) ;
    call symputx("buffer_list", buffer_list) ;
    call symputx("body_len", %num2hex(body_pos, Q)) ;
    
    meta_len = 80 + lengthn(compress(node_list))/2 + lengthn(compress(buffer_list))/2  ;
    call symputx("meta_len_hex", %num2hex(meta_len, I)) ;
    to_nodes = 20 + lengthn(compress(buffer_list))/2  + 4 ;
    call symputx("to_nodes_hex", %num2hex(to_nodes, I)) ;

    rc=close(dsid) ;
  run ;

  proc stream outfile = _rbatch ;
begin &streamdelim.;
FFFFFFFF&meta_len_hex.
1400000000000000 0C00160006000500
08000C000C000000 0003040018000000
&body_len. 00000A0018000C00
040008000A000000
&to_nodes_hex. 10000000&nobs_hex.
00000000&buffer_list.
00000000&node_list. 
&streamdelim. readfile _values ;
;;;;
  run ;

  %if &outpath. ^= temp %then %do ;
    filename _outref "&outpath." lrecl = 1000000000 ;
    %textout(_rbatch, _outref) ;
    filename _outref clear ;
    filename _rbatch clear ; 
  %end ;
  
  filename _values clear ;
%mend ;


%macro sd2IPC(table, libref = work, outpath = ) ;
/*
  Converts a SAS dataset to an Arrow IPC(Feather v2) format file.
  
  Parameters:
    - table: The name of the SAS dataset to be converted.
    - libref: The library reference where the dataset is located (default is 'work').
    - outpath: The output file path for the IPC file.

  Note:
    Uses %ipc_schema and %ipc_rbatch.
*/
  filename _outref "&outpath." lrecl = 1000000000 ;
  %ipc_schema(&table., libref = &libref.  ) ;
  %ipc_rbatch(&table., libref = &libref. ) ;

  %let magic = 4152524F5731 ;

  data _null_ ;
    ipc_id=fopen("_outref", "O", 0, "B") ;
    schema_id = fopen("_schema") ;
    rbatch_id = fopen("_rbatch") ;
     
    length hex $32767 ;
    rc = fput(ipc_id, input("&magic.0000", $hex16.) ) ;
  
  /* schema */
    schema_len = 0 ;
    do while(fread(schema_id) = 0) ;
      do while(fget(schema_id, hex) = 0) ;
       schema_len = schema_len + lengthn(hex)/2 ;
       fmt = cats("$hex", lengthn(hex)) ;
       rc = fput(ipc_id, inputc(hex, fmt)) ;
      end ;
    end ;
  
  /* recodbatch */
    rbatch_len = 0 ;
    do while(fread(rbatch_id) = 0) ;
      do while(fget(rbatch_id, hex) = 0) ;
       rbatch_len = rbatch_len + lengthn(hex)/2 ;
       if rbatch_len = 48 then body_len_hex = hex ;
       fmt = cats("$hex", lengthn(hex)) ;
       rc = fput(ipc_id, inputc(hex, fmt)) ;
      end ;
    end;
    
    offset_body = rbatch_len - input(input(body_len_hex, $hex16.), pibr8.) ;

  /* footer */
    rc = fput(ipc_id, input("FFFFFFFF00000000100000000c001400", $hex32.)) ;
    rc = fput(ipc_id, input("060008000C0010000C00000000000400", $hex32.)) ;
    rc = fput(ipc_id, input("34000000240000000400000001000000", $hex32.)) ;
  
    hex = cats(%num2hex(schema_len + 8, Q), %num2hex(offset_body, Q)) ;
    rc = fput(ipc_id, input(hex, $hex32.)) ;
    rc = fput(ipc_id, input(cats(body_len_hex, "00000000" ), $hex24.)) ;
   
    rc = frewind(schema_id) ;
    column_len = 0 ;
    readfl = 0 ;
    do while(fread(schema_id) = 0 ) ;
      do while (fget(schema_id, hex) = 0) ;
       if hex = "0C00000008000800" then do ;
         readfl = 1 ;
         hex = "08000800" ;
       end ;
       if readfl = 0 then continue ;
       
       column_len = column_len + lengthn(hex)/2 ;
       fmt = cats("$hex", lengthn(hex)) ;
       rc = fput(ipc_id, inputc(hex, fmt)) ;
       rc = fwrite(ipc_id) ;
      end ;
    end ;
    
    rc = fput(ipc_id, input(%num2hex(68 + column_len, I), $hex8.)) ;
    rc = fput(ipc_id, input("&magic.", $hex12.) ) ;
  
    rc = fwrite(ipc_id) ;
    
    rc = fclose(schema_id) ;  
    rc = fclose(rbatch_id) ;
    rc = fclose(ipc_id) ;  
  run ;

  filename _schema clear ;
  filename _rbatch clear ;
  filename _outref clear ;
%mend ; 

%macro ipc_valid(type= ) ;
/*
  Generate code to produce a validity bit for the body of the record batch.

  Parameters:
    - type: C for character variables and N for numeric variables.
    
*/

  null_count = 0 ;
  buffer_len = 0 ;
  repeat = 0 ;
  
  do j = 1 to nobs ;
    rc = fetchobs(dsid, j) ;
      %if &type. = C %then %do ; 
        val = getvarc(dsid, i) ;
      %end ;
      %else %if &type. = N %then %do ;
        if not missing(getvarn(dsid, i)) then val = "1" ;
        else val = "" ;
      %end ;
      
    valid_bit = cats(not missing(val), valid_bit) ; 
    null_count = null_count + missing(val) ;
    if j = nobs then valid_bit = cats(repeat("0", 8 - lengthn(valid_bit) -1), valid_bit) ;
    if mod(lengthn(valid_bit), 8) = 0 then do ;
      val = put(input(valid_bit, binary.), hex2.) ;
      put val +(-1) @ ;
      buffer_len = buffer_len + 1 ;
      call missing(valid_bit) ;
    end ;
  end ;
  if mod(buffer_len, 8) ^= 0 then do ;
    repeat = 8 - mod(buffer_len, 8)  ;
    pad = repeat("00", repeat -1) ;   
    put pad ;    
  end ;
    
  node_list = catx( " ", node_list, %num2hex(nobs, Q), %num2hex(null_count, Q)) ;
  buffer_list = catx(" ", buffer_list, %num2hex(body_pos, Q), %num2hex(buffer_len, Q)) ;
  body_pos = body_pos + buffer_len + repeat ;
%mend ;


%macro ipc_offset ;
/*
  Generate code to produce offset values for the body of the record batch.
*/

  offset = %num2hex(0, I) ; 
  put offset @ ;
  buffer_len = 4 ;
  buffer_pos = 0 ;
  repeat = 0 ;

  do j = 1 to nobs ;
    rc = fetchobs(dsid, j) ;
    val = getvarc(dsid, i) ; 
    buffer_len = buffer_len + 4 ;
    buffer_pos = buffer_pos + lengthn(val) ;
    offset = %num2hex(buffer_pos, I) ;   
    put offset ;
  end ;
  if mod(nobs, 2) = 0 then do ;
    repeat = 4 ;
    pad = repeat("00", repeat -1) ;   
    put pad ;
    buffer_len = buffer_len ;
  end ;
  
  buffer_list = catx(" ", buffer_list, %num2hex(body_pos, Q), %num2hex(buffer_len, Q)) ;
  body_pos = body_pos + buffer_len + repeat ;
%mend ;


%macro ipc_value(type = ) ;
/*
  Generate code to produce values for the body of the record batch.

Parameters:
 - type: C for character variable and N for numeric variable.
*/

  buffer_len = 0 ;
  repeat = 0 ;
  
  do j = 1 to nobs ;
    rc = fetchobs(dsid, j) ;
  %if &type. = C %then %do ;
    val = getvarc(dsid, i) ;
    buffer_len = buffer_len + lengthn(val) ;
    if not missing(val) then val = put(trim(val), $hex.) ;
  %end ;
  %else %if &type. = N %then %do ;
    valn = coalesce(getvarn(dsid, i), 0) ;
    buffer_len = buffer_len + 8 ;
    val  = %num2hex(valn, d) ;
  %end ;
    put val ;
  end ;
  if mod(buffer_len, 8) ^= 0 then do ;
    repeat = 8 - mod(buffer_len, 8)  ;
    pad = repeat("00", repeat -1) ;   
    put pad @ ;        
  end ;
  buffer_list = catx(" ", buffer_list, %num2hex(body_pos, Q), %num2hex(buffer_len, Q)) ;
  body_pos = body_pos + buffer_len + repeat ;
%mend ;