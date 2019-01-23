%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <sstream>
#include <cmath>
#include <vector>
#include <map>
#include <regex>

enum Type {
	ARRAY, IDENTIFIER, NUMBER
};
typedef struct {
	Type type;
	std::string name, inRegister;
    bool isInit, isLocal, isTable;
	long long int memory, numberAmount, beginTable, endTable;
} Variable;

typedef struct {
    long long int codePosition, depth;
} Jump;

long long int memoryIndex, depth;
bool assignFlag, writeFlag, preParsing;
std::vector<std::string> freeRegisters;
Jump tj;
int indextj;

std::vector<std::string> preParsingVars;
std::vector<int> preParsingCount;
int weight;

std::vector<std::string> code;
std::map<std::string, Variable> variables;
std::vector<Jump> jumps;
std::vector<Variable> forVariables;

Variable assignTarget;
std::string tabAssignTargetIndex = "NULL";
std::string expressionArguments[2] = {"NULL", "NULL"};
std::string argumentsTabIndex[2] = {"NULL", "NULL"};

int yyerror (const std::string);
extern int yylineno;
extern FILE * yyin;
int yylex();
void addJumpPlaceToCode(long long int, long long int);
void newJump(Jump*, long long int, long long int);
void addition(Variable, Variable, Variable, Variable);
void substract(Variable, Variable, Variable, Variable, int, int);
void arrayIndexToRegister(Variable, Variable, std::string);
void setRegister(std::string, std::string);
void newVariable(Variable*, std::string, bool, Type);
void newVariable(Variable*, std::string, bool, Type, long long int, long long int);
void popVariable(std::string);
void insertVariable(std::string, Variable);
void addCode(std::string);
void addCode(std::string, long long int);
void memToRegister(long long int, std::string);
void memToRegister(std::string);
std::string toBinary(long long int);
void registerToMem(std::string, long long int);
void registerToMem(std::string);
int isPowerOfTwo(long long int);
std::string registerValue(std::string);
void preParseVariableUsage(std::string);
%}

%define parse.error verbose
%define parse.lac full

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
	if(!preParsing)
		addCode("HALT");
}
;

declarations: 
| declarations IDENT COLON {
	if(!preParsing) {
		if(variables.find($2) != variables.end()) {
			std::cout << "Error [linia " << yylineno << "]: Kolejna deklaracja zmiennej " << $<str>2 << std::endl;
			exit(1);
		} else {
			Variable ide;
			newVariable(&ide, $2, false, IDENTIFIER);
			insertVariable($2, ide);
		}
	}
}
| declarations IDENT LB NUM INDEXER NUM RB COLON {
	if(!preParsing) {
		if(variables.find($2) != variables.end()) {
			std::cout << "Error [linia " << yylineno << "]: Kolejna deklaracja zmiennej " << $<str>2 << std::endl;
			exit(1);
		} else if (atoll($4) > atoll($6)) {
			std::cout << "Error [linia " << yylineno << "]: Indeksy tablicy " << $<str>2 << " są niepoprawne" << std::endl;
			exit(1);
		} else if (atoll($4) < 0) {
			std::cout << "Error [linia " << yylineno << "]: Początek tablicy o indeksie " << $<str>2 << " < 0!" << std::endl;
			exit(1);
		} else {
			Variable ide;
			newVariable(&ide, $2, false, ARRAY, atoll($4), atoll($6));
			insertVariable($2, ide);
			memoryIndex = memoryIndex + (atoll($6) - atoll($4) + 1);       
		}
	}
}
;

newlabel: WHILE {
	if(!preParsing) {
		assignFlag = false;
		Jump j;
		newJump(&j, code.size(), depth);
		tj = j;
		indextj = jumps.size();
	}
}
;

commands: commands command
| command
;

command: identifier ASSIGN {
	if(!preParsing) {
		assignFlag = false;
	}
} expression COLON {
	if(!preParsing) {
		if(assignTarget.type == ARRAY) {
			Variable index = variables.at(tabAssignTargetIndex);
			if(index.type == NUMBER) {
				long long int tabElMem = assignTarget.memory + stoll(index.name) + 1 - assignTarget.beginTable;
				registerToMem("B", tabElMem);
				popVariable(index.name);
			} else {
				long long int offset = assignTarget.memory + 1;

				if(index.inRegister == "NULL") {
					memToRegister(index.memory, "C");
					
				} else {
					addCode("COPY C " + index.inRegister);
				}
				setRegister("A", std::to_string(offset));
				addCode("ADD A C");
				setRegister("C", std::to_string(assignTarget.beginTable));
				addCode("SUB A C");
				addCode("STORE B");
			}
		}
		else if(!assignTarget.isLocal) {
			registerToMem("B", assignTarget.memory);
		}
		else {
			std::cout << "Error [linia " << yylineno << "]: Próba modyfikacji iteratora pętli." << std::endl;
			exit(1);
		}
		variables.at(assignTarget.name).isInit = true;
		assignFlag = true;
	}
}
| IF {
	if(!preParsing) {
		assignFlag = false;
		depth++;
	} else {
		depth++;
	}
} condition {
	if(!preParsing) {
		assignFlag = true;
	}
} THEN commands ifbody

| FOR IDENT {
	if(!preParsing) {
		if(variables.find($2)!=variables.end()) {
			std::cout << "Error [linia " << yylineno << "]: Kolejna deklaracja zmiennej " << $<str>2 << "." << std::endl;
			exit(1);
		} else {
			Variable i;
			newVariable(&i, $2, true, IDENTIFIER);
			insertVariable($2, i);
		}
		assignFlag = false;
		assignTarget = variables.at($2);
		depth++;
	} else {
		depth++;
		weight = weight*10; 
	}
} FROM value forbody

