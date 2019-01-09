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
bool assignFlag, writeFlag;
std::vector<std::string> freeRegisters;
Jump tj;
int indextj;

std::vector<std::string> code;
std::map<std::string, Variable> variables;
std::vector<Jump> jumps;
std::vector<Variable> forVariables;

Variable assignTarget;
std::string tabAssignTargetIndex = "-1";
std::string expressionArguments[2] = {"-1", "-1"};
std::string argumentsTabIndex[2] = {"-1", "-1"};

int yyerror (const std::string);
extern int yylineno;
extern FILE * yyin;
int yylex();
void addInt(long long int, long long int);
void newJump(Jump *j, long long int, long long int);
void addition(Variable a, Variable b);
void arrayAddition(Variable a, Variable b, Variable aIndex, Variable bIndex);
void substract(Variable, Variable, int, int);
void arraySubstract(Variable, Variable, Variable, Variable, int, int);
void arrayIndexToRegister(Variable tab, Variable index, std::string reg);
void setRegister(std::string, std::string);
void newVariable(Variable* id, std::string name, bool isLocal, Type type);
void newVariable(Variable* id, std::string name, bool isLocal, Type type, long long int begin, long long int end);
void popVariable(std::string key);
void insertVariable(std::string, Variable);
void pushCommand(std::string);
void pushCommand(std::string, long long int);
void memToRegister(long long int, std::string);
void memToRegister(std::string);
std::string decToBin(long long int);
void registerToMem(std::string, long long int);
void registerToMem(std::string);
int isPowerOfTwo(long long int);
std::string registerValue();
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
	pushCommand("HALT");
}
;

