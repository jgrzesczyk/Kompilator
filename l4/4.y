%{
#include <iostream>
#include <cstdlib>
#include <string>
#include <sstream>
#include <cmath>
#include <regex>

void yyerror (const char*);
int yylex();
bool error = false;

%}
%union rec{
	unsigned long long intval;
	char * pid;
	struct varTab *tab;
	struct varTabMath *tab2;
	struct varTabFor *tab3;
	struct labels *label;
}
%start program

%token number
%token DECLARE IN END
%token COLON
%token <label> IF WHILE
%token <tab3> FOR
%token FROM TO DOWNTO DO THEN ELSE ENDDO ENDFOR ENDWHILE ENDIF
%token READ WRITE
%token GE LE NEQ
%token ASSIGN
%token <pid> pidentifier
%token <intval> num


%left '+' '-'
%left '*' '/' '%'
%%
program: DECLARE declarations IN commands END {
	
}
;

declarations: 
| declarations pidentifier COLON {
	std::cout << "Deklaruje " << $2 << "\n";
}
| declarations pidentifier '(' num ':' num ')' COLON {
	std::cout << "Deklaruje talbice " << $2 << "\n";
}
;

commands: commands command
| command
;

command: identifier ASSIGN expression COLON {
	
}
| IF condition THEN commands ELSE commands ENDIF {
	
}
| IF condition THEN commands ENDIF {
	
}
| WHILE condition DO commands ENDWHILE {
	
}
| DO commands WHILE condition ENDDO {
	
}
| FOR pidentifier FROM value TO value DO commands ENDFOR {
	
}
| FOR pidentifier FROM value DOWNTO value DO commands ENDFOR {
	
}
| READ identifier COLON {
	
}
| WRITE value COLON {
	
}
;

expression: value {
	
}
| value '+' value {
	
}
| value '-' value {
	
}
| value '*' value {
	
}
| value '/' value {
	
}
| value '%' value {
	
}
;

condition: value '=' value {
	
}
| value NEQ value {
	
}
| value '<' value {
	
}
| value '>' value {
	
}
| value LE value {
	
}
| value GE value {
	
}
;

value: num {
	
}
| identifier {
	
}
;

identifier: pidentifier {
	std::cout << "Chce brać " << $1 << "\n";
}
| pidentifier '(' pidentifier ')' {
	std::cout << "Chce brać " << $1 << "(" << $3 << ")\n";
}
| pidentifier '(' num ')' {
	std::cout << "Chce brać " << $1 << "(" << $3 << ")\n";
}
;
%% 

int main (void) {
	return yyparse();
}

void yyerror(const char* s) {
	error = true;
}