| READ {
	if(!preParsing) {
		assignFlag = true;
	}
} identifier COLON {
	if(!preParsing) {
		if(assignTarget.type == ARRAY) {
			Variable index = variables.at(tabAssignTargetIndex);
			if(index.type == NUMBER) {
				addCode("GET B");
				long long int tabElMem = assignTarget.memory + stoll(index.name) + 1 - assignTarget.beginTable;
				registerToMem("B", tabElMem);
				popVariable(index.name);
			}
			else {
				long long int offset = assignTarget.memory + 1;
				if(index.inRegister == "NULL") {
					memToRegister(index.memory, "C");
					
				} else {
					addCode("COPY C " + index.inRegister);
				}
				setRegister("A", std::to_string(offset));
				addCode("ADD A C");
				setRegister("C", std::to_string(assignTarget.beginTable));
				addCode("SUB A C");
				addCode("GET B");
				addCode("STORE B");
			}

		} else if(!assignTarget.isLocal) {
			if(assignTarget.inRegister == "NULL") {
				addCode("GET B"); 
				registerToMem("B", assignTarget.memory);
			} else {
				addCode("GET " + assignTarget.inRegister);
			}
		} else {
			std::cout << "Error [linia " << yylineno << "]: Próba modyfikacji iteratora pętli." << std::endl;
			exit(1);
		}
		variables.at(assignTarget.name).isInit = true;
		assignFlag = true;
	}
}
| WRITE {
	if(!preParsing) {
		assignFlag = false;
		writeFlag = true;
	}
} value COLON {
	if(!preParsing) {
		Variable ide = variables.at(expressionArguments[0]);

		if(ide.type == NUMBER) {
			setRegister("B", ide.name);
			popVariable(ide.name);
		} else if(ide.type == IDENTIFIER) {
			memToRegister(ide.memory, "B");
		} else {
			Variable index = variables.at(argumentsTabIndex[0]);
			if(index.type == NUMBER) {
				long long int tabElMem = ide.memory + stoll(index.name) + 1 - ide.beginTable;
				memToRegister(tabElMem, "B");
				popVariable(index.name);
			} else {
				arrayIndexToRegister(ide, index, "B");
			}
		}
		addCode("PUT B"); 
		assignFlag = true;
		writeFlag = false;
		expressionArguments[0] = "NULL";
		argumentsTabIndex[0] = "NULL";
	}
}
| newlabel condition {
	if(!preParsing) {
		assignFlag = true;
		depth++;
		jumps.insert(jumps.begin() + indextj, tj);
		for(int i=indextj; i<jumps.size(); ++i) {
			jumps[i].depth = depth;
		}
	} else {
		depth++;
		weight*=10; 
	}
}  DO commands ENDWHILE {
	if(!preParsing) {
		long long int stack;
		long long int jumpCount = jumps.size()-1;
		if(jumpCount > 2 && jumps.at(jumpCount-2).depth == depth) {
			stack = jumps.at(jumpCount-2).codePosition;
			addCode("JUMP", stack);
			addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
			addJumpPlaceToCode(jumps.at(jumpCount-1).codePosition, code.size());
			jumps.pop_back();
		}
		else {
			stack = jumps.at(jumpCount-1).codePosition;
			addCode("JUMP", stack);
			addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
		}
		jumps.pop_back();
		jumps.pop_back();

		depth--;
		assignFlag = true;
	} else{
		depth--;
		weight /= 10; 
	}
}
| DO {
	if(!preParsing) {
		assignFlag = true;
		depth++;
		Jump j;
		newJump(&j, code.size(), depth);
		jumps.push_back(j);
	} else {
		depth++;
		weight*=10; 
	}
} commands newlabel condition ENDDO {
	if(!preParsing) {
		long long int stack;
		long long int jumpCount = jumps.size()-1;
		if(jumpCount > 2 && jumps.at(jumpCount-2).depth == depth) {
			stack = jumps.at(jumpCount-2).codePosition;
			addCode("JUMP", stack);
			addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
			addJumpPlaceToCode(jumps.at(jumpCount-1).codePosition, code.size());
			jumps.pop_back();
		}
		else {
			stack = jumps.at(jumpCount-1).codePosition;
			addCode("JUMP", stack);
			addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
		}
		jumps.pop_back();
		jumps.pop_back();

		depth--;
		assignFlag = true;
	} else {
		depth--;
		weight /=10; 
	}
} 
;

ifbody: ELSE {
	if(!preParsing) {
		Jump j;
		newJump(&j, code.size(), depth);
		jumps.push_back(j);
		
		addCode("JUMP");
		long long int jumpCount = jumps.size()-2;
		Jump jump = jumps.at(jumpCount);
		addJumpPlaceToCode(jump.codePosition, code.size());
		
		jumpCount--;
		if(jumpCount >= 0 && jumps.at(jumpCount).depth == depth) {
			addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
		}
		
		assignFlag = true;
	}
} commands ENDIF {
	if(!preParsing) {
		addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());

		jumps.pop_back();
		jumps.pop_back();
		if(jumps.size() >= 1 && jumps.at(jumps.size()-1).depth == depth) {
			jumps.pop_back();
		}
		depth--;
		assignFlag = true;
	} else {
		depth--;
	}
}
| ENDIF {
	if(!preParsing) {
		long long int jumpCount = jumps.size()-1;
		addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
		jumpCount--;
		if(jumpCount >= 0 && jumps.at(jumpCount).depth == depth) {
			addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
			jumps.pop_back();
		}
		jumps.pop_back();
		depth--;
		assignFlag = true;
	} else {
		depth--;
	}
}
;


forbody: TO value DO {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

		if(a.type == NUMBER) {
			setRegister("B", a.name);
			popVariable(a.name);
		}
		else if(a.type == IDENTIFIER) {
			memToRegister(a.memory, "B");
		}
		else {
			Variable index = variables.at(argumentsTabIndex[0]);
			if(index.type == NUMBER) {
				long long int tabElMem = a.memory + stoll(index.name) + 1;
				memToRegister(tabElMem, "B");
				popVariable(index.name);
			}
			else {
				arrayIndexToRegister(a, index, "B");
			}
		}
		registerToMem("B", assignTarget.memory);
		variables.at(assignTarget.name).isInit = true;

		if(a.type != ARRAY && b.type != ARRAY)
			substract(b, a, bI, aI, 1, 1);
		else {
			if(variables.count(argumentsTabIndex[0]) > 0)
				aI = variables.at(argumentsTabIndex[0]);
			if(variables.count(argumentsTabIndex[1]) > 0)
				bI = variables.at(argumentsTabIndex[1]);
			substract(b, a, bI, aI, 1, 1);
			argumentsTabIndex[0] = "NULL";
			argumentsTabIndex[1] = "NULL";
		}
		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";

		Variable s;
		std::string name = "LOOP" + std::to_string(depth);
		newVariable(&s, name, true, IDENTIFIER);
		insertVariable(name, s);

		registerToMem("B",variables.at(name).memory);
		forVariables.push_back(variables.at(assignTarget.name));

		addCode("JZERO B");
		Jump jj;
		newJump(&jj, code.size(), depth);
		jumps.push_back(jj);

		memToRegister(variables.at(name).memory, "B");
		
		addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition-1, code.size());

		Jump j;
		newJump(&j, code.size(), depth);
		jumps.push_back(j);
		addCode("JZERO B");
		addCode("DEC B");
		registerToMem("B", variables.at(name).memory);//todo same here
		assignFlag = true;
	} else {
		preParseVariableUsage("LOOP" + std::to_string(depth));
	}
} commands ENDFOR {
	if(!preParsing) {
		Variable iterator = forVariables.at(forVariables.size()-1);

		if(iterator.inRegister == "NULL") {
			memToRegister(iterator.memory, "B");
			addCode("INC B");
			registerToMem("B", iterator.memory);
		} else {
			addCode("INC " + iterator.inRegister);
		}

		long long int jumpCount = jumps.size()-1;
		long long int stack = jumps.at(jumpCount-1).codePosition;
		addCode("JUMP", stack);
		addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
		jumps.pop_back();
		jumps.pop_back();
		
		std::string name = "LOOP" + std::to_string(depth);
		
		popVariable(name); 
		popVariable(iterator.name);
		forVariables.pop_back();

		depth--;
		assignFlag = true;
	}else {
		depth--;
		weight/=10; 
	}
}
| DOWNTO value DO {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

		if(a.type == NUMBER) {
			setRegister("B", a.name);
			popVariable(a.name);
		}
		else if(a.type == IDENTIFIER) {
			memToRegister(a.memory, "B");
		}
		else {
			Variable index = variables.at(argumentsTabIndex[0]);
			if(index.type == NUMBER) {
				long long int tabElMem = a.memory + stoll(index.name) + 1;
				memToRegister(tabElMem, "B");
				popVariable(index.name);
			}
			else {
				arrayIndexToRegister(a, index, "B");
			}
		}
		registerToMem("B", assignTarget.memory);
		variables.at(assignTarget.name).isInit = true;

		if(a.type != ARRAY && b.type != ARRAY)
			substract(a, b, aI, bI, 1, 1);
		else {
			if(variables.count(argumentsTabIndex[0]) > 0)
				aI = variables.at(argumentsTabIndex[0]);
			if(variables.count(argumentsTabIndex[1]) > 0)
				bI = variables.at(argumentsTabIndex[1]);
			substract(a, b, aI, bI, 1, 1);
			argumentsTabIndex[0] = "NULL";
			argumentsTabIndex[1] = "NULL";
		}
		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";

		Variable s;
		std::string name = "LOOP" + std::to_string(depth);
		newVariable(&s, name, true, IDENTIFIER);
		insertVariable(name, s);

		registerToMem("B",variables.at(name).memory);
		forVariables.push_back(variables.at(assignTarget.name));

		addCode("JZERO B");
		Jump jj;
		newJump(&jj, code.size(), depth);
		jumps.push_back(jj);

		memToRegister(variables.at(name).memory, "B");
		
		addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition-1, code.size());

		Jump j;
		newJump(&j, code.size(), depth);
		jumps.push_back(j);
		addCode("JZERO B");//todo dla rejestrow zmiennych
		addCode("DEC B");
		registerToMem("B", variables.at(name).memory);
		assignFlag = true;
	} else {
		preParseVariableUsage("LOOP" + std::to_string(depth));
	}
} commands ENDFOR {
	if(!preParsing) {
		Variable iterator = forVariables.at(forVariables.size()-1);
		if(iterator.inRegister == "NULL") {
			memToRegister(iterator.memory, "B");
			addCode("DEC B");
			registerToMem("B", iterator.memory);
		} else {
			addCode("DEC " + iterator.inRegister);
		}

		long long int jumpCount = jumps.size()-1;
		long long int stack = jumps.at(jumpCount-1).codePosition;
		addCode("JUMP", stack);
		addJumpPlaceToCode(jumps.at(jumpCount).codePosition, code.size());
		jumps.pop_back();
		jumps.pop_back();

		std::string name = "LOOP" + std::to_string(depth);
		popVariable(name);
		popVariable(iterator.name);
		forVariables.pop_back();

		depth--;
		assignFlag = true;
	}else {
		depth--;
		weight/=10; 
	}
}
;

