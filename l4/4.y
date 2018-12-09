%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <sstream>
#include <cmath>
#include <vector>

int yyerror (const std::string);
extern int yylineno;
int yylex();

long long int memCounter;
long long int depth;
int assignFlag;
int writeFlag;


std::vector<std::string> codeStack;
%}
%union {
	char* str;
	long long int num;
}
%start program

%token <str> NUM IDENT
%token <str> DECLARE IN END READ WRITE FOR FROM TO DOWNTO DO WHILE IF THEN ELSE ENDFOR ENDWHILE ENDIF ENDDO
%token <str> ASSIGN NEQ EQ LE GE GT LT INDEXER COLON ADD SUB MUL DIV MOD LB RB

%type <str> value
%type <str> identifier
%%

program: DECLARE declarations IN commands END {
	
}
;

declarations: 
| declarations IDENT COLON {
	std::cout << "Deklaruje " << $2 << "\n";
}
| declarations IDENT LB NUM INDEXER NUM RB COLON {
	std::cout << "Deklaruje talbice " << $2 << "\n";
}
;

commands: commands command
| command
;

command: identifier ASSIGN expression COLON {
	
}
| IF condition THEN commands ifbody {
	
}
| WHILE condition DO commands ENDWHILE {
	
}
| DO commands WHILE condition ENDDO {
	
}
| FOR IDENT FROM value forbody {
	
}
| READ identifier COLON {
	
}
| WRITE value COLON {
	
}
;

ifbody: ELSE commands ENDIF {

}
| ENDIF {

}
;

forbody: TO value DO commands ENDFOR {

}
| DOWNTO value DO commands ENDFOR {

}
;

expression: value {
	
}
| value ADD value {
	
}
| value SUB value {
	
}
| value MUL value {
	
}
| value DIV value {
	
}
| value MOD value {
	
}
;

condition: value EQ value {
	
}
| value NEQ value {
	
}
| value LT value {
	
}
| value GT value {
	
}
| value LE value {
	
}
| value GE value {
	
}
;

value: NUM {
	
}
| identifier {
	
}
;

identifier: IDENT {
	std::cout << "Chce brać " << $1 << "\n";
}
| IDENT LB IDENT RB {
	std::cout << "Chce brać " << $1 << "(" << $3 << ")\n";
}
| IDENT LB NUM RB {
	std::cout << "Chce brać " << $1 << "(" << $3 << ")\n";
}
;
%% 

void printStdCode() {
	long long int i;
	for(i = 0; i < codeStack.size(); i++)
        std::cout << codeStack.at(i) << std::endl;
}

void printCode(std::string filename) {
	std::ofstream out_code(filename);
	long long int i;
	for(i = 0; i < codeStack.size(); i++)
        out_code << codeStack.at(i) << std::endl;
}

void parser(int argc, char** argv) {
	assignFlag = 1;
	memCounter = 12;
	writeFlag = 0;
	depth = 0;

	yyparse();

	if(argc < 2) {
		printStdCode();
	} else {
		printCode(argv[1]);
	}
}

int main (int argc, char** argv) {
	parser(argc, argv);
}

int yyerror(const std::string s) {
	std::cout << "Błąd [około linii " << yylineno << "]: " << s << std::endl;
	return 1;
}