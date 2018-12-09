%{
#include "y.tab.h"

void yyerror (const char* s);
int yylex();
%}

%x COMMENT
%%

"["             { BEGIN(COMMENT); }
<COMMENT>"]"        { BEGIN(INITIAL); }
<COMMENT>(\n|.)     ;
<COMMENT><<EOF>>    { printf("Błąd: niezakończony komentarz.\n"); yyterminate(); }
"#".*$ ;

":=" {return ASSIGN;}
"!=" {return NEQ;}
"=" {return EQ;}
"<=" {return LE;}
">=" {return GE;}
"<" {return LT;}
">" {return GT;}
";" {return COLON;}
"+" { return ADD;}
":" { return INDEXER;      }
"-" { return SUB;      }
"*" { return MUL;      }
"/" { return DIV;      }
"%" { return MOD;      }
"(" { return LB;       }
")" { return RB;       }
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
ENDDO {return ENDDO;}
ENDFOR {return ENDFOR;}
ENDWHILE {return ENDWHILE;}
ENDIF {return ENDIF;}
[_a-z]+ {yylval.str = (char *)strdup(yytext); return IDENT;}
[0-9]+ {yylval.str = (char *)strdup(yytext); return NUM;}
[ \t\r\n]+ ;
. ;
%%

int yywrap(void) {return 1;}