expression: value {
	if(!preParsing) {
		Variable ide = variables.at(expressionArguments[0]);
		if(ide.type == NUMBER) {
			setRegister("B", ide.name);
			popVariable(ide.name);
		}
		else if(ide.type == IDENTIFIER) {
			memToRegister(ide.memory, "B");
		}
		else {
			Variable index = variables.at(argumentsTabIndex[0]);
			if(index.type == NUMBER) {
				long long int tabElMem = ide.memory + stoll(index.name) + 1 - ide.beginTable;
				memToRegister(tabElMem, "B");
				popVariable(index.name);
			}
			else {
				arrayIndexToRegister(ide, index,"B");
			}
		}
		if (!writeFlag) {
			expressionArguments[0] = "NULL";
			argumentsTabIndex[0] = "NULL";
		}
	}
}
| value ADD value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;
		if(a.type != ARRAY && b.type != ARRAY)
			addition(a, b, aI, bI);
		else {
			if(variables.count(argumentsTabIndex[0]) > 0)
				aI = variables.at(argumentsTabIndex[0]);
			if(variables.count(argumentsTabIndex[1]) > 0)
				bI = variables.at(argumentsTabIndex[1]);
			addition(a, b, aI, bI);
			argumentsTabIndex[0] = "NULL";
			argumentsTabIndex[1] = "NULL";
		}
		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
	}
}
| value SUB value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

		if(a.type != ARRAY && b.type != ARRAY)
			substract(a, b, aI, bI, 0, 1);
		else {
			if(variables.count(argumentsTabIndex[0]) > 0)
				aI = variables.at(argumentsTabIndex[0]);
			if(variables.count(argumentsTabIndex[1]) > 0)
				bI = variables.at(argumentsTabIndex[1]);
			substract(a, b, aI, bI, 0, 1);
			argumentsTabIndex[0] = "NULL";
			argumentsTabIndex[1] = "NULL";
		}
		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
	}
}
| value MUL value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);

		if(a.type == NUMBER && b.type == NUMBER) {
			long long int val = stoll(a.name) * stoll(b.name);
			setRegister("B", std::to_string(val));
			popVariable(a.name);
			popVariable(b.name);
		}
		else if(a.type == NUMBER && isPowerOfTwo(stoll(a.name)) > 0) {
			
			int times = isPowerOfTwo(stoll(a.name));                                                 
			if(b.type == IDENTIFIER)
				memToRegister(b.memory, "B");
			else if(b.type == ARRAY && bI.type == NUMBER) {
				long long int addr = b.memory + stoll(bI.name) + 1 - b.beginTable;
				memToRegister(addr, "B");
				popVariable(bI.name);
			}
			else {
				arrayIndexToRegister(b, bI, "B");
			}
			
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");

			for(int i=0; i<times; ++i) {
				addCode("ADD B B");
			}

			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();

			popVariable(a.name);
		}
		else if(b.type == NUMBER && isPowerOfTwo(stoll(b.name)) > 0) {
			
			int times = isPowerOfTwo(stoll(b.name));

			if(a.type == IDENTIFIER)
				memToRegister(a.memory, "B");
			else if(a.type == ARRAY && aI.type == NUMBER) {
				long long int addr = a.memory + stoll(aI.name) + 1 - a.beginTable;
				memToRegister(addr, "B");
				popVariable(aI.name);
			}
			else {
				arrayIndexToRegister(a, aI, "B");
			}
			
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");

			for(int i=0; i<times; ++i) {
				addCode("ADD B B");
			}

			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();

			popVariable(b.name);
		}
		else {
			if(a.type == NUMBER) {
				setRegister("B", a.name);
			} else if(a.type == IDENTIFIER) {
				memToRegister(a.memory, "B");
			} else if(a.type == ARRAY) {
				if(aI.type == IDENTIFIER)
					arrayIndexToRegister(a, aI, "B");
				else {
					long long int addr = a.memory + stoll(aI.name) + 1 - a.beginTable;
					memToRegister(addr, "B");
					popVariable(aI.name);
				}
			}
			
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");

			if(b.type == NUMBER) {
				setRegister("C", b.name);
			} else if(b.type == IDENTIFIER) {
				memToRegister(b.memory, "C");
			} else if(b.type == ARRAY) {
				if(bI.type == IDENTIFIER)
					arrayIndexToRegister(b, bI, "C");
				else {
					long long int addr = b.memory + stoll(bI.name) + 1 - b.beginTable;
					memToRegister(addr, "C");
					popVariable(bI.name);
				}
			}
			
			addCode("JZERO C ",code.size()+10);  
			addCode("SUB D D");
			addCode("JZERO B", code.size()+9); 
			addCode("JODD B ", code.size()+2); 
			addCode("JUMP", code.size()+2);
			addCode("ADD D C");
			addCode("HALF B");
			addCode("ADD C C");
			addCode("JUMP",code.size()-6);
			addCode("JUMP",code.size()+2);

			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();

			addCode("SUB D D");
			addCode("COPY B D");	
		}

		argumentsTabIndex[0] = "NULL";
		argumentsTabIndex[1] = "NULL";
		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
	}
}
| value DIV value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);

		if(b.type == NUMBER && stoll(b.name) == 0) {
			setRegister("B", "0");
		}
		else if(a.type == NUMBER && stoll(a.name) == 0) {
			setRegister("B", "0");
		}
		else if(b.type == NUMBER && isPowerOfTwo(stoll(b.name)) > 0) {
			
			int times = isPowerOfTwo(stoll(b.name));
			
			if(a.type == NUMBER) {
				setRegister("B", a.name);
				popVariable(a.name);
			} else if(a.type == IDENTIFIER) {
				memToRegister(a.memory, "B");
			} else if(a.type == ARRAY) {
				if(aI.type == IDENTIFIER)
					arrayIndexToRegister(a, aI, "B");
				else {
					long long int addr = a.memory + stoll(aI.name) + 1 - a.beginTable;
					memToRegister(addr, "B");
					popVariable(aI.name);
				}
			}
			
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");

			for(int i=0; i<times; ++i) {
				addCode("HALF B");
			}

			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();
		}
		else if(a.type == NUMBER && b.type == NUMBER) {
			long long int val = stoll(a.name) / stoll(b.name);
			setRegister("B", std::to_string(val));
			popVariable(a.name);
			popVariable(b.name);
		} else {
			if(a.type == NUMBER) {
				setRegister("B", a.name);
				popVariable(a.name);
			} else if(a.type == IDENTIFIER) {
				memToRegister(a.memory, "B");
			} else if(a.type == ARRAY) {
				if(aI.type == IDENTIFIER)
					arrayIndexToRegister(a, aI, "B");
				else {
					long long int addr = a.memory + stoll(aI.name) + 1 - a.beginTable;
					memToRegister(addr, "B");
					popVariable(aI.name);
				}
			}
			
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");

			if(b.type == NUMBER) {
				setRegister("C", b.name);
				popVariable(b.name);
			} else if(b.type == IDENTIFIER) {
				memToRegister(b.memory, "C");
			} else if(b.type == ARRAY) {
				if(bI.type == IDENTIFIER)
					arrayIndexToRegister(b, bI, "C");
				else {
					long long int addr = b.memory + stoll(bI.name) + 1 - b.beginTable;
					memToRegister(addr, "C");
					popVariable(bI.name);
				}
			}
			
			Jump juma;
			newJump(&juma, code.size(), depth);
			jumps.push_back(juma);
			addCode("JZERO C");

			if ( std::find(freeRegisters.begin(), freeRegisters.end(), "E") == freeRegisters.end() ) {
				registerToMem("E");
			} 
			
			
			

			addCode("SUB E E"); 
			addCode("COPY D C");
			addCode("SUB D B");
			addCode("JZERO D",code.size()+3); 
			addCode("SUB B B");
			addCode("JUMP", code.size()+35); 
			
			addCode("COPY D B");
			addCode("SUB D C");
			addCode("JZERO D",code.size()+2);
			addCode("JUMP",code.size()+4); 
			addCode("SUB B B");
			addCode("INC B");
			addCode("JUMP", code.size()+28); 

			addCode("COPY D C");
			addCode("COPY A D");
			addCode("SUB A B");
			addCode("JZERO A",code.size()+2);
			addCode("JUMP",code.size()+3);
			addCode("ADD D D");
			addCode("JUMP",code.size()-5);
			addCode("COPY A C");
			addCode("SUB A B");
			addCode("JZERO A",code.size()+2);
			addCode("JUMP", code.size()+10);
			addCode("COPY A D");
			addCode("SUB A B");
			addCode("JZERO A",code.size()+4);
			addCode("HALF D");
			addCode("ADD E E"); 
			addCode("JUMP",code.size()-5);
			addCode("SUB B D");
			addCode("INC E"); 
			addCode("JUMP",code.size()-12);
			addCode("COPY A D"); 
			addCode("SUB A C"); 
			addCode("JZERO A", code.size()+4); 
			addCode("ADD E E"); 
			addCode("HALF D");
			addCode("JUMP", code.size()-5);
			addCode("COPY B E");
			addCode("JUMP", code.size()+2);

			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();
			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();

			addCode("SUB B B");

			if ( std::find(freeRegisters.begin(), freeRegisters.end(), "E") == freeRegisters.end() ) {
				memToRegister("E");
			}
		}

		argumentsTabIndex[0] = "NULL";
		argumentsTabIndex[1] = "NULL";
		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
	}
}
| value MOD value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);

		if(b.type == NUMBER && stoll(b.name) == 0) {
			setRegister("B", "0");
		}
		else if(a.type == NUMBER && stoll(a.name) == 0) {
			setRegister("B", "0");
		}
		else if(a.type == NUMBER && b.type == NUMBER) {
			long long int val = stoll(a.name) % stoll(b.name);
			setRegister("B", std::to_string(val));
			popVariable(a.name);
			popVariable(b.name);
		} else {
			if(a.type == NUMBER) {
				setRegister("B", a.name);
				popVariable(a.name);
			} else if(a.type == IDENTIFIER) {
				memToRegister(a.memory, "B");
			} else if(a.type == ARRAY) {
				if(aI.type == IDENTIFIER)
					arrayIndexToRegister(a, aI, "B");
				else {
					long long int addr = a.memory + stoll(aI.name) + 1 - a.beginTable;
					memToRegister(addr, "B");
					popVariable(aI.name);
				}
			}
			
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");

			if(b.type == NUMBER) {
				setRegister("C", b.name);
				popVariable(b.name);
			} else if(b.type == IDENTIFIER) {
				memToRegister(b.memory, "C");
			} else if(b.type == ARRAY) {
				if(bI.type == IDENTIFIER)
					arrayIndexToRegister(b, bI, "C");
				else {
					long long int addr = b.memory + stoll(bI.name) + 1 - b.beginTable;
					memToRegister(addr, "C");
					popVariable(bI.name);
				}
			}
			
			Jump juma;
			newJump(&juma, code.size(), depth);
			jumps.push_back(juma);
			addCode("JZERO C");

			addCode("COPY D C");
			addCode("SUB D B");
			addCode("JZERO D",code.size()+2); 
			addCode("JUMP", code.size()+25); 
			
			addCode("COPY D B");
			addCode("SUB D C");
			addCode("JZERO D",code.size()+2);
			addCode("JUMP",code.size()+3); 
			addCode("SUB B B");
			addCode("JUMP", code.size()+19); 

			addCode("COPY D C");
			addCode("COPY A D");
			addCode("SUB A B");
			addCode("JZERO A",code.size()+2);
			addCode("JUMP",code.size()+3);
			addCode("ADD D D");
			addCode("JUMP",code.size()-5);
			addCode("COPY A C");
			addCode("SUB A B");
			addCode("JZERO A",code.size()+2);
			addCode("JUMP", code.size()+8);
			addCode("COPY A D");
			addCode("SUB A B");
			addCode("JZERO A",code.size()+3);
			addCode("HALF D");
			addCode("JUMP",code.size()-4);
			addCode("SUB B D");
			addCode("JUMP",code.size()-10);
			addCode("JUMP", code.size()+2);

			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();
			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size());
			jumps.pop_back();

			addCode("SUB B B");			
		}


		argumentsTabIndex[0] = "NULL";
		argumentsTabIndex[1] = "NULL";
		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
	}
}
;

