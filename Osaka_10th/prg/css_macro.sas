%macro head_align ;
/*
    Return the text-align value for the header cells in the table.
*/
  %if "&_val_." = "age" or "&_val_." = "Treatment|Visit" %then left ;
  %else center ; 
%mend ;

%macro col_margin ;
/* 
    Retun the padding-left value for the data cells in the table.
*/
  %if "%scan(&_val_, 1)" = "Active" or "%scan(&_val_, 1)" = "Placebo" %then 0 ;
  %else 0.4cm ; 
%mend ;

%macro group_line ;
/*
    Return the border-top-width value for the data cells in the table.
*/
  %if "%scan(&_val_, 1)" = "Active" or "%scan(&_val_, 1)" = "Placebo"  %then 1pt ;
  %else 0 ;    
%mend ;


%macro make_css(rownums,  cssfile=temp) ;
/*
    Generates a CSS file for tables.
    Parameters:
    - rownums(list): a list of row numbers to apply a border-bottom to.
    - cssfile(path): path of the CSS file to create. Default is temp.
*/

filename css &cssfile. ;

proc stream outfile = css ;
begin &streamdelim.;
:root{
  font-size:8pt;
  font-family: 'Courier';
} 

.systemtitle, .systemtitle2,.systemtitle3, .linecontent{text-align:left;}
.systemfooter{text-align:right;}
.linecontent:first-child{border-top-width:1pt;}

.table{
    border-color:black;
    border-style:solid;
    border-top-width:1pt;
    width: 100% ;
}

.table.header, .table.data{
    padding: 0 ;
    margin: 0 ;
}

.header{vertical-align:bottom; }

.data{vertical-align:top;}

.header{text-align: resolve('%head_align') ;}

td.data:not(:empty){
    padding-left: resolve('%col_margin') ;
}

th.data{border-top-width: 1pt;}
.header:not(:empty){border-bottom-width: 1pt;}

%do i = 1 %to %sysfunc(countw(&rownums.)) ;
  %let rownum = %scan(&rownums.,&i.) ;
tr:nth-child(&rownum.) .data
    %if &i. ne %sysfunc(countw(&rownums.)) %then %do ;
,
    %end ;
%end ;
%if &rownums. ne %then %do ;
{border-bottom-width:1pt;}
%end ;
;;;;
run ;

%mend ;