%{
#include "y.tab.h"

void yyerror (const char* s);
int yylex();
%}

%%
\[([^\[\]])*\] ;
"#".*$ ;
[0-9]+ {yylval.intval=atoll(yytext); return num;}
":=" {return ASSIGN;}
"!=" {return NEQ;}
"<=" {return LE;}
">=" {return GE;}
";" {return COLON;}
DECLARE {return DECLARE;}
IN {return IN;}	
END {return END;}
READ {return READ;}
WRITE {return WRITE;}
FOR	{return FOR;}
FROM {return FROM;}
TO {return TO;}
DOWNTO {return DOWNTO;}
DO {return DO;}
WHILE {return WHILE;}
IF {return IF;}
THEN {return THEN;}
ELSE {return ELSE;}
ENDFOR {return ENDFOR;}
ENDWHILE {return ENDWHILE;}
ENDIF {return ENDIF;}
[_a-z]+ {yylval.pid=strdup(yytext); return pidentifier;}
[ \t\n]+ ;
. {return(yytext[0]);}
%%

int yywrap(void) {return 1;}