condition: value EQ value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

		if(a.type == NUMBER && b.type == NUMBER) {
			if(stoll(a.name) == stoll(b.name))
				setRegister("B", "1");
			else
				setRegister("B", "0");
			popVariable(a.name);
			popVariable(b.name);
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");
		}
		else {
			if(variables.count(argumentsTabIndex[0]) > 0)
				aI = variables.at(argumentsTabIndex[0]);
			if(variables.count(argumentsTabIndex[1]) > 0)
				bI = variables.at(argumentsTabIndex[1]);

			if(a.type != ARRAY && b.type != ARRAY)
				substract(b, a, bI, aI, 0, 0);
			else
				substract(b, a, bI, aI, 0, 0);

			addCode("JZERO B", code.size()+2);
			Jump j;
			newJump(&j, code.size(), depth);
			jumps.push_back(j);
			addCode("JUMP");

			if(a.type != ARRAY && b.type != ARRAY)
				substract(a, b, aI, bI, 0, 1);
			else
				substract(a, b, aI, bI, 0, 1);

			addCode("JZERO B", code.size()+2);
			Jump jj;
			newJump(&jj, code.size(), depth);
			jumps.push_back(jj);
			addCode("JUMP");
		}

		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
		argumentsTabIndex[0] = "NULL";
		argumentsTabIndex[1] = "NULL";
	}
}
| value NEQ value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

		if(a.type == NUMBER && b.type == NUMBER) {
			if(stoll(a.name) != stoll(b.name))
				setRegister("B", "1");
			else
				setRegister("B", "0");
			popVariable(a.name);
			popVariable(b.name);
			Jump jum;
			newJump(&jum, code.size(), depth);
			jumps.push_back(jum);
			addCode("JZERO B");
		}
		else {
			if(variables.count(argumentsTabIndex[0]) > 0)
				aI = variables.at(argumentsTabIndex[0]);
			if(variables.count(argumentsTabIndex[1]) > 0)
				bI = variables.at(argumentsTabIndex[1]);

			if(a.type != ARRAY && b.type != ARRAY)
				substract(b, a, bI, aI, 0, 0);
			else
				substract(b, a, bI, aI, 0, 0);

			addCode("JZERO B", code.size()+2);
			Jump j;
			newJump(&j, code.size(), depth);
			jumps.push_back(j);
			addCode("JUMP");

			if(a.type != ARRAY && b.type != ARRAY)
				substract(a, b, aI, bI, 0, 1);
			else
				substract(a, b, aI, bI, 0, 1);

			addJumpPlaceToCode(jumps.at(jumps.size()-1).codePosition, code.size()+1);
			jumps.pop_back();
			Jump jj;
			newJump(&jj, code.size(), depth);
			jumps.push_back(jj);
			addCode("JZERO B");
		}

		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
		argumentsTabIndex[0] = "NULL";
		argumentsTabIndex[1] = "NULL";
	}
}
| value LT value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
		Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

		if(a.type == NUMBER && b.type == NUMBER) {
			if(stoll(a.name) < stoll(b.name))
				setRegister("B","1");
			else
				setRegister("B","0");
			popVariable(a.name);
			popVariable(b.name);
		}
		else {

			if(a.type != ARRAY && b.type != ARRAY)
				substract(b, a, bI, aI, 0, 1);
			else {
				if(variables.count(argumentsTabIndex[0]) > 0)
					aI = variables.at(argumentsTabIndex[0]);
				if(variables.count(argumentsTabIndex[1]) > 0)
					bI = variables.at(argumentsTabIndex[1]);
				substract(b, a, bI, aI, 0, 1);
				argumentsTabIndex[0] = "NULL";
				argumentsTabIndex[1] = "NULL";
			}
		}

		Jump j;
		newJump(&j, code.size(), depth);
		jumps.push_back(j);
		addCode("JZERO B");

		expressionArguments[0] = "NULL";
		expressionArguments[1] = "NULL";
	}
}
| value GT value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
        Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

        if(a.type == NUMBER && b.type == NUMBER) {
            if(stoll(b.name) < stoll(a.name))
                setRegister("B", "1");
            else
                setRegister("B", "0");
            popVariable(a.name);
            popVariable(b.name);
        }
        else {
            if(a.type != ARRAY && b.type != ARRAY)
                substract(a, b, aI, bI, 0, 1);
            else {
                
                if(variables.count(argumentsTabIndex[0]) > 0)
                    aI = variables.at(argumentsTabIndex[0]);
                if(variables.count(argumentsTabIndex[1]) > 0)
                    bI = variables.at(argumentsTabIndex[1]);
                substract(a, b, aI, bI, 0, 1);
                argumentsTabIndex[0] = "NULL";
                argumentsTabIndex[1] = "NULL";
            }
        }

        Jump j;
        newJump(&j, code.size(), depth);
        jumps.push_back(j);;
        addCode("JZERO B");

        expressionArguments[0] = "NULL";
        expressionArguments[1] = "NULL";
	}
}
| value LE value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
        Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;

        if(a.type == NUMBER && b.type == NUMBER) {
            if(stoll(a.name) <= stoll(b.name))
                setRegister("B", "1");
            else
                setRegister("B", "0");
            popVariable(a.name);
            popVariable(b.name);
        }
        else {
            if(a.type != ARRAY && b.type != ARRAY)
                substract(b, a, bI, aI, 1, 1);
            else {
                if(variables.count(argumentsTabIndex[0]) > 0)
                    aI = variables.at(argumentsTabIndex[0]);
                if(variables.count(argumentsTabIndex[1]) > 0)
                    bI = variables.at(argumentsTabIndex[1]);
                substract(b, a, bI, aI, 1, 1);
                argumentsTabIndex[0] = "NULL";
                argumentsTabIndex[1] = "NULL";
            }
        }

        Jump j;
        newJump(&j, code.size(), depth);
        jumps.push_back(j);
        addCode("JZERO B");

        expressionArguments[0] = "NULL";
        expressionArguments[1] = "NULL";
	}
}
| value GE value {
	if(!preParsing) {
		Variable a = variables.at(expressionArguments[0]);
        Variable b = variables.at(expressionArguments[1]);
		Variable aI, bI;	

        if(a.type == NUMBER && b.type == NUMBER) {
            if(stoll(a.name) >= stoll(b.name))
                setRegister("B", "1");
            else
                setRegister("B", "0");
            popVariable(a.name);
            popVariable(b.name);
        }
        else {
            if(a.type != ARRAY && b.type != ARRAY)
                substract(a, b, aI, bI, 1, 1);
            else {
                if(variables.count(argumentsTabIndex[0]) > 0)
                    aI = variables.at(argumentsTabIndex[0]);
                if(variables.count(argumentsTabIndex[1]) > 0)
                    bI = variables.at(argumentsTabIndex[1]);
                substract(a, b, aI, bI, 1, 1);
                argumentsTabIndex[0] = "NULL";
                argumentsTabIndex[1] = "NULL";
            }
        }

        Jump j;
        newJump(&j, code.size(), depth);
        jumps.push_back(j);
        addCode("JZERO B");

        expressionArguments[0] = "NULL";
        expressionArguments[1] = "NULL";
        argumentsTabIndex[0] = "NULL";
        argumentsTabIndex[1] = "NULL";
	}
}
;

