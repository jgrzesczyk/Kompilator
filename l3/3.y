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

std::ostringstream ss;
std::string rpn;
std::regex regex("([-]*[0-9]+)(?!.*[0-9]+)");
%}

%token number

%left '+' '-'
%left '/' '*' '%'
%right '^'
%right NEG
%%
program: 
	   | line program
	   ;

line: '\n'
	| error '\n' { yyerrok; rpn = ""; std::cout << "Błąd.\n"; error = false; }
	| expression '\n' { 
		if(error) {
			std::cout << "Błąd.\n";
		} else {
			std::cout << rpn << "\n";
			$$ = $1; 
			std::cout << "Wynik: " << $1 << "\n";   
		}
		error = false;
		$$ = 0;
		rpn = "";
	}
	;

expression: number { ss << $1; rpn.append(ss.str()).append(" "); ss.str("") }
		  | expression '+' expression { 
				if(!error) {
					$$ = $1+$3;
				} 
				rpn.append("+ ");  
		  }
		  | expression '*' expression { 
				if(!error) {
					$$ = $1*$3;
				} 
				rpn.append("* ");  
		  }
		  | expression '/' expression {
				if($3 == 0 || error) {
						error = true;
				} else {
					$$ = $1/$3; 
				} 
				rpn.append("/ "); 
		  }
			| expression '^' expression { 
				if(!error) {
					$$ = pow($1,$3);
				}
				rpn.append("^ ");  
		  }
		  | expression '%' expression {
				if($3 == 0 || error) {
						error = true;
				} else {
					$$ = $1%$3;
					if($$ < 0) {
						$$ = $$+$3;
					}
				} 
				rpn.append("% "); 
		  }
		  | expression '-' expression { 
				if(!error) {
					$$ = $1-$3;
				} 
				rpn.append("- ");  
		  }
		  | '-' expression %prec NEG { 
			  $$ = -$2;
			  rpn = std::regex_replace(rpn, regex, "-$0") 
		  }
		  | '(' expression ')' { $$ = $2; }
		  ;
%% 

int main (void) {
	return yyparse();
}

void yyerror(const char* s) {
	error = true;
}