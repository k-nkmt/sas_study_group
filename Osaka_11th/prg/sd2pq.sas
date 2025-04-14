/* 
This draft is intended for educational or testing purposes only. 
Please refer to https://github.com/k-nkmt/sas_study_group/blob/main/Osaka_11th/README.md before using this code.
*/

%macro pq_schema(table, libref = work, outpath = temp) ;
/*
  Generates a Parquet schema (excluding the row group part) for a given SAS dataset as a hexadecimal string.

  Parameters:
  - table: The name of the dataset for which the schema is to be generated.
  - libref: The library reference where the dataset is located. Default is 'work'.
  - outpath: The output file path where the schema will be written. Default is temp.
            If changed, the schema will be written with line breaks every 16 bytes.
            
*/

  filename _schema temp ;
  data _null_ ;
    file _schema ;
    
    dsid= open("&libref..&table.") ;
    nvars = attrn(dsid, "NVARS") ;
    call symputx("nvars", nvars) ;
    nobs = attrn(dsid, "NOBS") ;

    call symputx("n_schema", lencode(nvars+1, "C")) ;
    call symputx("nvars_encode", encode(nvars, "N")) ; 
  
    do i = 1 to nvars; 
      call symputx(cats("varname", i), varname(dsid, i)) ;
      call symputx(cats("vartype", i), vartype(dsid, i)) ;
    end ;
    rc = close(dsid) ;
  run ;

  filename _vcolumn temp ;

  %do i = 1 %to &nvars. ;
    data _null_ ;
      %if &&vartype&i. = N %then %do ;
        call symputx("type_hex", "0A") ;
        call symputx("convert_hex", "") ;
      %end ;
      %else %if &&vartype&i. = C %then %do ;
        call symputx("type_hex", "0C") ;
        call symputx("convert_hex", "2500") ;
      %end ;
  
     call symputx("col_hex", cats(encode(lengthn("&&varname&i."), "C"), put("&&varname&i.", $hex.) ) ) ;
    run ;
        
    proc stream outfile = _vcolumn mod ;
begin &streamdelim.;
15&type_hex.250218&col_hex.&convert_hex.00
;;;;
    run ;
  %end ;

  proc stream outfile = _schema ;
begin &streamdelim.;
150419&n_schema.35001806736368656D6115&nvars_encode.00
&streamdelim. readfile _vcolumn ;
;;;;
  run ;

  %if &outpath. ^= temp %then %do ;
    filename _outref "&outpath." ;
    %textout(_schema, _outref) ;
    filename _outref clear ;
    filename _schema clear ; 
  %end ;
  
  filename _vcolumn clear ;
%mend ;

%macro pq_rgroups(table, libref = work, outpath1 = temp, outpath2 = temp) ;
/*
  Generates a Parquet row groups part(page and schema) for a given SAS dataset as a hexadecimal string.

  Parameters:
  - table: The name of the SAS dataset to process.
  - libref: The library reference where the dataset is located (default is 'work').
  - outpath1: The output file path for the row group of page (default is temp).
  - outpath2: The output file path for the row group of schema (default is temp).

  Note:
    Uses %pq_valid and %pq_value.

*/

  filename _rvalue temp lrecl = 1000000000 ;
  filename _rfooter temp ;
  filename _page temp lrecl = 1000000 ;
  
  data _null_ ;    
    dsid= open("&libref..&table.") ;
    nvars = attrn(dsid, "NVARS") ;
    call symputx("nvars", nvars) ;
    nobs = attrn(dsid, "NOBS") ;
    call symputx("nobs_encode", encode(nobs, "N")) ; 
    do i = 1 to nvars; 
      call symputx(cats("varname", i), varname(dsid, i)) ;
      call symputx(cats("vartype", i), vartype(dsid, i)) ;
    end ;
    rc = close(dsid) ;
  run ;

  %let offset = 4 ;
  
  %do i = 1 %to &nvars. ;
    data _null_ ;
      file _page ;
      dsid= open("&libref..&table.") ;
      nobs = attrn(dsid, "NOBS") ;
      size = 0 ;
      length valid_bit $8 val $32767 ;
      %if &&vartype&i. = N %then %do ;
        %pq_valid(type = N) ;
        %pq_value(type = N) ;
        call symputx("type_hex", "0A") ;
      %end ;
      %else %if &&vartype&i. = C %then %do ;
        %pq_valid(type = C) ;
        %pq_value(type = C) ;
        call symputx("type_hex", "0C") ;
      %end ;
       rc = close(dsid) ;
     call symputx("col_hex", cats(encode(lengthn("&&varname&i."), "C"), put("&&varname&i.", $hex.))) ;
     call symputx("size_encode", encode(size, "N")) ;
     psize = size + 14 + lengthn(encode(size, "N")) /* /2*2 */ + lengthn("&nobs_encode.")/2 ;
     call symputx("psize_encode", encode(psize, "N")) ;
     offset = input(symget("offset"), best.) ;
     call symputx("offset_encode", encode(offset, "N")) ;
     call symputx("offset", offset + psize) ; 

    run ;
        
    proc stream outfile = _rvalue mod ;