value: NUM {
	if(!preParsing) {
		if(assignFlag){
			std::cout << "Error [linia " << yylineno << "]: Próba przypisania do stałej." << std::endl;
			exit(1);
		}
		Variable s;
		newVariable(&s, $1, false, NUMBER);
		insertVariable($1, s);
		if (expressionArguments[0] == "NULL"){
			expressionArguments[0] = $1;
		}
		else {
			expressionArguments[1] = $1;
		}
	}
}
| identifier
;

identifier: IDENT {
	if(!preParsing) {
		if(variables.find($1) == variables.end()) {
			std::cout << "Error [linia " << yylineno << "]: Niezadeklarowana zmienna " << $<str>1 << std::endl;
			exit(1);
		} 
		if(!variables.at($1).isTable) {
			if(!assignFlag) {
				if(!variables.at($1).isInit) {
					std::cout << "Error [linia " << yylineno << "]: Użyta niezainicjowana zmienna " << $<str>1 << std::endl;
					exit(1);
				}
				if (expressionArguments[0] == "NULL"){
					expressionArguments[0] = $1;
				}
				else{
					expressionArguments[1] = $1;
				}
			} else {
				assignTarget = variables.at($1);
			}
		} else {
			std::cout << "Error [linia " << yylineno << "]: Przypisanie wartości do całej tablicy " << $<str>1 << std::endl;
			exit(1);
		}
	} else {
		preParseVariableUsage($1);
	}
}
| IDENT LB IDENT RB {
	if(!preParsing) {
		if(variables.find($1) == variables.end()) {
			std::cout << "Error [linia " << yylineno << "]: Niezadeklarowana zmienna " << $<str>1 << std::endl;
			exit(1);
		} 
		if(variables.find($3) == variables.end()) {
			std::cout << "Error [linia " << yylineno << "]: Niezadeklarowana zmienna " << $<str>3 << std::endl;
			exit(1);
		} 

		if(!variables.at($1).isTable) {
			std::cout << "Error [linia " << yylineno << "]: Zmienna " << $<str>1 << " nie jest tablicą!" << std::endl;
			exit(1);
		} else {
			if(variables.at($3).isTable) {
				std::cout << "Error [linia " << yylineno << "]: Indeks tablicy nie może być zmienną tablicową!" << std::endl;
				exit(1);
			}
			if(!variables.at($3).isInit) {
				std::cout << "Error [linia " << yylineno << "]: Użyta zmienna " << $<str>3 << " nie jest zainicjowana!" << std::endl;
				exit(1);
			}
			
			if(false) { 
				std::cout << "Error [linia " << yylineno << "]: Odwołanie do złego indeksu tablicy " << $<str>1 << "!" << std::endl;
				exit(1);
			}

			if(!assignFlag) {
				if (expressionArguments[0] == "NULL"){
					expressionArguments[0] = $1;
					argumentsTabIndex[0] = $3;
				}
				else {
					expressionArguments[1] = $1;
					argumentsTabIndex[1] = $3;
				}
			} else {
				assignTarget = variables.at($1);
				tabAssignTargetIndex = $3;
			}
		}
	} else {
		preParseVariableUsage($3);
	}
}
| IDENT LB NUM RB {
if(!preParsing) {
	if(variables.find($1) == variables.end()) {
		std::cout << "Error [linia " << yylineno << "]: Niezadeklarowana zmienna " << $<str>1 << std::endl;
		exit(1);
	}
	if(!variables.at($1).isTable) {
		std::cout << "Error [linia " << yylineno << "]: Zmienna " << $<str>1 << " nie jest tablicą!" << std::endl;
		exit(1);
	} else {
		if(!(variables.at($1).beginTable <= atoll($3) && variables.at($1).endTable >= atoll($3))) {
			std::cout << "Error [linia " << yylineno << "]: Odwołanie do złego indeksu tablicy " << $<str>1 << "!" << std::endl;
			exit(1);
		}

		Variable s;
		newVariable(&s, $3, false, NUMBER);
		insertVariable($3, s);

		if(!assignFlag){
			if (expressionArguments[0] == "NULL"){
				expressionArguments[0] = $1;
				argumentsTabIndex[0] = $3;
			}
			else{
				expressionArguments[1] = $1;
				argumentsTabIndex[1] = $3;
			}
		}
		else {
			assignTarget = variables.at($1);
			tabAssignTargetIndex = $3;
		}
	}
}
}
;
%%



















