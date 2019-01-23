%{
#include "y.tab.h"

void yyerror (const char* s);
int yylex();
%}

%%
\\\n ;
^\#.*\n ;
[ \t]+ ;
[-+*/%\^()\n] { return yytext[0]; }
[0] {yylval = 0; return number;}
[1-9][0-9]* {yylval = atoi(yytext); return number;}
[^-+0-9*/%\^()\n\\]+ {yyerror("");}
%%

int yywrap(void) {return 1;}

