/* 
This draft is intended for educational or testing purposes only. 
Please refer to https://github.com/k-nkmt/sas_study_group/blob/main/Osaka_11th/README.md before using this code.
*/

proc fcmp outlib=work.funcs.myfunc ;
  function encode(num, type$) $16 ;
  /*
    Encodes a given number based on the Thrift Varint returns a hexadecimal string.
    
    Parameters:
      - num: The number to be encoded.
      - type: A character string specifying the type of encoding. 
              If encord legth of string, set "C", the number is used as is. 
              Otherwise, the number is multiplied by 2 (zigzag encoding).
    Returns:
      - A hexadecimal string representation of the encoded number.
  */
    if type = "C" then n = num ;
    else n = num * 2 ;
    bit = cats("") ;
    do i = 1 to 8 ;
      n2 = band(n, 7fx);
      n = brshift(n, 7) ;
      bit = cats(n > 0, put(n2, binary7.), bit) ;
      if n = 0 then leave ;
    end ; 
    result = putc(putn(inputn(trim(bit), cats("binary", i*8)), "pibr8"), cats("hex", i*2)) ;
  
    return(result) ;
  endfunc ;
  
  function lencode(num, type $) $18 ;
    /*
    Encodes List based on the Thrift Varint returns a hexadecimal string.
    
    Parameters:
      - num: The number to be encoded.
      - type: Type of element.
    Returns:
      - A hexadecimal string representation of the encoded List.
  */

    if num < 15 then do ;
      result = cats(put(num, hex1.), type) ;
    end ;
    else do ;
      n = num ;
      bit = cats("") ;
      do i = 1 to 8 ;
        n2 = band(n, 7fx);
        n = brshift(n, 7) ;
        bit = cats(n > 0, put(n2, binary7.), bit) ;
        if n = 0 then leave ;
      end ; 
      result = putc(putn(inputn(bit, cats("binary", i*8)), cats("pibr", i *4)), cats("hex", i*2)) ;
      result = cats("F", type, result) ;
    end ;
    return(result) ;
  endfunc ;
  
  /* 
  function num2hex(num, type $) $16 ;
    select(type) ;
      when("I") fmt = "pibr4" ;
      when("i") fmt = "ibr4" ;
      when("Q") fmt = "pibr8" ;
      when("q") fmt = "ibr8" ;
      when("d") fmt = "rb8" ;
      otherwise return("") ;
    end ;
    hex = put(putn(num, fmt), hex.) ;
    return(hex) ;
  endfunc ; 
  */
run ;

options cmplib=work.funcs ;

%macro num2hex(var, type) ;
/*
  return put functin to converts a numeric variable to its hexadecimal representation in little endian.
  
  Parameters:
  - var: The numeric variable to be converted.
  - type: The type of numeric variable, which determines the format to be used.
          The valid types are:
          - I: Positive Integer (4 bytes)
          - i: Integer (4 bytes)
          - Q: Positive Integer (8 bytes)
          - q: Integer (8 bytes)
          - d: Double (8 bytes)
  Example:
  - %num2hex(a, I) >>> put(put(a, pibr4), hex.)

  Note:
    FCMP function num2hex is not works as expected.;
 */

  %let typelist = IiQqd ;
  %let fmtlist  = pibr4 ibr4 pibr8 ibr8 rb8 ;  
  %let fmt = %scan(&fmtlist., %index(&typelist., &type.)) ;

/*  return  */
  put(put(&var., &fmt..), hex.) 
%mend ;

%macro textout(inref, outref) ;
/*
  Write the contents of the input file to the output file in text format with line break by 16byte.
  Parameters:
  - inref: The input file reference.
  - outref: The output file reference.

  Example:
  filename in "input.txt" ;
  filename out "output.txt" ;
  %textout(in, out) ;
*/  
  data _null_ ;
    in_id = fopen("&inref.") ;
    out_id = fopen("&outref.", "O") ;
     
    length line hex $32767 ;

    do while(fread(in_id) = 0) ;
      do while(fget(in_id, hex) = 0) ;
        line = cats(line, hex) ;
        pos = lengthn(line) ;
       
        if pos = 32 then do ;
          rc = fput(out_id, trim(line)) ;
          rc = fwrite(out_id) ;
          line = "" ;
          pos = 0 ;
        end ;
        else if pos > 32 then do ;
          do i = 1 to pos by 32 ;
            rc = fput(out_id, trim(substr(line, 1, 32))) ;
            rc = fwrite(out_id) ;
            if lengthn(line) = 32 then line = "" ;
            else do ;
              line = substr(line, i+32) ;
              if lengthn(line) < 32 then leave ;
            end ;
          end ;
          pos = mod(pos, 32) ;
        end ;
      end ;
    end ;
    
    if pos > 0 then do ;
      rc = fput(out_id, trim(line)) ;
      rc = fwrite(out_id) ;
    end ;
    
    rc = fclose(in_id) ;
    rc = fclose(out_id) ;  
  run ;
%mend ;