void newJump(Jump *j, long long int stack, long long int depth) {
    j->codePosition = stack;
    j->depth = depth;
}

void addJumpPlaceToCode(long long int command, long long int val) {
    code.at(command) = code.at(command) + " " + std::to_string(val);
}

 void substract(Variable a, Variable b, Variable aIndex, Variable bIndex, int isAddingOne, int removingTemps) {
    
    if(a.type == NUMBER && b.type == NUMBER) {
        long long int val = std::max(stoll(a.name) + isAddingOne - stoll(b.name), (long long int) 0);
        setRegister("B", std::to_string(val));
        if(removingTemps) {
            popVariable(a.name);
            popVariable(b.name);
        }
    }
    else if(a.type == NUMBER && b.type == IDENTIFIER) {
        setRegister("B", std::to_string(stoll(a.name) + isAddingOne));
		memToRegister(b.memory, "C");
        addCode("SUB B C");
        if(removingTemps)
            popVariable(a.name);
    }
    else if(a.type == IDENTIFIER && b.type == NUMBER) {
        setRegister("C", b.name);
		memToRegister(a.memory, "B");
		if(isAddingOne) {
			addCode("INC B");
		}
        addCode("SUB B C");
        if(removingTemps)
            popVariable(b.name);
    }
    else if(a.type == IDENTIFIER && b.type == IDENTIFIER) {
        if(a.name == b.name) {
            addCode("SUB B B");
            if(isAddingOne)
                addCode("INC B");
        }
        else {
            memToRegister(a.memory, "B");
			memToRegister(b.memory, "C");
            if(isAddingOne)
                addCode("INC B");
            addCode("SUB B C");
        }
    }
	else if(a.type == NUMBER && b.type == ARRAY) {
        if(bIndex.type == NUMBER) {
            long long int addr = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            setRegister("B", std::to_string(stoll(a.name) + isAddingOne));
			memToRegister(addr, "C");
            addCode("SUB B C");
            if(removingTemps) {
                popVariable(a.name);
                popVariable(bIndex.name);
            }
        }
        else if(bIndex.type == IDENTIFIER) {
            arrayIndexToRegister(b, bIndex, "C");
            setRegister("B", std::to_string(stoll(a.name) + isAddingOne));
            addCode("SUB B C");
            if(removingTemps)
                popVariable(a.name);
        }
    }
    else if(a.type == ARRAY && b.type == NUMBER) {
        if(aIndex.type == NUMBER) {
            long long int addr = a.memory + stoll(aIndex.name) + 1 - a.beginTable;

			setRegister("C", b.name);
			memToRegister(addr, "B");
			if(isAddingOne)
				addCode("INC B");
			addCode("SUB B C");
            
            if(removingTemps) {
                popVariable(b.name);
                popVariable(aIndex.name);
            }
        }
        else if(aIndex.type == IDENTIFIER) {
			arrayIndexToRegister(a, aIndex, "B");   
			setRegister("C", b.name);
			
			if(isAddingOne)
				addCode("INC B");

			addCode("SUB B C");
		
			if(removingTemps)
				popVariable(b.name);
        }
    }
    else if(a.type == IDENTIFIER && b.type == ARRAY) {
        if(bIndex.type == NUMBER) {
            long long int addr = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            memToRegister(a.memory, "B");
			memToRegister(addr, "C");
            if(isAddingOne)
                addCode("INC B");
            addCode("SUB B C");
            if(removingTemps)
                popVariable(bIndex.name);
        }
        else if(bIndex.type == IDENTIFIER) {
            arrayIndexToRegister(b, bIndex, "C");
            memToRegister(a.memory, "B");
            if(isAddingOne)
                addCode("INC B");
            addCode("SUB B C");
        }
    }
    else if(a.type == ARRAY && b.type == IDENTIFIER) {
        if(aIndex.type == NUMBER) {
            long long int addr = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            memToRegister(b.memory, "C");
			memToRegister(addr, "B");
			
            if(isAddingOne)
                addCode("INC B");
            addCode("SUB B C");
            if(removingTemps)
                popVariable(aIndex.name);
        }
        else if(aIndex.type == IDENTIFIER) {
            arrayIndexToRegister(a, aIndex, "B");
            memToRegister(b.memory, "C");
            if(isAddingOne)
                addCode("INC B");
            addCode("SUB B C");
        }
    }
    else if(a.type == ARRAY && b.type == ARRAY) {
        if(aIndex.type == NUMBER && bIndex.type == NUMBER) {
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            if(a.name == b.name && addrA == addrB) {
                addCode("SUB B B");
                if(isAddingOne)
                    addCode("INC B");
            }
            else {
                memToRegister(addrA, "B");
				memToRegister(addrB, "C");
                if(isAddingOne)
                    addCode("INC B");
                addCode("SUB B C");
            }
            if(removingTemps) {
                popVariable(aIndex.name);
                popVariable(bIndex.name);
            }
        }
        else if(aIndex.type == NUMBER && bIndex.type == IDENTIFIER) {
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            arrayIndexToRegister(b, bIndex, "C");
            memToRegister(addrA, "B");
            if(isAddingOne)
                addCode("INC B");
            addCode("SUB B C");
            if(removingTemps)
                popVariable(aIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == NUMBER) {
            long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            arrayIndexToRegister(a, aIndex, "B");
            memToRegister(addrB, "C");
            if(isAddingOne)
                addCode("INC B");
            addCode("SUB B C");
            if(removingTemps)
                popVariable(bIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == IDENTIFIER) {
            if(a.name == b.name && aIndex.name == bIndex.name) {
                addCode("SUB B B");
                if(isAddingOne)
                    addCode("INC B");
            }
            else {
                arrayIndexToRegister(a, aIndex, "B");
				arrayIndexToRegister(b, bIndex, "C");
                if(isAddingOne)
                    addCode("INC B");
                addCode("SUB B C");
            }
        }
    }
}

void addition(Variable a, Variable b, Variable aIndex, Variable bIndex) {
	if(a.type == NUMBER && b.type == NUMBER) {
		long long int val = stoll(a.name) + stoll(b.name);
        setRegister("B", std::to_string(val));
        popVariable(a.name);
        popVariable(b.name);
	} else if((a.type == NUMBER && b.type == IDENTIFIER) || (b.type == NUMBER && a.type == IDENTIFIER)) {
		Variable c = ((a.type == NUMBER) ? a : b);
		Variable d = ((a.type == NUMBER) ? b : a);
		if(stoll(c.name) <= 3) {
			memToRegister(d.memory, "B");
            for(int i=0; i < stoll(c.name); i++) {
                addCode("INC B");
            }
            popVariable(c.name);
        }
        else {
            setRegister("B", c.name);
			memToRegister(d.memory, "C");
            addCode("ADD B C");
            popVariable(c.name);
        }
	} else if(a.type == IDENTIFIER && b.type == IDENTIFIER) {
		if(a.name == b.name) {
            memToRegister(a.memory, "B");
            addCode("ADD B B");
        }
        else {
            memToRegister(a.memory, "B");
			memToRegister(b.memory, "C");
            addCode("ADD B C");
        }
	} else if((a.type == NUMBER && b.type == ARRAY) || (a.type == ARRAY && b.type == NUMBER)) {
		if(a.type == ARRAY) {
			Variable temp = a;
			a = b;
			b = temp;
			temp = aIndex;
			aIndex = bIndex;
			bIndex = temp;
		}
        if(bIndex.type == NUMBER) { 
            long long int addr = b.memory + stoll(bIndex.name) + 1 - b.beginTable;

			if(stoll(a.name) <= 3) {
				memToRegister(addr, "B");
				for(int i=0; i < stoll(a.name); i++) {
					addCode("INC B");
				}
			}
            else {
                setRegister("C", a.name);
                memToRegister(addr, "B");
				addCode("ADD B C");
            }

            popVariable(a.name);
            popVariable(bIndex.name);
        }
        else if(bIndex.type == IDENTIFIER) { 

            arrayIndexToRegister(b, bIndex, "B");

			if(stoll(a.name) <= 3) {
				for(int i=0; i < stoll(a.name); i++) {
					addCode("INC B");
				}
			} else {
                setRegister("C", a.name);
				addCode("ADD B C");
            }

            popVariable(a.name);
        }
    }
    else if((a.type == IDENTIFIER && b.type == ARRAY) | (a.type == ARRAY && b.type == IDENTIFIER) ) {
		Variable cIndex;
		if(a.type == ARRAY) {
			Variable temp = a;
			a = b;
			b = temp;
			cIndex = aIndex;
		} else {
			cIndex = bIndex;
		}
    
        if(cIndex.type == NUMBER) { 
			long long int addr = b.memory + stoll(cIndex.name) + 1 - b.beginTable;
			memToRegister(a.memory, "B");
			memToRegister(addr, "C");
            addCode("ADD B C");
            popVariable(cIndex.name);
        }
        else if(cIndex.type == IDENTIFIER) { 
			arrayIndexToRegister(b, cIndex, "B"); 
			memToRegister(a.memory, "C");
			addCode("ADD B C");
        }
    }
    else if(a.type == ARRAY && b.type == ARRAY) {
        if(aIndex.type == NUMBER && bIndex.type == NUMBER) {
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            if(a.name == b.name && addrA == addrB) {
                memToRegister(addrA, "B");
                addCode("ADD B B");
            }
            else {
                memToRegister(addrA, "B");
				memToRegister(addrB, "C");
                addCode("ADD B C");
            }
            popVariable(aIndex.name);
            popVariable(bIndex.name);
        }
        else if(aIndex.type == NUMBER && bIndex.type == IDENTIFIER) { 
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
			arrayIndexToRegister(b, bIndex, "B");
			memToRegister(addrA, "C");
			addCode("ADD B C");
            popVariable(aIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == NUMBER) {
			long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
			arrayIndexToRegister(a, aIndex, "B");
			memToRegister(addrB, "C");
			addCode("ADD B C");
            popVariable(bIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == IDENTIFIER) {
            if(a.name == b.name && aIndex.name == bIndex.name) {
                arrayIndexToRegister(a, aIndex, "B");
				addCode("ADD B B");
            }
            else {
                arrayIndexToRegister(a, aIndex, "B");
				arrayIndexToRegister(b, bIndex, "C");

				addCode("ADD B C");
            }
        }
    }
}

void arrayIndexToRegister(Variable tab, Variable index, std::string reg) {
	long long int offset = tab.memory + 1;
	if(index.inRegister == "NULL") {
		memToRegister(index.memory, "C");
	} else {
		addCode("COPY C " + index.inRegister);
	}
	setRegister("A", std::to_string(offset));
	addCode("ADD A C");
	setRegister("C", std::to_string(tab.beginTable));
	addCode("SUB A C");
	addCode("LOAD " + reg);
}

void setRegister(std::string reg, std::string number) {
    long long int n = stoll(number);
	
    std::string bin = toBinary(n);
	long long int limit = bin.size();
   
	addCode("SUB " + reg + " " + reg);
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			addCode("INC " + reg);
			
		}
		if(i < (limit - 1)){
	        addCode("ADD " + reg + " " + reg);
	        
		}
	}
}

void memToRegister(std::string reg) {
	long long int mem;
	for (std::map<std::string, Variable>::iterator it=variables.begin(); it!=variables.end(); ++it) {
		if(it->second.inRegister == reg) {
			mem = it->second.memory;
			break;
		}
	}

	addCode("SUB A A");
	std::string bin = toBinary(mem);
	long long int limit = bin.size();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			addCode("INC A");
			
		}
		if(i < (limit - 1)){
	        addCode("ADD A A");
	        
		}
	}
    addCode("LOAD " + reg); 
}
void memToRegister(long long int mem, std::string reg) {

	std::string srcReg;
	bool flag = false;
	for (std::map<std::string, Variable>::iterator it=variables.begin(); it!=variables.end(); ++it) {
		if(it->second.memory == mem && it->second.inRegister != "NULL") {
			srcReg = it->second.inRegister;
			flag = true;
			break;
		}
	}

	if(flag) {
		addCode("COPY " + reg + " " + srcReg);
	} else {
		addCode("SUB A A");
		std::string bin = toBinary(mem);
		long long int limit = bin.size();
		for(long long int i = 0; i < limit; ++i){
			if(bin[i] == '1'){
				addCode("INC A");
				
			}
			if(i < (limit - 1)){
				addCode("ADD A A");
				
			}
		}
		addCode("LOAD " + reg); 
	}
}