declarations: 
| declarations IDENT COLON {
	if(variables.find($2) != variables.end()) {
		std::cout << "Error [linia " << yylineno << "]: Kolejna deklaracja zmiennej " << $<str>2 << std::endl;
		exit(1);
	} else {
		Variable ide;
		newVariable(&ide, $2, false, IDENTIFIER);
		insertVariable($2, ide);
	}
}
| declarations IDENT LB NUM INDEXER NUM RB COLON {
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
;

newlabel: WHILE {
	assignFlag = false;
	Jump j;
	newJump(&j, code.size(), depth);
	tj = j;
	indextj = jumps.size();
}
;

commands: commands command
| command
;

command: identifier ASSIGN {
	assignFlag = false;
} expression COLON {
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
				pushCommand("COPY C " + index.inRegister);
			}
			setRegister("A", std::to_string(offset));
			pushCommand("ADD A C");
			setRegister("C", std::to_string(assignTarget.beginTable));
			pushCommand("SUB A C");
			pushCommand("STORE B");
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
| IF {
	assignFlag = false;
	depth++;
} condition {
	assignFlag = true;
} THEN commands ifbody

| FOR IDENT {
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
} FROM value forbody

| READ {
	assignFlag = true;
} identifier COLON {
	if(assignTarget.type == ARRAY) {
		Variable index = variables.at(tabAssignTargetIndex);
		if(index.type == NUMBER) {
			pushCommand("GET B");
			long long int tabElMem = assignTarget.memory + stoll(index.name) + 1 - assignTarget.beginTable;
			registerToMem("B", tabElMem);
			popVariable(index.name);
		}
		else {
			long long int offset = assignTarget.memory + 1;
			if(index.inRegister == "NULL") {
				memToRegister(index.memory, "C");
				
			} else {
				pushCommand("COPY C " + index.inRegister);
			}
			setRegister("A", std::to_string(offset));
				pushCommand("ADD A C");
			setRegister("C", std::to_string(assignTarget.beginTable));
			pushCommand("SUB A C");
			pushCommand("GET B");
			pushCommand("STORE B");
		}

	} else if(!assignTarget.isLocal) {
		pushCommand("GET B"); 
		registerToMem("B", assignTarget.memory);
	} else {
		std::cout << "Error [linia " << yylineno << "]: Próba modyfikacji iteratora pętli." << std::endl;
        exit(1);
	}
	variables.at(assignTarget.name).isInit = true;
	assignFlag = true;
}
| WRITE {
	assignFlag = false;
	writeFlag = true;
} value COLON {
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
	pushCommand("PUT B"); 
	assignFlag = true;
	writeFlag = false;
	expressionArguments[0] = "-1";
	argumentsTabIndex[0] = "-1";
}
| newlabel condition {
	assignFlag = true;
	depth++;
	jumps.insert(jumps.begin() + indextj, tj);
	for(int i=indextj; i<jumps.size(); ++i) {
		jumps[i].depth = depth;
	}
}  DO commands ENDWHILE {
	long long int stack;
	long long int jumpCount = jumps.size()-1;
	if(jumpCount > 2 && jumps.at(jumpCount-2).depth == depth) {
		stack = jumps.at(jumpCount-2).codePosition;
		pushCommand("JUMP", stack);
		addInt(jumps.at(jumpCount).codePosition, code.size());
		addInt(jumps.at(jumpCount-1).codePosition, code.size());
		jumps.pop_back();
	}
	else {
		stack = jumps.at(jumpCount-1).codePosition;
		pushCommand("JUMP", stack);
		addInt(jumps.at(jumpCount).codePosition, code.size());
	}
	jumps.pop_back();
	jumps.pop_back();

	depth--;
	assignFlag = true;
}
| DO {
	assignFlag = true;
	depth++;
	Jump j;
	newJump(&j, code.size(), depth);
	jumps.push_back(j);
} commands newlabel condition ENDDO {
	long long int stack;
	long long int jumpCount = jumps.size()-1;
	if(jumpCount > 2 && jumps.at(jumpCount-2).depth == depth) {
		stack = jumps.at(jumpCount-2).codePosition;
		pushCommand("JUMP", stack);
		addInt(jumps.at(jumpCount).codePosition, code.size());
		addInt(jumps.at(jumpCount-1).codePosition, code.size());
		jumps.pop_back();
	}
	else {
		stack = jumps.at(jumpCount-1).codePosition;
		pushCommand("JUMP", stack);
		addInt(jumps.at(jumpCount).codePosition, code.size());
	}
	jumps.pop_back();
	jumps.pop_back();

	depth--;
	assignFlag = true;
} 
;


ifbody: ELSE {
	Jump j;
	newJump(&j, code.size(), depth);
	jumps.push_back(j);
	
	pushCommand("JUMP");
	long long int jumpCount = jumps.size()-2;
	Jump jump = jumps.at(jumpCount);
	addInt(jump.codePosition, code.size());
	
	jumpCount--;
	if(jumpCount >= 0 && jumps.at(jumpCount).depth == depth) {
		addInt(jumps.at(jumpCount).codePosition, code.size());
	}
	
	assignFlag = true;
} commands ENDIF {
	addInt(jumps.at(jumps.size()-1).codePosition, code.size());

	jumps.pop_back();
	jumps.pop_back();
	if(jumps.size() >= 1 && jumps.at(jumps.size()-1).depth == depth) {
		jumps.pop_back();
	}
	depth--;
	assignFlag = true;
}
| ENDIF {
	long long int jumpCount = jumps.size()-1;
	addInt(jumps.at(jumpCount).codePosition, code.size());
	jumpCount--;
	if(jumpCount >= 0 && jumps.at(jumpCount).depth == depth) {
		addInt(jumps.at(jumpCount).codePosition, code.size());
		jumps.pop_back();
	}
	jumps.pop_back();
	depth--;
	assignFlag = true;
}
;


forbody: TO value DO {
	Variable a = variables.at(expressionArguments[0]);
	Variable b = variables.at(expressionArguments[1]);

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
		substract(b, a, 1, 1);
	else {
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);
		arraySubstract(b, a, bI, aI, 1, 1);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";

	Variable s;
	std::string name = "C" + std::to_string(depth);
	newVariable(&s, name, true, IDENTIFIER);
	insertVariable(name, s);

	registerToMem("B",variables.at(name).memory);
	forVariables.push_back(variables.at(assignTarget.name));

	pushCommand("JZERO B");
	Jump jj;
	newJump(&jj, code.size(), depth);
	jumps.push_back(jj);

	memToRegister(variables.at(name).memory, "B");
	
	addInt(jumps.at(jumps.size()-1).codePosition-1, code.size());

	Jump j;
	newJump(&j, code.size(), depth);
	jumps.push_back(j);
	pushCommand("JZERO B");
	pushCommand("DEC B");
	registerToMem("B", variables.at(name).memory);
	assignFlag = true;

} commands ENDFOR {
	Variable iterator = forVariables.at(forVariables.size()-1);
	memToRegister(iterator.memory, "B");
	pushCommand("INC B");
	registerToMem("B", iterator.memory);

	long long int jumpCount = jumps.size()-1;
	long long int stack = jumps.at(jumpCount-1).codePosition;
	pushCommand("JUMP", stack);
	addInt(jumps.at(jumpCount).codePosition, code.size());
	jumps.pop_back();
	jumps.pop_back();
	
	std::string name = "C" + std::to_string(depth);
	
	popVariable(name); 
	popVariable(iterator.name);
	forVariables.pop_back();

	depth--;
	assignFlag = true;
}
| DOWNTO value DO {
	Variable a = variables.at(expressionArguments[0]);
	Variable b = variables.at(expressionArguments[1]);

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
		substract(a, b, 1, 1);
	else {
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);
		arraySubstract(a, b, aI, bI, 1, 1);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";

	Variable s;
	std::string name = "C" + std::to_string(depth);
	newVariable(&s, name, true, IDENTIFIER);
	insertVariable(name, s);

	registerToMem("B",variables.at(name).memory);
	forVariables.push_back(variables.at(assignTarget.name));

	pushCommand("JZERO B");
	Jump jj;
	newJump(&jj, code.size(), depth);
	jumps.push_back(jj);

	memToRegister(variables.at(name).memory, "B");
	
	addInt(jumps.at(jumps.size()-1).codePosition-1, code.size());

	Jump j;
	newJump(&j, code.size(), depth);
	jumps.push_back(j);
	pushCommand("JZERO B");
	pushCommand("DEC B");
	registerToMem("B", variables.at(name).memory);
	assignFlag = true;

} commands ENDFOR {
	Variable iterator = forVariables.at(forVariables.size()-1);
	memToRegister(iterator.memory, "B");
	pushCommand("DEC B");
	registerToMem("B", iterator.memory);

	long long int jumpCount = jumps.size()-1;
	long long int stack = jumps.at(jumpCount-1).codePosition;
	pushCommand("JUMP", stack);
	addInt(jumps.at(jumpCount).codePosition, code.size());
	jumps.pop_back();
	jumps.pop_back();

	std::string name = "C" + std::to_string(depth);
	popVariable(name);
	popVariable(iterator.name);
	forVariables.pop_back();

	depth--;
	assignFlag = true;
}
;

expression: value {
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
		expressionArguments[0] = "-1";
		argumentsTabIndex[0] = "-1";
	}
}
| value ADD value {
	Variable a = variables.at(expressionArguments[0]);
	Variable b = variables.at(expressionArguments[1]);
	if(a.type != ARRAY && b.type != ARRAY)
		addition(a, b);
	else {
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);
		arrayAddition(a, b, aI, bI);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value SUB value {
	Variable a = variables.at(expressionArguments[0]);
	Variable b = variables.at(expressionArguments[1]);
	if(a.type != ARRAY && b.type != ARRAY)
		substract(a, b, 0, 1);
	else {
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);
		arraySubstract(a, b, aI, bI, 0, 1);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value MUL value {
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
		pushCommand("JZERO B");

		for(int i=0; i<times; ++i) {
			pushCommand("ADD B B");
		}

		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
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
		pushCommand("JZERO B");

		for(int i=0; i<times; ++i) {
			pushCommand("ADD B B");
		}

		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
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
		pushCommand("JZERO B");

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
		
		pushCommand("JZERO C ",code.size()+10);  
		pushCommand("SUB D D");
		pushCommand("JZERO B", code.size()+9); 
		pushCommand("JODD B ", code.size()+2); 
		pushCommand("JUMP", code.size()+2);
		pushCommand("ADD D C");
		pushCommand("HALF B");
		pushCommand("ADD C C");
		pushCommand("JUMP",code.size()-6);
		pushCommand("JUMP",code.size()+2);

		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
		jumps.pop_back();

		pushCommand("SUB D D");
		pushCommand("COPY B D");	
	}

	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value DIV value {
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
		pushCommand("JZERO B");

		for(int i=0; i<times; ++i) {
			pushCommand("HALF B");
		}

		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
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
		pushCommand("JZERO B");

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
		pushCommand("JZERO C");

		if ( std::find(freeRegisters.begin(), freeRegisters.end(), "E") == freeRegisters.end() ) {
			registerToMem("E");
		} 
		
		
		

		pushCommand("SUB E E"); 
		pushCommand("COPY D C");
		pushCommand("SUB D B");
		pushCommand("JZERO D",code.size()+3); 
		pushCommand("SUB B B");
		pushCommand("JUMP", code.size()+35); 
		
		pushCommand("COPY D B");
		pushCommand("SUB D C");
		pushCommand("JZERO D",code.size()+2);
		pushCommand("JUMP",code.size()+4); 
		pushCommand("SUB B B");
		pushCommand("INC B");
		pushCommand("JUMP", code.size()+28); 

		pushCommand("COPY D C");
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",code.size()+2);
		pushCommand("JUMP",code.size()+3);
		pushCommand("ADD D D");
		pushCommand("JUMP",code.size()-5);
		pushCommand("COPY A C");
		pushCommand("SUB A B");
		pushCommand("JZERO A",code.size()+2);
		pushCommand("JUMP", code.size()+10);
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",code.size()+4);
		pushCommand("HALF D");
		pushCommand("ADD E E"); 
		pushCommand("JUMP",code.size()-5);
		pushCommand("SUB B D");
		pushCommand("INC E"); 
		pushCommand("JUMP",code.size()-12);
		pushCommand("COPY A D"); 
		pushCommand("SUB A C"); 
		pushCommand("JZERO A", code.size()+4); 
		pushCommand("ADD E E"); 
		pushCommand("HALF D");
		pushCommand("JUMP", code.size()-5);
		pushCommand("COPY B E");
		pushCommand("JUMP", code.size()+2);

		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
		jumps.pop_back();
		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
		jumps.pop_back();

		pushCommand("SUB B B");

		if ( std::find(freeRegisters.begin(), freeRegisters.end(), "E") == freeRegisters.end() ) {
			memToRegister("E");
		}
	}

	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value MOD value {
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
		pushCommand("JZERO B");

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
		pushCommand("JZERO C");

		pushCommand("COPY D C");
		pushCommand("SUB D B");
		pushCommand("JZERO D",code.size()+2); 
		pushCommand("JUMP", code.size()+25); 
		
		pushCommand("COPY D B");
		pushCommand("SUB D C");
		pushCommand("JZERO D",code.size()+2);
		pushCommand("JUMP",code.size()+3); 
		pushCommand("SUB B B");
		pushCommand("JUMP", code.size()+19); 

		pushCommand("COPY D C");
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",code.size()+2);
		pushCommand("JUMP",code.size()+3);
		pushCommand("ADD D D");
		pushCommand("JUMP",code.size()-5);
		pushCommand("COPY A C");
		pushCommand("SUB A B");
		pushCommand("JZERO A",code.size()+2);
		pushCommand("JUMP", code.size()+8);
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",code.size()+3);
		pushCommand("HALF D");
		pushCommand("JUMP",code.size()-4);
		pushCommand("SUB B D");
		pushCommand("JUMP",code.size()-10);
		pushCommand("JUMP", code.size()+2);

		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
		jumps.pop_back();
		addInt(jumps.at(jumps.size()-1).codePosition, code.size());
		jumps.pop_back();

		pushCommand("SUB B B");			
	}


	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
;

condition: value EQ value {
	Variable a = variables.at(expressionArguments[0]);
	Variable b = variables.at(expressionArguments[1]);

	if(a.type == NUMBER && b.type == NUMBER) {
		if(stoll(a.name) == stoll(b.name))
			setRegister("B", "1");
		else
			setRegister("B", "0");
		popVariable(a.name);
		popVariable(b.name);
		Jump jum;
		newJump(&jum, code.size(), depth);
		std::cout << "jump na " << code.size() << " d:" << depth << "\n";
		jumps.push_back(jum);
		pushCommand("JZERO B");
	}
	else {
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);

		if(a.type != ARRAY && b.type != ARRAY)
			substract(b, a, 0, 0);
		else
			arraySubstract(b, a, bI, aI, 0, 0);

		pushCommand("JZERO B", code.size()+2);
		Jump j;
		newJump(&j, code.size(), depth);
		jumps.push_back(j);
		pushCommand("JUMP");

		if(a.type != ARRAY && b.type != ARRAY)
			substract(a, b, 0, 1);
		else
			arraySubstract(a, b, aI, bI, 0, 1);

		pushCommand("JZERO B", code.size()+2);
		Jump jj;
		newJump(&jj, code.size(), depth);
		jumps.push_back(jj);
		pushCommand("JUMP");
	}

	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
}
| value NEQ value {
	Variable a = variables.at(expressionArguments[0]);
	Variable b = variables.at(expressionArguments[1]);

	if(a.type == NUMBER && b.type == NUMBER) {
		if(stoll(a.name) != stoll(b.name))
			setRegister("B", "1");
		else
			setRegister("B", "0");
		popVariable(a.name);
		popVariable(b.name);
		Jump jum;
		newJump(&jum, code.size(), depth);
		std::cout << "jump na " << code.size() << " d:" << depth << "\n";
		jumps.push_back(jum);
		pushCommand("JZERO B");
	}
	else {
		Variable aI, bI;
		if(variables.count(argumentsTabIndex[0]) > 0)
			aI = variables.at(argumentsTabIndex[0]);
		if(variables.count(argumentsTabIndex[1]) > 0)
			bI = variables.at(argumentsTabIndex[1]);

		if(a.type != ARRAY && b.type != ARRAY)
			substract(b, a, 0, 0);
		else
			arraySubstract(b, a, bI, aI, 0, 0);

		pushCommand("JZERO B", code.size()+2);
		Jump j;
		newJump(&j, code.size(), depth);
		jumps.push_back(j);
		pushCommand("JUMP");

		if(a.type != ARRAY && b.type != ARRAY)
			substract(a, b, 0, 1);
		else
			arraySubstract(a, b, aI, bI, 0, 1);

		addInt(jumps.at(jumps.size()-1).codePosition, code.size()+1);
		jumps.pop_back();
		Jump jj;
		newJump(&jj, code.size(), depth);
		jumps.push_back(jj);
		pushCommand("JZERO B");
	}

	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
}
| value LT value {
	Variable a = variables.at(expressionArguments[0]);
	Variable b = variables.at(expressionArguments[1]);

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
			substract(b, a, 0, 1);
		else {
			Variable aI, bI;
			if(variables.count(argumentsTabIndex[0]) > 0)
				aI = variables.at(argumentsTabIndex[0]);
			if(variables.count(argumentsTabIndex[1]) > 0)
				bI = variables.at(argumentsTabIndex[1]);
			arraySubstract(b, a, bI, aI, 0, 1);
			argumentsTabIndex[0] = "-1";
			argumentsTabIndex[1] = "-1";
		}
	}

	Jump j;
	newJump(&j, code.size(), depth);
	jumps.push_back(j);
	pushCommand("JZERO B");

	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value GT value {
	Variable a = variables.at(expressionArguments[0]);
        Variable b = variables.at(expressionArguments[1]);

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
                substract(a, b, 0, 1);
            else {
                Variable aI, bI;
                if(variables.count(argumentsTabIndex[0]) > 0)
                    aI = variables.at(argumentsTabIndex[0]);
                if(variables.count(argumentsTabIndex[1]) > 0)
                    bI = variables.at(argumentsTabIndex[1]);
                arraySubstract(a, b, aI, bI, 0, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        newJump(&j, code.size(), depth);
        jumps.push_back(j);;
        pushCommand("JZERO B");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
}
| value LE value {
	Variable a = variables.at(expressionArguments[0]);
        Variable b = variables.at(expressionArguments[1]);

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
                substract(b, a, 1, 1);
            else {
                Variable aI, bI;
                if(variables.count(argumentsTabIndex[0]) > 0)
                    aI = variables.at(argumentsTabIndex[0]);
                if(variables.count(argumentsTabIndex[1]) > 0)
                    bI = variables.at(argumentsTabIndex[1]);
                arraySubstract(b, a, bI, aI, 1, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        newJump(&j, code.size(), depth);
        jumps.push_back(j);
        pushCommand("JZERO B");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
}
| value GE value {
	Variable a = variables.at(expressionArguments[0]);
        Variable b = variables.at(expressionArguments[1]);

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
                substract(a, b, 1, 1);
            else {
                Variable aI, bI;
                if(variables.count(argumentsTabIndex[0]) > 0)
                    aI = variables.at(argumentsTabIndex[0]);
                if(variables.count(argumentsTabIndex[1]) > 0)
                    bI = variables.at(argumentsTabIndex[1]);
                arraySubstract(a, b, aI, bI, 1, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        newJump(&j, code.size(), depth);
        jumps.push_back(j);
        pushCommand("JZERO B");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
}
;

value: NUM {
	if(assignFlag){
		std::cout << "Error [linia " << yylineno << "]: Próba przypisania do stałej." << std::endl;
		exit(1);
	}
	Variable s;
	newVariable(&s, $1, false, NUMBER);
	insertVariable($1, s);
	if (expressionArguments[0] == "-1"){
		expressionArguments[0] = $1;
	}
	else {
		expressionArguments[1] = $1;
	}
}
| identifier
;

identifier: IDENT {
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
			if (expressionArguments[0] == "-1"){
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
}
| IDENT LB IDENT RB {
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
			if (expressionArguments[0] == "-1"){
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
}
| IDENT LB NUM RB {
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
			if (expressionArguments[0] == "-1"){
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
;
%%



















void newJump(Jump *j, long long int stack, long long int depth) {
    j->codePosition = stack;
    j->depth = depth;
}

void addInt(long long int command, long long int val) {
    code.at(command) = code.at(command) + " " + std::to_string(val);
}

void substract(Variable a, Variable b, int isINC, int remove) {
	
    if(a.type == NUMBER && b.type == NUMBER) {
        long long int val = std::max(stoll(a.name) + isINC - stoll(b.name), (long long int) 0);
        setRegister("B", std::to_string(val));
        if(remove) {
            popVariable(a.name);
            popVariable(b.name);
        }
    }
    else if(a.type == NUMBER && b.type == IDENTIFIER) {
        setRegister("B", std::to_string(stoll(a.name) + isINC));
		memToRegister(b.memory, "C");
        pushCommand("SUB B C");
        if(remove)
            popVariable(a.name);
    }
    else if(a.type == IDENTIFIER && b.type == NUMBER) {
        setRegister("C", b.name);
		memToRegister(a.memory, "B");
		if(isINC) {
			pushCommand("INC B");
		}
        pushCommand("SUB B C");
        if(remove)
            popVariable(b.name);
    }
    else if(a.type == IDENTIFIER && b.type == IDENTIFIER) {
        if(a.name == b.name) {
            pushCommand("SUB B B");
            if(isINC)
                pushCommand("INC B");
        }
        else {
            memToRegister(a.memory, "B");
			memToRegister(b.memory, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
        }
    }
}

 void arraySubstract(Variable a, Variable b, Variable aIndex, Variable bIndex, int isINC, int remove) {
    if(a.type == NUMBER && b.type == ARRAY) {
        if(bIndex.type == NUMBER) {
            long long int addr = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            setRegister("B", std::to_string(stoll(a.name) + isINC));
			memToRegister(addr, "C");
            pushCommand("SUB B C");
            if(remove) {
                popVariable(a.name);
                popVariable(bIndex.name);
            }
        }
        else if(bIndex.type == IDENTIFIER) {
            arrayIndexToRegister(b, bIndex, "C");
            setRegister("B", std::to_string(stoll(a.name) + isINC));
            pushCommand("SUB B C");
            if(remove)
                popVariable(a.name);
        }
    }
    else if(a.type == ARRAY && b.type == NUMBER) {
        if(aIndex.type == NUMBER) {
            long long int addr = a.memory + stoll(aIndex.name) + 1 - a.beginTable;

			setRegister("C", b.name);
			memToRegister(addr, "B");
			if(isINC)
				pushCommand("INC B");
			pushCommand("SUB B C");
            
            if(remove) {
                popVariable(b.name);
                popVariable(aIndex.name);
            }
        }
        else if(aIndex.type == IDENTIFIER) {
			arrayIndexToRegister(a, aIndex, "B");   
			setRegister("C", b.name);
			
			if(isINC)
				pushCommand("INC B");

			pushCommand("SUB B C");
		
			if(remove)
				popVariable(b.name);
        }
    }
    else if(a.type == IDENTIFIER && b.type == ARRAY) {
        if(bIndex.type == NUMBER) {
            long long int addr = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            memToRegister(a.memory, "B");
			memToRegister(addr, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(remove)
                popVariable(bIndex.name);
        }
        else if(bIndex.type == IDENTIFIER) {
            arrayIndexToRegister(b, bIndex, "C");
            memToRegister(a.memory, "B");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
        }
    }
    else if(a.type == ARRAY && b.type == IDENTIFIER) {
        if(aIndex.type == NUMBER) {
            long long int addr = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            memToRegister(b.memory, "C");
			memToRegister(addr, "B");
			
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(remove)
                popVariable(aIndex.name);
        }
        else if(aIndex.type == IDENTIFIER) {
            arrayIndexToRegister(a, aIndex, "B");
            memToRegister(b.memory, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
        }
    }
    else if(a.type == ARRAY && b.type == ARRAY) {
        if(aIndex.type == NUMBER && bIndex.type == NUMBER) {
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            if(a.name == b.name && addrA == addrB) {
                pushCommand("SUB B B");
                if(isINC)
                    pushCommand("INC B");
            }
            else {
                memToRegister(addrA, "B");
				memToRegister(addrB, "C");
                if(isINC)
                    pushCommand("INC B");
                pushCommand("SUB B C");
            }
            if(remove) {
                popVariable(aIndex.name);
                popVariable(bIndex.name);
            }
        }
        else if(aIndex.type == NUMBER && bIndex.type == IDENTIFIER) {
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            arrayIndexToRegister(b, bIndex, "C");
            memToRegister(addrA, "B");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(remove)
                popVariable(aIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == NUMBER) {
            long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            arrayIndexToRegister(a, aIndex, "B");
            memToRegister(addrB, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(remove)
                popVariable(bIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == IDENTIFIER) {
            if(a.name == b.name && aIndex.name == bIndex.name) {
                pushCommand("SUB B B");
                if(isINC)
                    pushCommand("INC B");
            }
            else {
                arrayIndexToRegister(a, aIndex, "B");
				arrayIndexToRegister(b, bIndex, "C");
                if(isINC)
                    pushCommand("INC B");
                pushCommand("SUB B C");
            }
        }
    }
}

void addition(Variable a, Variable b) {
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
                pushCommand("INC B");
            }
            popVariable(c.name);
        }
        else {
            setRegister("B", c.name);
			memToRegister(d.memory, "C");
            pushCommand("ADD B C");
            popVariable(c.name);
        }
	} else if(a.type == IDENTIFIER && b.type == IDENTIFIER) {
		if(a.name == b.name) {
            memToRegister(a.memory, "B");
            pushCommand("ADD B B");
        }
        else {
            memToRegister(a.memory, "B");
			memToRegister(b.memory, "C");
            pushCommand("ADD B C");
        }
	}
}
void arrayAddition(Variable a, Variable b, Variable aIndex, Variable bIndex) {
	
	if((a.type == NUMBER && b.type == ARRAY) || (a.type == ARRAY && b.type == NUMBER)) {
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
					pushCommand("INC B");
				}
			}
            else {
                setRegister("C", a.name);
                memToRegister(addr, "B");
				pushCommand("ADD B C");
            }

            popVariable(a.name);
            popVariable(bIndex.name);
        }
        else if(bIndex.type == IDENTIFIER) { 

            arrayIndexToRegister(b, bIndex, "B");

			if(stoll(a.name) <= 3) {
				for(int i=0; i < stoll(a.name); i++) {
					pushCommand("INC B");
				}
			} else {
                setRegister("C", a.name);
				pushCommand("ADD B C");
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
            pushCommand("ADD B C");
            popVariable(cIndex.name);
        }
        else if(cIndex.type == IDENTIFIER) { 
			arrayIndexToRegister(b, cIndex, "B"); 
			memToRegister(a.memory, "C");
			pushCommand("ADD B C");
        }
    }
    else if(a.type == ARRAY && b.type == ARRAY) {
        if(aIndex.type == NUMBER && bIndex.type == NUMBER) {
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
            long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
            if(a.name == b.name && addrA == addrB) {
                memToRegister(addrA, "B");
                pushCommand("ADD B B");
            }
            else {
                memToRegister(addrA, "B");
				memToRegister(addrB, "C");
                pushCommand("ADD B C");
            }
            popVariable(aIndex.name);
            popVariable(bIndex.name);
        }
        else if(aIndex.type == NUMBER && bIndex.type == IDENTIFIER) { 
            long long int addrA = a.memory + stoll(aIndex.name) + 1 - a.beginTable;
			arrayIndexToRegister(b, bIndex, "B");
			memToRegister(addrA, "C");
			pushCommand("ADD B C");
            popVariable(aIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == NUMBER) {
			long long int addrB = b.memory + stoll(bIndex.name) + 1 - b.beginTable;
			arrayIndexToRegister(a, aIndex, "B");
			memToRegister(addrB, "C");
			pushCommand("ADD B C");
            popVariable(bIndex.name);
        }
        else if(aIndex.type == IDENTIFIER && bIndex.type == IDENTIFIER) {
            if(a.name == b.name && aIndex.name == bIndex.name) {
                arrayIndexToRegister(a, aIndex, "B");
				pushCommand("ADD B B");
            }
            else {
                arrayIndexToRegister(a, aIndex, "B");
				arrayIndexToRegister(b, bIndex, "C");

				pushCommand("ADD B C");
            }
        }
    }
}

void arrayIndexToRegister(Variable tab, Variable index, std::string reg) {
	long long int offset = tab.memory + 1;
	if(index.inRegister == "NULL") {
		memToRegister(index.memory, "C");
	} else {
		pushCommand("COPY C " + index.inRegister);
	}
	setRegister("A", std::to_string(offset));
	pushCommand("ADD A C");
	setRegister("C", std::to_string(tab.beginTable));
	pushCommand("SUB A C");
	pushCommand("LOAD " + reg);
}

void setRegister(std::string reg, std::string number) {
    long long int n = stoll(number);
	
    std::string bin = decToBin(n);
	long long int limit = bin.size();
   
	pushCommand("SUB " + reg + " " + reg);
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC " + reg);
			
		}
		if(i < (limit - 1)){
	        pushCommand("ADD " + reg + " " + reg);
	        
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

	pushCommand("SUB A A");
	std::string bin = decToBin(mem);
	long long int limit = bin.size();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC A");
			
		}
		if(i < (limit - 1)){
	        pushCommand("ADD A A");
	        
		}
	}
    pushCommand("LOAD " + reg); 
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
		pushCommand("COPY " + reg + " " + srcReg);
	} else {
		pushCommand("SUB A A");
		std::string bin = decToBin(mem);
		long long int limit = bin.size();
		for(long long int i = 0; i < limit; ++i){
			if(bin[i] == '1'){
				pushCommand("INC A");
				
			}
			if(i < (limit - 1)){
				pushCommand("ADD A A");
				
			}
		}
		pushCommand("LOAD " + reg); 
	}
}

std::string decToBin(long long int n) {
    std::string r;
    while(n!=0) {r=(n%2==0 ?"0":"1")+r; n/=2;}
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

	pushCommand("SUB A A");
	std::string bin = decToBin(mem);
	long long int limit = bin.size();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC A");
			
		}
		if(i < (limit - 1)){
	        pushCommand("ADD A A");
	        
		}
	}
    pushCommand("STORE " + reg); 
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
		pushCommand("COPY " + srcReg + " " + reg);
	} else {
		pushCommand("SUB A A");
		std::string bin = decToBin(mem);
		long long int limit = bin.size();
		for(long long int i = 0; i < limit; ++i){
			if(bin[i] == '1'){
				pushCommand("INC A");
				
			}
			if(i < (limit - 1)){
				pushCommand("ADD A A");
				
			}
		}
		pushCommand("STORE " + reg); 
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
		id->inRegister = registerValue();
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
			freeRegisters.push_back(reg);
			pushCommand("SUB " + reg + " " + reg);
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
	if(i.inRegister != "NULL")//debug
    	std::cout << "Add: " << key << " name: " << i.name << " type: " << i.type << " memory:" << memoryIndex-1 << " reg:" << i.inRegister << std::endl;
}

void pushCommand(std::string str) {
    code.push_back(str);
}

void pushCommand(std::string str, long long int num) {
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

std::string registerValue() {
	if(freeRegisters.size() > 0) {
		std::string reg = freeRegisters.at(freeRegisters.size()-1);
		freeRegisters.pop_back();
		return reg;
	} else {
		return "NULL";
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

	freeRegisters.push_back("E");
	freeRegisters.push_back("F");
	freeRegisters.push_back("G");
	freeRegisters.push_back("H");
	
	

	yyin = fopen(argv[1], "r");
    yyparse();

	if(argc < 3) {
		return -1;
	} else {
		printCode(argv[2]);
	}

	return 0;
}
