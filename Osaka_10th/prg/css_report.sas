/* 
    Examplees of PROC REPORT with CSS
*/

%let root = xxx/prg ;
/* Original code and dataset (out.sas7bdat) from https://www.sas.com/content/dam/SAS/ja_jp/doc/event/sas-user-groups/usergroups2017-b-11-02.pdf  */

libname sample.out "&root./data" access = readonly ;

* Original Code **************************************************************************************************;
* filename out "&root./report/report_original.rtf" ;
/*
options nodate nonumber papersize = "A4" orientation = portrait topmargin = 3cm bottommargin = 3cm leftmargin = 2.5cm rightmargin= 2.5cm ;
ods escapechar = '~';

* ユーザー定義スタイルテンプレート未使用 ********************************************************************************************;
* タイトル・フットノートの指定（位置、色、フォント、サイズ、テキスト）*;
title1 '~S={just=left background=white foreground=black font=("Courier New", 8pt)}Table 9.9.9 Subgroup Analysis, MMRM for Percent Change
from Baseline in VAS by Age Group' ;
title2 '~S={just=left background=white foreground=black font=("Courier New", 8pt)}Full Analysis Set' ;
footnote1 '~S={just=right background=white foreground=black font=("Courier New", 8pt)}Page ~{pageof}' ;
* RTF出力開始 ;
ods rtf file = out notoc_data style = Styles.Default ;
* REPORTプロシジャ *;
proc report data = sample.out missing split = '|' spanrows
  style(report) ={just=left bordercolor=black borderstyle=solid borderwidth=1pt
    background=white foreground=black frame=hsides rules=groups cellpadding=0 cellspacing=0}
  style(header) ={asis=on vjust=bottom background=white foreground=black font=('Courier New', 8pt)}
  style(column) ={asis=on vjust=top background=white foreground=black font=('Courier New', 8pt)}
  style(lines) ={asis=on just=left vjust=top background=white foreground=black font=('Courier New', 8pt)
    borderbottomstyle=none} 
  ;
  column AGEGR1N AGEGR1X TRT_VISITN TRT_VISIT LSMEAN SE
    ("~S={just=center borderbottomwidth=1pt}95% CI~{super[a]}" LOWER UPPER)
    ("~S={just=center borderbottomwidth=1pt}Comparison to Placebo" C_LSMEAN C_SE
    ("~S={just=center borderbottomwidth=1pt}95% CI~{super[a]}" C_LOWER C_UPPER)) _LINE_IND 
  ;
  
  define AGEGR1N / order noprint ;
  define AGEGR1X / order style(column)={just=left cellwidth=1.6cm} style(header)={just=left} 'Age' ;
  define TRT_VISITN / order noprint ;
  define TRT_VISIT / style(column)={just=left cellwidth=2.6cm} style(header)={just=left } 'Treatment|Visit' ;
  define LSMEAN / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'LS Mean' ;
  define SE / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'SE';
  define LOWER / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'Lower';
  define UPPER / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'Upper';
  define C_LSMEAN / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'LS Mean' ;
  define C_SE / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'SE';
  define C_LOWER / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'Lower';
  define C_UPPER / style(column)={just=center cellwidth=1.4cm} style(header)={just=center} 'Upper';
  define _LINE_IND / display noprint ;
  
  compute _LINE_IND ;
    if _LINE_IND = 10 then call define('AGEGR1X' , 'style', 'style=[borderbottomwidth=1pt]') ;
    if _LINE_IND = 1 then call define('TRT_VISIT', 'style', 'style=[marginleft=0.4cm]') ;
    if _LINE_IND = 21 then do ;
      call define('TRT_VISIT', 'style', 'style=[borderbottomwidth=1pt marginleft=0.4cm]') ;
      call define('LSMEAN' , 'style', 'style=[borderbottomwidth=1pt]'); 
      call define('SE' , 'style', 'style=[borderbottomwidth=1pt]') ;
      call define('LOWER' , 'style', 'style=[borderbottomwidth=1pt]'); 
      call define('UPPER' , 'style', 'style=[borderbottomwidth=1pt]') ;
      call define('C_LSMEAN', 'style', 'style=[borderbottomwidth=1pt]'); 
      call define('C_SE' , 'style', 'style=[borderbottomwidth=1pt]') ;
      call define('C_LOWER', 'style', 'style=[borderbottomwidth=1pt]'); 
      call define('C_UPPER', 'style', 'style=[borderbottomwidth=1pt]') ;
    end ;
  endcomp;
  compute after _page_ ;
    line '[a] 95% confidence interval' ;
  endcomp ;
run ;
ods rtf close ;
*/


* With CSS **************************************************************************************************;

filename css "&root./style.css" ;
filename out "&root./report/report_css.rtf" ;
%include "&root./css_macro.sas" ;

/*
* border with row numbers ;

%let rownums = ;
data _null_ ;
  set sample.out end = eof ;
  length rownums $ 100 ;
  retain rownums ;

  if _LINE_IND = 21 then rownums = catx(' ', rownums, _n_) ;
  if eof = 1 then call symputx('rownums', rownums) ;
run ;

%make_css(&rownums.) ;
*/

options nodate nonumber papersize = "A4" orientation = portrait topmargin = 3cm bottommargin = 3cm leftmargin = 2.5cm rightmargin= 2.5cm ;
ods escapechar = '~';

title1 'Table 9.9.9 Subgroup Analysis, MMRM for Percent Change from Baseline in VAS by Age Group 日本語テキスト' ;
title2 'Full Analysis Set' ;
footnote1 'Page ~{pageof}' ;

ods rtf file = out  notoc_data cssstyle = css dom ;
proc report data = sample.out missing split = '|' spanrows ;
  column ("" AGEGR1N AGEGR1X TRTPN TRT_VISITN TRT_VISIT LSMEAN SE)
         ("95% CI~{super[a]}" LOWER UPPER)
         ("Comparison to Placebo" C_LSMEAN C_SE("CI~{super[a]}" C_LOWER C_UPPER)) 
         ;
  define AGEGR1N    / order noprint ;
  define AGEGR1X    / order 'age' ;
  define TRTPN      / order noprint ;
  define TRT_VISITN / order noprint ;
  define TRT_VISIT  / 'Treatment|Visit' ;
  define LSMEAN     / 'LS Mean' ;
  define SE         / 'SE' ;
  define LOWER      / 'Lower' ;
  define UPPER      / 'Upper' ;
  define C_LSMEAN   / 'LS Mean' ;
  define C_SE       / 'SE' ;
  define C_LOWER    / 'Lower' ;
  define C_UPPER    / 'Upper' ;

  compute after _page_ ;
    line '[a] 95% confidence interval' ;
  endcomp ;
run ;
ods rtf close ;