std::string toBinary(long long int n) {
    std::string r;
    while(n!=0) {
		r=(n%2==0 ?"0":"1")+r; 
		n/=2;
	}
    return r;
}

void registerToMem(std::string reg) {
	long long int mem;
	for (std::map<std::string, Variable>::iterator it=variables.begin(); it!=variables.end(); ++it) {
		if(it->second.inRegister == reg ) {
			mem = it->second.memory;
			break;
		}
	}

	addCode("SUB A A");
	std::string bin = toBinary(mem);
	long long int limit = bin.size();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			addCode("INC A");
			
		}
		if(i < (limit - 1)){
	        addCode("ADD A A");
	        
		}
	}
    addCode("STORE " + reg); 
}
void registerToMem(std::string reg, long long int mem) {
	
	std::string srcReg;
	bool flag = false;
	for (std::map<std::string, Variable>::iterator it=variables.begin(); it!=variables.end(); ++it) {
		if(it->second.memory == mem && it->second.inRegister != "NULL") {
			srcReg = it->second.inRegister;
			flag = true;
			break;
		}
	}
	
	if(flag) {
		addCode("COPY " + srcReg + " " + reg);
	} else {
		addCode("SUB A A");
		std::string bin = toBinary(mem);
		long long int limit = bin.size();
		for(long long int i = 0; i < limit; ++i){
			if(bin[i] == '1'){
				addCode("INC A");
				
			}
			if(i < (limit - 1)){
				addCode("ADD A A");
				
			}
		}
		addCode("STORE " + reg); 
	}
}