begin &streamdelim.;
150015&size_encode.15&size_encode.2C
15&nobs_encode.1500150615060000
&streamdelim. readfile _page ; 
;;;;
    run ;
    
    proc stream outfile = _rfooter mod ;
begin &streamdelim.;
26001C15&type_hex.192506001918
&col_hex.
150016&nobs_encode.16&psize_encode.16&psize_encode.
26&offset_encode.0000
;;;;
    run ;

  %end ;

  %if &outpath1. ^= temp %then %do ;
    filename _outref "&outpath1." lrecl = 1000000000 ;
    %textout(_rvalue, _outref) ;
    filename _outref clear ;
    filename _rvalue clear ; 
  %end ;
  %if &outpath2. ^= temp %then %do ;
    filename _outref "&outpath2." ;
    %textout(_rfooter, _outref) ;
    filename _outref clear ;
    filename _rfooter clear ; 
  %end ;

  filename _page clear ;
%mend ;

%macro sd2pq(table, libref = work, outpath = ) ;
/*
  Converts a SAS dataset into a parquet file format. 

  Parameters:
    - table: The name of the SAS dataset to be converted.
    - libref: The library reference where the dataset is located. Default is 'work'.
    - outpath: The output file path where the Parquet file will be written.

  Note:
    Uses %pq_schema and %pq_rgroups.

*/
  filename _outref "&outpath." lrecl = 1000000000 ;

  %pq_schema(&table., libref = &libref. ) ;
  %pq_rgroups(&table., libref = &libref. ) ;
  %let magic = 50415231 ;
      
  data _null_ ;
    dsid= open("&libref..&table.") ;
    nobs = attrn(dsid, "NOBS") ;
    nvars = attrn(dsid, "NVARS") ;
    rc = close(dsid) ;
  
    pq_id=fopen("_outref", "O", 0, "B") ;
    rvalue_id = fopen("_rvalue") ;
    schema_id = fopen("_schema") ;
    rfooter_id = fopen("_rfooter") ;
     
    length hex $32767 ;
  
    rc = fput(pq_id, input("&magic.", $hex8.) ) ;
  
  /* page */
    rsize = 0 ;
    do while(fread(rvalue_id) = 0) ;
      do while(fget(rvalue_id, hex) = 0) ;
       rsize = rsize + lengthn(hex)/2 ;
       fmt = cats("$hex", lengthn(hex)) ;
       rc = fput(pq_id, inputc(hex, fmt)) ;
      end ;
    end ;
  
  /* footer */
    fsize = 0 ;    
    do while(fread(schema_id) = 0) ;
      do while(fget(schema_id, hex) = 0) ;
       fsize = fsize + lengthn(hex)/2 ;
       fmt = cats("$hex", lengthn(hex)) ;
       rc = fput(pq_id, inputc(hex, fmt)) ;
      end ;
    end;

    hex = cats("16", encode(nobs, "N"), "191C19", lencode(nvars, "C")) ;
    fsize = fsize + lengthn(hex)/2 ;
    fmt = cats("$hex", lengthn(hex)) ;
    rc = fput(pq_id, inputc(hex, fmt) ) ;
        
    do while(fread(rfooter_id) = 0) ;
      do while(fget(rfooter_id, hex) = 0) ;
       fsize = fsize + lengthn(hex)/2 ;
       fmt = cats("$hex", lengthn(hex)) ;
       rc = fput(pq_id, inputc(hex, fmt)) ;
      end ;
    end ;
    
    hex = cats("16", encode(rsize, "N"), "16", encode(nobs, "N"), "000000") ;
    fsize = fsize + lengthn(hex)/2 ;
    fmt = cats("$hex", lengthn(hex)) ;
    rc = fput(pq_id, inputc(hex, fmt) ) ;
       
    rc = fput(pq_id, input(%num2hex(fsize, I), $hex8.)) ;
    rc = fput(pq_id, input("&magic.", $hex8.) ) ;
  
    rc = fwrite(pq_id) ;
    
    rc = fclose(schema_id) ;  
    rc = fclose(rvalue_id) ;
    rc = fclose(rfooter_id) ;    
    rc = fclose(pq_id) ;  
  run ;

  filename _schema clear ;
  filename _rvalue clear ;
  filename _rfooter clear ;
  filename _outref clear ;
  