void newVariable(Variable* id, std::string name, bool isLocal, Type type) {
	id->name = name;
	id->memory = memoryIndex;
	id->type = type;
	id->isInit = false;
	id->isLocal = isLocal;
	id->isTable = false;
	id->beginTable = -1;
	id->endTable = -1;

	if(type != IDENTIFIER)
		id->inRegister = "NULL";
	else
		id->inRegister = registerValue(name);
}
void newVariable(Variable* id, std::string name, bool isLocal, Type type, long long int begin, long long int end) {
	id->name = name;
	id->memory = memoryIndex;
	id->type = type;
	id->isInit = false;
	id->isLocal = isLocal;
	id->isTable = true;
	id->beginTable = begin;
	id->endTable = end;
	id->inRegister = "NULL";
}
void popVariable(std::string key) {
    if(variables.count(key) > 0) {
		std::string reg = variables.at(key).inRegister;
		if(reg != "NULL") {
			if(!(key == preParsingVars[0] || key == preParsingVars[1] || key == preParsingVars[2] || key == preParsingVars[3]))
				freeRegisters.push_back(reg);
			
			addCode("SUB " + reg + " " + reg);
		}
        if(variables.at(key).numberAmount > 0) {
            variables.at(key).numberAmount = variables.at(key).numberAmount-1;
        }
        else {
            variables.erase(key);
            memoryIndex--;
        }
    }
}
void insertVariable(std::string key, Variable i) {
    if(variables.count(key) == 0) {
        variables.insert(make_pair(key, i));
        variables.at(key).numberAmount = 0;
        memoryIndex++;
    }
    else {
        variables.at(key).numberAmount = variables.at(key).numberAmount+1;
    }
	if(i.inRegister == "NNULL")//debug
    	std::cout << "Add: " << key << " name: " << i.name << " type: " << i.type << " memory:" << memoryIndex-1 << " reg:" << i.inRegister << std::endl;
}

void addCode(std::string str) {
    code.push_back(str);
}

void addCode(std::string str, long long int num) {
    std::string temp = str + " " + std::to_string(num);
    code.push_back(temp);
}

void printCode(std::string filename) {
	std::ofstream out_code(filename);
	long long int i;
	for(i = 0; i < code.size(); i++)
        out_code << code.at(i) << std::endl;
}

int isPowerOfTwo(long long int x) {
	int amount = 0;
	int nmb = 1;
	while(nmb < x) {
		nmb = nmb*2;
		amount++;
	}
	if(nmb == x) {
		return amount;
	} else {
		return -1;
	}
}

std::string registerValue(std::string name) {
	if(preParsingVars.size() >= 1 && preParsingVars[0] == name) {
		return "H";
	}
	else if(preParsingVars.size() >= 2 && preParsingVars[1] == name) {
		return "G";
	}
	else if(preParsingVars.size() >= 3 && preParsingVars[2] == name) {
		return "F";
	}
	else if(preParsingVars.size() >= 4 && preParsingVars[3] == name) {
		return "E";
	}
	else if(preParsingVars.size() >= 4) {
		return "NULL";
	} else {
		std::string reg = freeRegisters.at(freeRegisters.size()-1);
		freeRegisters.pop_back();
		return reg;
	}
}

void preParseVariableUsage(std::string var) {
	int i=0;
	while(i<preParsingVars.size()) {
		if(preParsingVars[i] == var) {
			preParsingCount[i] += weight; 
			break;
		}
		i++;
	}
	if(i==preParsingVars.size()) {
		preParsingVars.push_back(var);
		preParsingCount.push_back(weight); 
	}
}

void sortVariableUsage() {
	for(int i=0; i<preParsingCount.size(); ++i) {
		for(int j=1; j<(preParsingCount.size()-i); ++j) {
			if(preParsingCount[j-1] < preParsingCount[j]) {
				std::string tmp1 = preParsingVars[j-1];
				int tmp2 = preParsingCount[j-1];
				preParsingVars[j-1] = preParsingVars[j];
				preParsingCount[j-1] = preParsingCount[j];
				preParsingVars[j] = tmp1;
				preParsingCount[j] = tmp2;
			}
		}
	}
	for(int i=0; i<preParsingVars.size(); ++i) {
		//std::cout << preParsingVars[i] << ": " << preParsingCount[i] << " użyć" << "\n"; //debug
	}
}

int yyerror(const std::string s) {
	std::cout << "Error [około linii " << yylineno << "]: " << s << std::endl;
	exit(1);
}


int main (int argc, char** argv) {

	assignFlag = true;
	memoryIndex = 0;
	writeFlag = false;
	depth = 0;
	
	preParsing = true;
	weight = 1; 
	yyin = fopen(argv[1], "r");
    yyparse();
	sortVariableUsage();

	preParsing = false;
	depth = 0;

	if(preParsingVars.size() < 4) {
		int v = preParsingVars.size();
		std::string regs[] = {"E","F","G","H"};
		while(v < 4) {
			freeRegisters.push_back(regs[3-v]);
			v++;
		}
	}
		
	yyin = fopen(argv[1], "r");
	yyparse();

	if(argc < 3) {
		return -1;
	} else {
		printCode(argv[2]);
	}

	return 0;
}