%mend ;

%macro pq_valid(type= ) ;
/*
  Generates code to produce repetition levels and definition levels.
  Only bit-packing encoding is supported.

  Parameters:
    - type: C for character variables and N for numeric variables.
*/
  rlevel_hex = %num2hex(ceil(nobs/8) + ceil(nobs/(63*8)), I) ;
  put rlevel_hex +(-1) @ ;
  size = size + 4 ;
  
  test = cats(ceil(nobs/8), ceil(nobs/(63*8))) ;
  putlog  test ; 
  
  do j = 1 to nobs ;
    if mod(j, 63*8) = 1 then do ;
      tgt_obs = min(nobs-j, 63*8) ;
      nbit_bin = put(ceil(tgt_obs/8), binary7.) ;  
      val = put(input(cats(nbit_bin ,"1"), binary.), hex2.) ;
      put val @ ;
      size = size + 1 ;
    end ;
  
    rc = fetchobs(dsid, j) ;
      %if &type. = C %then %do ; 
        val = getvarc(dsid, &i.) ;
      %end ;
      %else %if &type. = N %then %do ;
        if not missing(getvarn(dsid, &i.)) then val = "1" ;
        else val = "" ;
      %end ;
      
    valid_bit = cats(not missing(val), valid_bit) ; 

    if j = nobs then valid_bit = cats(repeat("0", 8 - lengthn(valid_bit) -1), valid_bit) ;
    if mod(lengthn(valid_bit), 8) = 0 then do ;
      val = put(input(valid_bit, binary.), hex2.) ;
      put val @ ;
      size = size + 1 ;
      call missing(valid_bit) ;
    end ;
  end ;
  
%mend ;

%macro pq_value(type = ) ;
/*
 Generate code for values.
 
Parameters:
 - type: C for character variable and N for numeric variable.
*/
  
  do j = 1 to nobs ;
    rc = fetchobs(dsid, j) ;
  %if &type. = C %then %do ;
    val = getvarc(dsid, &i.) ;
    if not missing(val) then do ;
      val = cats(%num2hex(lengthn(val), I), put(trim(val), $hex.)) ;
      put val ;
      size = size + lengthn(val)/2 ;
    end ;
  %end ;
  %else %if &type. = N %then %do ;
    valn = getvarn(dsid, &i.) ;
    if not missing(valn) then do ;
      val  = %num2hex(valn, d) ;
      put val ;
      size = size + 8 ;
    end ;
  %end ;
  end ;
%mend ;