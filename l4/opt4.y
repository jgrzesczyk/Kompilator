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

typedef struct {
	std::string name;
    std::string type;
    bool initialized;
    int counter;
	long long int mem;
	bool local;
	bool isTable;
  	long long int beginTable;
	long long int endTable;
	std::string inRegister;
} Identifier;

typedef struct {
    long long int placeInStack;
    long long int depth;
} Jump;

std::vector<std::string> codeStack;
std::map<std::string, Identifier> idStack;
std::vector<Jump> jumpStack;
std::vector<Identifier> forStack;

int yyerror (const std::string);
extern int yylineno;
extern FILE * yyin;
int yylex();

void addInt(long long int command, long long int val);
void createJump(Jump *j, long long int stack, long long int depth);
void add(Identifier a, Identifier b);
void addTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex);
void sub(Identifier, Identifier, int, int);
void subTab(Identifier, Identifier, Identifier, Identifier, int, int);
void arrayIndexToRegister(Identifier tab, Identifier index, std::string reg);
void setRegister(std::string, std::string);
void createIdentifier(Identifier* id, std::string name, bool isLocal, std::string type);
void createIdentifier(Identifier* id, std::string name, bool isLocal, std::string type, long long int begin, long long int end);
void removeIdentifier(std::string key);
void insertIdentifier(std::string key, Identifier i);
void pushCommand(std::string);
void pushCommand(std::string, long long int);
void memToRegister(long long int, std::string);
void memToRegister(std::string);
std::string decToBin(long long int n);
void registerToMem(std::string, long long int);
void registerToMem(std::string);
int isPowerOfTwo(long long int);
std::string registerValue();
long long int memCounter;
long long int depth;
bool assignFlag;
bool writeFlag;
std::vector<std::string> freeRegisters; //int freeRegisters;
Identifier assignTarget;
std::string tabAssignTargetIndex = "-1";
std::string expressionArguments[2] = {"-1", "-1"};
std::string argumentsTabIndex[2] = {"-1", "-1"};


Jump tj;
int indextj;
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
	if(idStack.find($2) != idStack.end()) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Kolejna deklaracja zmiennej " << $<str>2 << std::endl;
		exit(1);
	} else {
		Identifier ide;
		createIdentifier(&ide, $2, false, "IDE");
		insertIdentifier($2, ide);
	}
}
| declarations IDENT LB NUM INDEXER NUM RB COLON {
	if(idStack.find($2) != idStack.end()) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Kolejna deklaracja zmiennej " << $<str>2 << std::endl;
		exit(1);
	} else if (atoll($4) > atoll($6)) {
        std::cout << "Błąd [okolice linii " << yylineno << "]: Indeksy tablicy " << $<str>2 << " są niepoprawne" << std::endl;
		exit(1);
    } else if (atoll($4) < 0) {
        std::cout << "Błąd [okolice linii " << yylineno << "]: Początek tablicy o indeksie " << $<str>2 << " < 0!" << std::endl;
		exit(1);
    } else {
		Identifier ide;
		createIdentifier(&ide, $2, false, "ARR", atoll($4), atoll($6));
		insertIdentifier($2, ide);
		memCounter = memCounter + (atoll($6) - atoll($4) + 1);
		// setRegister("B", std::to_string(ide.mem+1));
        // registerToMem("B", ide.mem);
	}
}
;

newlabel: WHILE {
	assignFlag = false;
	Jump j;
	createJump(&j, codeStack.size(), depth);
	tj = j;
	indextj = jumpStack.size();
}
;

commands: commands command
| command
;

command: identifier ASSIGN {
	assignFlag = false;
} expression COLON {
	if(assignTarget.type == "ARR") {
		Identifier index = idStack.at(tabAssignTargetIndex);
		if(index.type == "NUM") {
			long long int tabElMem = assignTarget.mem + stoll(index.name) + 1 - assignTarget.beginTable;
			registerToMem("B", tabElMem);
			removeIdentifier(index.name);
		} else {
			long long int offset = assignTarget.mem + 1;

			if(index.inRegister == "NULL") {
				memToRegister(index.mem, "C");
				
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
	else if(!assignTarget.local) {
		registerToMem("B", assignTarget.mem);
	}
	else {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Próba modyfikacji iteratora pętli." << std::endl;
		exit(1);
	}
	idStack.at(assignTarget.name).initialized = true;
	assignFlag = true;
}
| IF {
	assignFlag = false;
	depth++;
} condition {
	assignFlag = true;
} THEN commands ifbody

| FOR IDENT {
	if(idStack.find($2)!=idStack.end()) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Kolejna deklaracja zmiennej " << $<str>2 << "." << std::endl;
		exit(1);
	} else {
		Identifier i;
		createIdentifier(&i, $2, true, "IDE");
		insertIdentifier($2, i);
	}
	assignFlag = false;
	assignTarget = idStack.at($2);
	depth++;
} FROM value forbody

| READ {
	assignFlag = true;
} identifier COLON {
	if(assignTarget.type == "ARR") {
		Identifier index = idStack.at(tabAssignTargetIndex);
		if(index.type == "NUM") {
			pushCommand("GET B");
			long long int tabElMem = assignTarget.mem + stoll(index.name) + 1 - assignTarget.beginTable;
			registerToMem("B", tabElMem);
			removeIdentifier(index.name);
		}
		else {
			long long int offset = assignTarget.mem + 1;
			if(index.inRegister == "NULL") {
				memToRegister(index.mem, "C");
				
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

	} else if(!assignTarget.local) {
		pushCommand("GET B"); //todo many r
		registerToMem("B", assignTarget.mem);
	} else {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Próba modyfikacji iteratora pętli." << std::endl;
        exit(1);
	}
	idStack.at(assignTarget.name).initialized = true;
	assignFlag = true;
}
| WRITE {
	assignFlag = false;
	writeFlag = true;
} value COLON {
	Identifier ide = idStack.at(expressionArguments[0]);

	if(ide.type == "NUM") {
		setRegister("B", ide.name);
		removeIdentifier(ide.name);
	} else if(ide.type == "IDE") {
		memToRegister(ide.mem, "B");
	} else {
		Identifier index = idStack.at(argumentsTabIndex[0]);
		if(index.type == "NUM") {
			long long int tabElMem = ide.mem + stoll(index.name) + 1 - ide.beginTable;
			memToRegister(tabElMem, "B");
			removeIdentifier(index.name);
		} else {
			arrayIndexToRegister(ide, index, "B");
		}
	}
	pushCommand("PUT B"); //todo many register
	assignFlag = true;
	writeFlag = false;
	expressionArguments[0] = "-1";
	argumentsTabIndex[0] = "-1";
}
| newlabel condition {
	assignFlag = true;
	depth++;
	jumpStack.insert(jumpStack.begin() + indextj, tj);
	for(int i=indextj; i<jumpStack.size(); ++i) {
		jumpStack[i].depth = depth;
	}
}  DO commands ENDWHILE {
	long long int stack;
	long long int jumpCount = jumpStack.size()-1;
	if(jumpCount > 2 && jumpStack.at(jumpCount-2).depth == depth) {
		stack = jumpStack.at(jumpCount-2).placeInStack;
		pushCommand("JUMP", stack);
		addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
		addInt(jumpStack.at(jumpCount-1).placeInStack, codeStack.size());
		jumpStack.pop_back();
	}
	else {
		stack = jumpStack.at(jumpCount-1).placeInStack;
		pushCommand("JUMP", stack);
		addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
	}
	jumpStack.pop_back();
	jumpStack.pop_back();

	depth--;
	assignFlag = true;
}
| DO {
	assignFlag = true;
	depth++;
	Jump j;
	createJump(&j, codeStack.size(), depth);
	jumpStack.push_back(j);
} commands newlabel condition ENDDO {
	long long int stack;
	long long int jumpCount = jumpStack.size()-1;
	if(jumpCount > 2 && jumpStack.at(jumpCount-2).depth == depth) {
		stack = jumpStack.at(jumpCount-2).placeInStack;
		pushCommand("JUMP", stack);
		addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
		addInt(jumpStack.at(jumpCount-1).placeInStack, codeStack.size());
		jumpStack.pop_back();
	}
	else {
		stack = jumpStack.at(jumpCount-1).placeInStack;
		pushCommand("JUMP", stack);
		addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
	}
	jumpStack.pop_back();
	jumpStack.pop_back();

	depth--;
	assignFlag = true;
} 
;


ifbody: ELSE {
	Jump j;
	createJump(&j, codeStack.size(), depth);
	jumpStack.push_back(j);
	
	pushCommand("JUMP");
	long long int jumpCount = jumpStack.size()-2;
	Jump jump = jumpStack.at(jumpCount);
	addInt(jump.placeInStack, codeStack.size());
	
	jumpCount--;
	if(jumpCount >= 0 && jumpStack.at(jumpCount).depth == depth) {
		addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
	}
	/*registerValue = -1;*/
	assignFlag = true;
} commands ENDIF {
	addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());

	jumpStack.pop_back();
	jumpStack.pop_back();
	if(jumpStack.size() >= 1 && jumpStack.at(jumpStack.size()-1).depth == depth) {
		jumpStack.pop_back();
	}
	depth--;
	assignFlag = true;
}
| ENDIF {
	long long int jumpCount = jumpStack.size()-1;
	addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
	jumpCount--;
	if(jumpCount >= 0 && jumpStack.at(jumpCount).depth == depth) {
		addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
		jumpStack.pop_back();
	}
	jumpStack.pop_back();
	depth--;
	assignFlag = true;
}
;


forbody: TO value DO {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);

	if(a.type == "NUM") {
		setRegister("B", a.name);
		removeIdentifier(a.name);
	}
	else if(a.type == "IDE") {
		memToRegister(a.mem, "B");
	}
	else {
		Identifier index = idStack.at(argumentsTabIndex[0]);
		if(index.type == "NUM") {
			long long int tabElMem = a.mem + stoll(index.name) + 1;
			memToRegister(tabElMem, "B");
			removeIdentifier(index.name);
		}
		else {
			arrayIndexToRegister(a, index, "B");
		}
	}
	registerToMem("B", assignTarget.mem);
	idStack.at(assignTarget.name).initialized = true;

	if(a.type != "ARR" && b.type != "ARR")
		sub(b, a, 1, 1);
	else {
		Identifier aI, bI;
		if(idStack.count(argumentsTabIndex[0]) > 0)
			aI = idStack.at(argumentsTabIndex[0]);
		if(idStack.count(argumentsTabIndex[1]) > 0)
			bI = idStack.at(argumentsTabIndex[1]);
		subTab(b, a, bI, aI, 1, 1);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";

	Identifier s;
	std::string name = "C" + std::to_string(depth);
	createIdentifier(&s, name, true, "IDE");
	insertIdentifier(name, s);

	registerToMem("B",idStack.at(name).mem);
	forStack.push_back(idStack.at(assignTarget.name));

	pushCommand("JZERO B");
	Jump jj;
	createJump(&jj, codeStack.size(), depth);
	jumpStack.push_back(jj);

	memToRegister(idStack.at(name).mem, "B");
	
	addInt(jumpStack.at(jumpStack.size()-1).placeInStack-1, codeStack.size());

	Jump j;
	createJump(&j, codeStack.size(), depth);
	jumpStack.push_back(j);
	pushCommand("JZERO B");
	pushCommand("DEC B");
	registerToMem("B", idStack.at(name).mem);
	assignFlag = true;

} commands ENDFOR {
	Identifier iterator = forStack.at(forStack.size()-1);
	memToRegister(iterator.mem, "B");
	pushCommand("INC B");
	registerToMem("B", iterator.mem);

	long long int jumpCount = jumpStack.size()-1;
	long long int stack = jumpStack.at(jumpCount-1).placeInStack;
	pushCommand("JUMP", stack);
	addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
	jumpStack.pop_back();
	jumpStack.pop_back();
	
	std::string name = "C" + std::to_string(depth);
	
	removeIdentifier(name); //#tu
	removeIdentifier(iterator.name);
	forStack.pop_back();

	depth--;
	assignFlag = true;
}
| DOWNTO value DO {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);

	if(a.type == "NUM") {
		setRegister("B", a.name);
		removeIdentifier(a.name);
	}
	else if(a.type == "IDE") {
		memToRegister(a.mem, "B");
	}
	else {
		Identifier index = idStack.at(argumentsTabIndex[0]);
		if(index.type == "NUM") {
			long long int tabElMem = a.mem + stoll(index.name) + 1;
			memToRegister(tabElMem, "B");
			removeIdentifier(index.name);
		}
		else {
			arrayIndexToRegister(a, index, "B");
		}
	}
	registerToMem("B", assignTarget.mem);
	idStack.at(assignTarget.name).initialized = true;

	if(a.type != "ARR" && b.type != "ARR")
		sub(a, b, 1, 1);
	else {
		Identifier aI, bI;
		if(idStack.count(argumentsTabIndex[0]) > 0)
			aI = idStack.at(argumentsTabIndex[0]);
		if(idStack.count(argumentsTabIndex[1]) > 0)
			bI = idStack.at(argumentsTabIndex[1]);
		subTab(a, b, aI, bI, 1, 1);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";

	Identifier s;
	std::string name = "C" + std::to_string(depth);
	createIdentifier(&s, name, true, "IDE");
	insertIdentifier(name, s);

	registerToMem("B",idStack.at(name).mem);
	forStack.push_back(idStack.at(assignTarget.name));

	pushCommand("JZERO B");
	Jump jj;
	createJump(&jj, codeStack.size(), depth);
	jumpStack.push_back(jj);

	memToRegister(idStack.at(name).mem, "B");
	
	addInt(jumpStack.at(jumpStack.size()-1).placeInStack-1, codeStack.size());

	Jump j;
	createJump(&j, codeStack.size(), depth);
	jumpStack.push_back(j);
	pushCommand("JZERO B");
	pushCommand("DEC B");
	registerToMem("B", idStack.at(name).mem);
	assignFlag = true;

} commands ENDFOR {
	Identifier iterator = forStack.at(forStack.size()-1);
	memToRegister(iterator.mem, "B");
	pushCommand("DEC B");
	registerToMem("B", iterator.mem);

	long long int jumpCount = jumpStack.size()-1;
	long long int stack = jumpStack.at(jumpCount-1).placeInStack;
	pushCommand("JUMP", stack);
	addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
	jumpStack.pop_back();
	jumpStack.pop_back();

	std::string name = "C" + std::to_string(depth);
	removeIdentifier(name);//#tu
	removeIdentifier(iterator.name);
	forStack.pop_back();

	depth--;
	assignFlag = true;
}
;

expression: value {
	Identifier ide = idStack.at(expressionArguments[0]);
	if(ide.type == "NUM") {
		setRegister("B", ide.name);
		removeIdentifier(ide.name);
	}
	else if(ide.type == "IDE") {
		memToRegister(ide.mem, "B");
	}
	else {
		Identifier index = idStack.at(argumentsTabIndex[0]);
		if(index.type == "NUM") {
			long long int tabElMem = ide.mem + stoll(index.name) + 1 - ide.beginTable;
			memToRegister(tabElMem, "B");
			removeIdentifier(index.name);
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
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);
	if(a.type != "ARR" && b.type != "ARR")
		add(a, b);
	else {
		Identifier aI, bI;
		if(idStack.count(argumentsTabIndex[0]) > 0)
			aI = idStack.at(argumentsTabIndex[0]);
		if(idStack.count(argumentsTabIndex[1]) > 0)
			bI = idStack.at(argumentsTabIndex[1]);
		addTab(a, b, aI, bI);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value SUB value {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);
	if(a.type != "ARR" && b.type != "ARR")
		sub(a, b, 0, 1);
	else {
		Identifier aI, bI;
		if(idStack.count(argumentsTabIndex[0]) > 0)
			aI = idStack.at(argumentsTabIndex[0]);
		if(idStack.count(argumentsTabIndex[1]) > 0)
			bI = idStack.at(argumentsTabIndex[1]);
		subTab(a, b, aI, bI, 0, 1);
		argumentsTabIndex[0] = "-1";
		argumentsTabIndex[1] = "-1";
	}
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value MUL value {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);
	Identifier aI, bI;
	if(idStack.count(argumentsTabIndex[0]) > 0)
		aI = idStack.at(argumentsTabIndex[0]);
	if(idStack.count(argumentsTabIndex[1]) > 0)
		bI = idStack.at(argumentsTabIndex[1]);

	if(a.type == "NUM" && b.type == "NUM") {
		long long int val = stoll(a.name) * stoll(b.name);
		setRegister("B", std::to_string(val));
		removeIdentifier(a.name);
		removeIdentifier(b.name);
	}
	else if(a.type == "NUM" && isPowerOfTwo(stoll(a.name)) > 0) {
		
		int times = isPowerOfTwo(stoll(a.name));                                                 
		if(b.type == "IDE")
			memToRegister(b.mem, "B");
		else if(b.type == "ARR" && bI.type == "NUM") {
			long long int addr = b.mem + stoll(bI.name) + 1 - b.beginTable;
			memToRegister(addr, "B");
			removeIdentifier(bI.name);
		}
		else {
			arrayIndexToRegister(b, bI, "B");
		}
		
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		jumpStack.push_back(jum);
		pushCommand("JZERO B");

		for(int i=0; i<times; ++i) {
			pushCommand("ADD B B");
		}

		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();

		removeIdentifier(a.name);
	}
	else if(b.type == "NUM" && isPowerOfTwo(stoll(b.name)) > 0) {
		
		int times = isPowerOfTwo(stoll(b.name));

		if(a.type == "IDE")
			memToRegister(a.mem, "B");
		else if(a.type == "ARR" && aI.type == "NUM") {
			long long int addr = a.mem + stoll(aI.name) + 1 - a.beginTable;
			memToRegister(addr, "B");
			removeIdentifier(aI.name);
		}
		else {
			arrayIndexToRegister(a, aI, "B");
		}
		
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		jumpStack.push_back(jum);
		pushCommand("JZERO B");

		for(int i=0; i<times; ++i) {
			pushCommand("ADD B B");
		}

		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();

		removeIdentifier(b.name);
	}
	else {
		if(a.type == "NUM") {
			setRegister("B", a.name);
		} else if(a.type == "IDE") {
			memToRegister(a.mem, "B");
		} else if(a.type == "ARR") {
			if(aI.type == "IDE")
				arrayIndexToRegister(a, aI, "B");
			else {
				long long int addr = a.mem + stoll(aI.name) + 1 - a.beginTable;
				memToRegister(addr, "B");
				removeIdentifier(aI.name);
			}
		}
		
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		jumpStack.push_back(jum);
		pushCommand("JZERO B");

		if(b.type == "NUM") {
			setRegister("C", b.name);
		} else if(b.type == "IDE") {
			memToRegister(b.mem, "C");
		} else if(b.type == "ARR") {
			if(bI.type == "IDE")
				arrayIndexToRegister(b, bI, "C");
			else {
				long long int addr = b.mem + stoll(bI.name) + 1 - b.beginTable;
				memToRegister(addr, "C");
				removeIdentifier(bI.name);
			}
		}
		
		pushCommand("JZERO C ",codeStack.size()+10);  
		pushCommand("SUB D D");
		pushCommand("JZERO B", codeStack.size()+9); 
		pushCommand("JODD B ", codeStack.size()+2); 
		pushCommand("JUMP", codeStack.size()+2);
		pushCommand("ADD D C");
		pushCommand("HALF B");
		pushCommand("ADD C C");
		pushCommand("JUMP",codeStack.size()-6);
		pushCommand("JUMP",codeStack.size()+2);

		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();

		pushCommand("SUB D D");
		pushCommand("COPY B D");	
	}

	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value DIV value {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);
	Identifier aI, bI;
	if(idStack.count(argumentsTabIndex[0]) > 0)
		aI = idStack.at(argumentsTabIndex[0]);
	if(idStack.count(argumentsTabIndex[1]) > 0)
		bI = idStack.at(argumentsTabIndex[1]);

	if(b.type == "NUM" && stoll(b.name) == 0) {
		setRegister("B", "0");
	}
	else if(a.type == "NUM" && stoll(a.name) == 0) {
		setRegister("B", "0");
	}
	else if(b.type == "NUM" && isPowerOfTwo(stoll(b.name)) > 0) {
		
		int times = isPowerOfTwo(stoll(b.name));
		
		if(a.type == "NUM") {
			setRegister("B", a.name);
			removeIdentifier(a.name);
		} else if(a.type == "IDE") {
			memToRegister(a.mem, "B");
		} else if(a.type == "ARR") {
			if(aI.type == "IDE")
				arrayIndexToRegister(a, aI, "B");
			else {
				long long int addr = a.mem + stoll(aI.name) + 1 - a.beginTable;
				memToRegister(addr, "B");
				removeIdentifier(aI.name);
			}
		}
		
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		jumpStack.push_back(jum);
		pushCommand("JZERO B");

		for(int i=0; i<times; ++i) {
			pushCommand("HALF B");
		}

		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();
	}
	else if(a.type == "NUM" && b.type == "NUM") {
		long long int val = stoll(a.name) / stoll(b.name);
		setRegister("B", std::to_string(val));
		removeIdentifier(a.name);
		removeIdentifier(b.name);
	} else {
		if(a.type == "NUM") {
			setRegister("B", a.name);
			removeIdentifier(a.name);
		} else if(a.type == "IDE") {
			memToRegister(a.mem, "B");
		} else if(a.type == "ARR") {
			if(aI.type == "IDE")
				arrayIndexToRegister(a, aI, "B");
			else {
				long long int addr = a.mem + stoll(aI.name) + 1 - a.beginTable;
				memToRegister(addr, "B");
				removeIdentifier(aI.name);
			}
		}
		
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		jumpStack.push_back(jum);
		pushCommand("JZERO B");

		if(b.type == "NUM") {
			setRegister("C", b.name);
			removeIdentifier(b.name);
		} else if(b.type == "IDE") {
			memToRegister(b.mem, "C");
		} else if(b.type == "ARR") {
			if(bI.type == "IDE")
				arrayIndexToRegister(b, bI, "C");
			else {
				long long int addr = b.mem + stoll(bI.name) + 1 - b.beginTable;
				memToRegister(addr, "C");
				removeIdentifier(bI.name);
			}
		}
		
		Jump juma;
		createJump(&juma, codeStack.size(), depth);
		jumpStack.push_back(juma);
		pushCommand("JZERO C");

		if ( std::find(freeRegisters.begin(), freeRegisters.end(), "E") != freeRegisters.end() )
			memToRegister("E");
		// if(freeRegisters < 4)
		// 	registerToMem("E");

		pushCommand("SUB E E"); 
		pushCommand("COPY D C");
		pushCommand("SUB D B");
		pushCommand("JZERO D",codeStack.size()+3); 
		pushCommand("SUB B B");
		pushCommand("JUMP", codeStack.size()+35); 
		
		pushCommand("COPY D B");
		pushCommand("SUB D C");
		pushCommand("JZERO D",codeStack.size()+2);
		pushCommand("JUMP",codeStack.size()+4); 
		pushCommand("SUB B B");
		pushCommand("INC B");
		pushCommand("JUMP", codeStack.size()+28); 

		pushCommand("COPY D C");
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",codeStack.size()+2);
		pushCommand("JUMP",codeStack.size()+3);
		pushCommand("ADD D D");
		pushCommand("JUMP",codeStack.size()-5);
		pushCommand("COPY A C");
		pushCommand("SUB A B");
		pushCommand("JZERO A",codeStack.size()+2);
		pushCommand("JUMP", codeStack.size()+10);
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",codeStack.size()+4);
		pushCommand("HALF D");
		pushCommand("ADD E E"); 
		pushCommand("JUMP",codeStack.size()-5);
		pushCommand("SUB B D");
		pushCommand("INC E"); 
		pushCommand("JUMP",codeStack.size()-12);
		pushCommand("COPY A D"); 
		pushCommand("SUB A C"); 
		pushCommand("JZERO A", codeStack.size()+4); 
		pushCommand("ADD E E"); 
		pushCommand("HALF D");
		pushCommand("JUMP", codeStack.size()-5);
		pushCommand("COPY B E");
		pushCommand("JUMP", codeStack.size()+2);

		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();
		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();

		pushCommand("SUB B B");

		if ( std::find(freeRegisters.begin(), freeRegisters.end(), "E") != freeRegisters.end() )
			memToRegister("E");
		// if(freeRegisters < 4)
			// memToRegister("E");
	}


	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value MOD value {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);
	Identifier aI, bI;
	if(idStack.count(argumentsTabIndex[0]) > 0)
		aI = idStack.at(argumentsTabIndex[0]);
	if(idStack.count(argumentsTabIndex[1]) > 0)
		bI = idStack.at(argumentsTabIndex[1]);

	if(b.type == "NUM" && stoll(b.name) == 0) {
		setRegister("B", "0");
	}
	else if(a.type == "NUM" && stoll(a.name) == 0) {
		setRegister("B", "0");
	}
	else if(a.type == "NUM" && b.type == "NUM") {
		long long int val = stoll(a.name) % stoll(b.name);
		setRegister("B", std::to_string(val));
		removeIdentifier(a.name);
		removeIdentifier(b.name);
	} else {
		if(a.type == "NUM") {
			setRegister("B", a.name);
			removeIdentifier(a.name);
		} else if(a.type == "IDE") {
			memToRegister(a.mem, "B");
		} else if(a.type == "ARR") {
			if(aI.type == "IDE")
				arrayIndexToRegister(a, aI, "B");
			else {
				long long int addr = a.mem + stoll(aI.name) + 1 - a.beginTable;
				memToRegister(addr, "B");
				removeIdentifier(aI.name);
			}
		}
		
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		jumpStack.push_back(jum);
		pushCommand("JZERO B");

		if(b.type == "NUM") {
			setRegister("C", b.name);
			removeIdentifier(b.name);
		} else if(b.type == "IDE") {
			memToRegister(b.mem, "C");
		} else if(b.type == "ARR") {
			if(bI.type == "IDE")
				arrayIndexToRegister(b, bI, "C");
			else {
				long long int addr = b.mem + stoll(bI.name) + 1 - b.beginTable;
				memToRegister(addr, "C");
				removeIdentifier(bI.name);
			}
		}
		
		Jump juma;
		createJump(&juma, codeStack.size(), depth);
		jumpStack.push_back(juma);
		pushCommand("JZERO C");

		pushCommand("COPY D C");
		pushCommand("SUB D B");
		pushCommand("JZERO D",codeStack.size()+2); 
		pushCommand("JUMP", codeStack.size()+25); 
		
		pushCommand("COPY D B");
		pushCommand("SUB D C");
		pushCommand("JZERO D",codeStack.size()+2);
		pushCommand("JUMP",codeStack.size()+3); 
		pushCommand("SUB B B");
		pushCommand("JUMP", codeStack.size()+19); 

		pushCommand("COPY D C");
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",codeStack.size()+2);
		pushCommand("JUMP",codeStack.size()+3);
		pushCommand("ADD D D");
		pushCommand("JUMP",codeStack.size()-5);
		pushCommand("COPY A C");
		pushCommand("SUB A B");
		pushCommand("JZERO A",codeStack.size()+2);
		pushCommand("JUMP", codeStack.size()+8);
		pushCommand("COPY A D");
		pushCommand("SUB A B");
		pushCommand("JZERO A",codeStack.size()+3);
		pushCommand("HALF D");
		pushCommand("JUMP",codeStack.size()-4);
		pushCommand("SUB B D");
		pushCommand("JUMP",codeStack.size()-10);
		pushCommand("JUMP", codeStack.size()+2);

		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();
		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
		jumpStack.pop_back();

		pushCommand("SUB B B");			
	}


	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
;

condition: value EQ value {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);

	if(a.type == "NUM" && b.type == "NUM") {
		if(stoll(a.name) == stoll(b.name))
			setRegister("B", "1");
		else
			setRegister("B", "0");
		removeIdentifier(a.name);
		removeIdentifier(b.name);
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		std::cout << "jump na " << codeStack.size() << " d:" << depth << "\n";
		jumpStack.push_back(jum);
		pushCommand("JZERO B");
	}
	else {
		Identifier aI, bI;
		if(idStack.count(argumentsTabIndex[0]) > 0)
			aI = idStack.at(argumentsTabIndex[0]);
		if(idStack.count(argumentsTabIndex[1]) > 0)
			bI = idStack.at(argumentsTabIndex[1]);

		if(a.type != "ARR" && b.type != "ARR")
			sub(b, a, 0, 0);
		else
			subTab(b, a, bI, aI, 0, 0);

		pushCommand("JZERO B", codeStack.size()+2);
		Jump j;
		createJump(&j, codeStack.size(), depth);
		jumpStack.push_back(j);
		pushCommand("JUMP");

		if(a.type != "ARR" && b.type != "ARR")
			sub(a, b, 0, 1);
		else
			subTab(a, b, aI, bI, 0, 1);

		pushCommand("JZERO B", codeStack.size()+2);
		Jump jj;
		createJump(&jj, codeStack.size(), depth);
		jumpStack.push_back(jj);
		pushCommand("JUMP");
	}

	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
}
| value NEQ value {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);

	if(a.type == "NUM" && b.type == "NUM") {
		if(stoll(a.name) != stoll(b.name))
			setRegister("B", "1");
		else
			setRegister("B", "0");
		removeIdentifier(a.name);
		removeIdentifier(b.name);
		Jump jum;
		createJump(&jum, codeStack.size(), depth);
		std::cout << "jump na " << codeStack.size() << " d:" << depth << "\n";
		jumpStack.push_back(jum);
		pushCommand("JZERO B");
	}
	else {
		Identifier aI, bI;
		if(idStack.count(argumentsTabIndex[0]) > 0)
			aI = idStack.at(argumentsTabIndex[0]);
		if(idStack.count(argumentsTabIndex[1]) > 0)
			bI = idStack.at(argumentsTabIndex[1]);

		if(a.type != "ARR" && b.type != "ARR")
			sub(b, a, 0, 0);
		else
			subTab(b, a, bI, aI, 0, 0);

		pushCommand("JZERO B", codeStack.size()+2);
		Jump j;
		createJump(&j, codeStack.size(), depth);
		jumpStack.push_back(j);
		pushCommand("JUMP");

		if(a.type != "ARR" && b.type != "ARR")
			sub(a, b, 0, 1);
		else
			subTab(a, b, aI, bI, 0, 1);

		addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size()+1);
		jumpStack.pop_back();
		Jump jj;
		createJump(&jj, codeStack.size(), depth);
		jumpStack.push_back(jj);
		pushCommand("JZERO B");
	}

	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
	argumentsTabIndex[0] = "-1";
	argumentsTabIndex[1] = "-1";
}
| value LT value {
	Identifier a = idStack.at(expressionArguments[0]);
	Identifier b = idStack.at(expressionArguments[1]);

	if(a.type == "NUM" && b.type == "NUM") {
		if(stoll(a.name) < stoll(b.name))
			setRegister("B","1");
		else
			setRegister("B","0");
		removeIdentifier(a.name);
		removeIdentifier(b.name);
	}
	else {
		if(a.type != "ARR" && b.type != "ARR")
			sub(b, a, 0, 1);
		else {
			Identifier aI, bI;
			if(idStack.count(argumentsTabIndex[0]) > 0)
				aI = idStack.at(argumentsTabIndex[0]);
			if(idStack.count(argumentsTabIndex[1]) > 0)
				bI = idStack.at(argumentsTabIndex[1]);
			subTab(b, a, bI, aI, 0, 1);
			argumentsTabIndex[0] = "-1";
			argumentsTabIndex[1] = "-1";
		}
	}

	Jump j;
	createJump(&j, codeStack.size(), depth);
	jumpStack.push_back(j);
	pushCommand("JZERO B");

	expressionArguments[0] = "-1";
	expressionArguments[1] = "-1";
}
| value GT value {
	Identifier a = idStack.at(expressionArguments[0]);
        Identifier b = idStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(b.name) < stoll(a.name))
                setRegister("B", "1");
            else
                setRegister("B", "0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 0, 1);
            else {
                Identifier aI, bI;
                if(idStack.count(argumentsTabIndex[0]) > 0)
                    aI = idStack.at(argumentsTabIndex[0]);
                if(idStack.count(argumentsTabIndex[1]) > 0)
                    bI = idStack.at(argumentsTabIndex[1]);
                subTab(a, b, aI, bI, 0, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);;
        pushCommand("JZERO B");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
}
| value LE value {
	Identifier a = idStack.at(expressionArguments[0]);
        Identifier b = idStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) <= stoll(b.name))
                setRegister("B", "1");
            else
                setRegister("B", "0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 1, 1);
            else {
                Identifier aI, bI;
                if(idStack.count(argumentsTabIndex[0]) > 0)
                    aI = idStack.at(argumentsTabIndex[0]);
                if(idStack.count(argumentsTabIndex[1]) > 0)
                    bI = idStack.at(argumentsTabIndex[1]);
                subTab(b, a, bI, aI, 1, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO B");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
}
| value GE value {
	Identifier a = idStack.at(expressionArguments[0]);
        Identifier b = idStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) >= stoll(b.name))
                setRegister("B", "1");
            else
                setRegister("B", "0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 1, 1);
            else {
                Identifier aI, bI;
                if(idStack.count(argumentsTabIndex[0]) > 0)
                    aI = idStack.at(argumentsTabIndex[0]);
                if(idStack.count(argumentsTabIndex[1]) > 0)
                    bI = idStack.at(argumentsTabIndex[1]);
                subTab(a, b, aI, bI, 1, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO B");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
}
;

value: NUM {
	if(assignFlag){
		std::cout << "Błąd [okolice linii " << yylineno << "]: Próba przypisania do stałej." << std::endl;
		exit(1);
	}
	Identifier s;
	createIdentifier(&s, $1, false, "NUM");
	insertIdentifier($1, s);
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
	if(idStack.find($1) == idStack.end()) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Niezadeklarowana zmienna " << $<str>1 << std::endl;
		exit(1);
	} 
	if(!idStack.at($1).isTable) {
		if(!assignFlag) {
			if(!idStack.at($1).initialized) {
				std::cout << "Błąd [okolice linii " << yylineno << "]: Użyta niezainicjowana zmienna " << $<str>1 << std::endl;
				exit(1);
			}
			if (expressionArguments[0] == "-1"){
				expressionArguments[0] = $1;
			}
			else{
				expressionArguments[1] = $1;
			}
		} else {
			assignTarget = idStack.at($1);
		}
	} else {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Przypisanie wartości do całej tablicy " << $<str>1 << std::endl;
		exit(1);
	}
}
| IDENT LB IDENT RB {
	if(idStack.find($1) == idStack.end()) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Niezadeklarowana zmienna " << $<str>1 << std::endl;
		exit(1);
	} 
	if(idStack.find($3) == idStack.end()) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Niezadeklarowana zmienna " << $<str>3 << std::endl;
		exit(1);
	} 

	if(!idStack.at($1).isTable) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Zmienna " << $<str>1 << " nie jest tablicą!" << std::endl;
		exit(1);
	} else {
		if(idStack.at($3).isTable) {
			std::cout << "Błąd [okolice linii " << yylineno << "]: Indeks tablicy nie może być zmienną tablicową!" << std::endl;
			exit(1);
		}
		if(!idStack.at($3).initialized) {
			std::cout << "Błąd [okolice linii " << yylineno << "]: Użyta zmienna " << $<str>3 << " nie jest zainicjowana!" << std::endl;
			exit(1);
		}
		
		if(false) { 
			std::cout << "Błąd [okolice linii " << yylineno << "]: Odwołanie do złego indeksu tablicy " << $<str>1 << "!" << std::endl;
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
			assignTarget = idStack.at($1);
			tabAssignTargetIndex = $3;
		}
	}
}
| IDENT LB NUM RB {
	if(idStack.find($1) == idStack.end()) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Niezadeklarowana zmienna " << $<str>1 << std::endl;
		exit(1);
	}
	if(!idStack.at($1).isTable) {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Zmienna " << $<str>1 << " nie jest tablicą!" << std::endl;
		exit(1);
	} else {
		if(!(idStack.at($1).beginTable <= atoll($3) && idStack.at($1).endTable >= atoll($3))) {
			std::cout << "Błąd [okolice linii " << yylineno << "]: Odwołanie do złego indeksu tablicy " << $<str>1 << "!" << std::endl;
			exit(1);
		}

		Identifier s;
		createIdentifier(&s, $3, false, "NUM");
		insertIdentifier($3, s);

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
			assignTarget = idStack.at($1);
			tabAssignTargetIndex = $3;
		}
	}

}
;
%%



















void createJump(Jump *j, long long int stack, long long int depth) {
    j->placeInStack = stack;
    j->depth = depth;
}

void addInt(long long int command, long long int val) {
    codeStack.at(command) = codeStack.at(command) + " " + std::to_string(val);
}

void sub(Identifier a, Identifier b, int isINC, int isRemoval) {
	
    if(a.type == "NUM" && b.type == "NUM") {
        long long int val = std::max(stoll(a.name) + isINC - stoll(b.name), (long long int) 0);
        setRegister("B", std::to_string(val));
        if(isRemoval) {
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
    }
    else if(a.type == "NUM" && b.type == "IDE") {
        setRegister("B", std::to_string(stoll(a.name) + isINC));
		memToRegister(b.mem, "C");
        pushCommand("SUB B C");
        if(isRemoval)
            removeIdentifier(a.name);
    }
    else if(a.type == "IDE" && b.type == "NUM") {
        setRegister("C", b.name);
		memToRegister(a.mem, "B");
		if(isINC) {
			pushCommand("INC B");
		}
        pushCommand("SUB B C");
        if(isRemoval)
            removeIdentifier(b.name);
    }
    else if(a.type == "IDE" && b.type == "IDE") {
        if(a.name == b.name) {
            pushCommand("SUB B B");
            if(isINC)
                pushCommand("INC B");
        }
        else {
            memToRegister(a.mem, "B");
			memToRegister(b.mem, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
        }
    }
}

 void subTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex, int isINC, int isRemoval) {
    if(a.type == "NUM" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.mem + stoll(bIndex.name) + 1 - b.beginTable;
            setRegister("B", std::to_string(stoll(a.name) + isINC));
			memToRegister(addr, "C");
            pushCommand("SUB B C");
            if(isRemoval) {
                removeIdentifier(a.name);
                removeIdentifier(bIndex.name);
            }
        }
        else if(bIndex.type == "IDE") {
            arrayIndexToRegister(b, bIndex, "C");
            setRegister("B", std::to_string(stoll(a.name) + isINC));
            pushCommand("SUB B C");
            if(isRemoval)
                removeIdentifier(a.name);
        }
    }
    else if(a.type == "ARR" && b.type == "NUM") {
        if(aIndex.type == "NUM") {
            long long int addr = a.mem + stoll(aIndex.name) + 1 - a.beginTable;

			setRegister("C", b.name);
			memToRegister(addr, "B");
			if(isINC)
				pushCommand("INC B");
			pushCommand("SUB B C");
            
            if(isRemoval) {
                removeIdentifier(b.name);
                removeIdentifier(aIndex.name);
            }
        }
        else if(aIndex.type == "IDE") {
			arrayIndexToRegister(a, aIndex, "B");   
			setRegister("C", b.name);
			
			if(isINC)
				pushCommand("INC B");

			pushCommand("SUB B C");
		
			if(isRemoval)
				removeIdentifier(b.name);
        }
    }
    else if(a.type == "IDE" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.mem + stoll(bIndex.name) + 1 - b.beginTable;
            memToRegister(a.mem, "B");
			memToRegister(addr, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(isRemoval)
                removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "IDE") {
            arrayIndexToRegister(b, bIndex, "C");
            memToRegister(a.mem, "B");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
        }
    }
    else if(a.type == "ARR" && b.type == "IDE") {
        if(aIndex.type == "NUM") {
            long long int addr = a.mem + stoll(aIndex.name) + 1 - a.beginTable;
            memToRegister(b.mem, "C");
			memToRegister(addr, "B");
			
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(isRemoval)
                removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "IDE") {
            arrayIndexToRegister(a, aIndex, "B");
            memToRegister(b.mem, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
        }
    }
    else if(a.type == "ARR" && b.type == "ARR") {
        if(aIndex.type == "NUM" && bIndex.type == "NUM") {
            long long int addrA = a.mem + stoll(aIndex.name) + 1 - a.beginTable;
            long long int addrB = b.mem + stoll(bIndex.name) + 1 - b.beginTable;
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
            if(isRemoval) {
                removeIdentifier(aIndex.name);
                removeIdentifier(bIndex.name);
            }
        }
        else if(aIndex.type == "NUM" && bIndex.type == "IDE") {
            long long int addrA = a.mem + stoll(aIndex.name) + 1 - a.beginTable;
            arrayIndexToRegister(b, bIndex, "C");
            memToRegister(addrA, "B");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(isRemoval)
                removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "NUM") {
            long long int addrB = b.mem + stoll(bIndex.name) + 1 - b.beginTable;
            arrayIndexToRegister(a, aIndex, "B");
            memToRegister(addrB, "C");
            if(isINC)
                pushCommand("INC B");
            pushCommand("SUB B C");
            if(isRemoval)
                removeIdentifier(bIndex.name);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "IDE") {
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

void add(Identifier a, Identifier b) {
	if(a.type == "NUM" && b.type == "NUM") {
		long long int val = stoll(a.name) + stoll(b.name);
        setRegister("B", std::to_string(val));
        removeIdentifier(a.name);
        removeIdentifier(b.name);
	} else if((a.type == "NUM" && b.type == "IDE") || (b.type == "NUM" && a.type == "IDE")) {
		Identifier c = ((a.type == "NUM") ? a : b);
		Identifier d = ((a.type == "NUM") ? b : a);
		if(stoll(c.name) <= 3) {
			memToRegister(d.mem, "B");
            for(int i=0; i < stoll(c.name); i++) {
                pushCommand("INC B");
            }
            removeIdentifier(c.name);
        }
        else {
            setRegister("B", c.name);
			memToRegister(d.mem, "C");
            pushCommand("ADD B C");
            removeIdentifier(c.name);
        }
	} else if(a.type == "IDE" && b.type == "IDE") {
		if(a.name == b.name) {
            memToRegister(a.mem, "B");
            pushCommand("ADD B B");
        }
        else {
            memToRegister(a.mem, "B");
			memToRegister(b.mem, "C");
            pushCommand("ADD B C");
        }
	}
}
void addTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex) {
	
	if((a.type == "NUM" && b.type == "ARR") || (a.type == "ARR" && b.type == "NUM")) {
		if(a.type == "ARR") {
			Identifier temp = a;
			a = b;
			b = temp;
			temp = aIndex;
			aIndex = bIndex;
			bIndex = temp;
		}
        if(bIndex.type == "NUM") { 
            long long int addr = b.mem + stoll(bIndex.name) + 1 - b.beginTable;

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

            removeIdentifier(a.name);
            removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "IDE") { 

            arrayIndexToRegister(b, bIndex, "B");

			if(stoll(a.name) <= 3) {
				for(int i=0; i < stoll(a.name); i++) {
					pushCommand("INC B");
				}
			} else {
                setRegister("C", a.name);
				pushCommand("ADD B C");
            }

            removeIdentifier(a.name);
        }
    }
    else if((a.type == "IDE" && b.type == "ARR") | (a.type == "ARR" && b.type == "IDE") ) {
		Identifier cIndex;
		if(a.type == "ARR") {
			Identifier temp = a;
			a = b;
			b = temp;
			cIndex = aIndex;
		} else {
			cIndex = bIndex;
		}
    
        if(cIndex.type == "NUM") { 
			long long int addr = b.mem + stoll(cIndex.name) + 1 - b.beginTable;
			memToRegister(a.mem, "B");
			memToRegister(addr, "C");
            pushCommand("ADD B C");
            removeIdentifier(cIndex.name);
        }
        else if(cIndex.type == "IDE") { 
			arrayIndexToRegister(b, cIndex, "B"); 
			memToRegister(a.mem, "C");
			pushCommand("ADD B C");
        }
    }
    else if(a.type == "ARR" && b.type == "ARR") {
        if(aIndex.type == "NUM" && bIndex.type == "NUM") {
            long long int addrA = a.mem + stoll(aIndex.name) + 1 - a.beginTable;
            long long int addrB = b.mem + stoll(bIndex.name) + 1 - b.beginTable;
            if(a.name == b.name && addrA == addrB) {
                memToRegister(addrA, "B");
                pushCommand("ADD B B");
            }
            else {
                memToRegister(addrA, "B");
				memToRegister(addrB, "C");
                pushCommand("ADD B C");
            }
            removeIdentifier(aIndex.name);
            removeIdentifier(bIndex.name);
        }
        else if(aIndex.type == "NUM" && bIndex.type == "IDE") { 
            long long int addrA = a.mem + stoll(aIndex.name) + 1 - a.beginTable;
			arrayIndexToRegister(b, bIndex, "B");
			memToRegister(addrA, "C");
			pushCommand("ADD B C");
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "NUM") {
			long long int addrB = b.mem + stoll(bIndex.name) + 1 - b.beginTable;
			arrayIndexToRegister(a, aIndex, "B");
			memToRegister(addrB, "C");
			pushCommand("ADD B C");
            removeIdentifier(bIndex.name);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "IDE") {
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

void arrayIndexToRegister(Identifier tab, Identifier index, std::string reg) {
	long long int offset = tab.mem + 1;
	if(index.inRegister == "NULL") {
		memToRegister(index.mem, "C");
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
	/*if (n == registerValue) {
		return;
	}*/
    std::string bin = decToBin(n);
	long long int limit = bin.size();
   
	pushCommand("SUB " + reg + " " + reg);
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC " + reg);
			/*registerValue++;*/
		}
		if(i < (limit - 1)){
	        pushCommand("ADD " + reg + " " + reg);
	        /*registerValue *= 2;*/
		}
	}
}

void memToRegister(std::string reg) {
	long long int mem;
	for (std::map<std::string, Identifier>::iterator it=idStack.begin(); it!=idStack.end(); ++it) {
		if(it->second.inRegister == reg) {
			mem = it->second.mem;
			break;
		}
	}

	pushCommand("SUB A A");
	std::string bin = decToBin(mem);
	long long int limit = bin.size();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC A");
			/*registerValue++;*/
		}
		if(i < (limit - 1)){
	        pushCommand("ADD A A");
	        /*registerValue *= 2;*/
		}
	}
    pushCommand("LOAD " + reg); 
}
void memToRegister(long long int mem, std::string reg) {

	std::string srcReg;
	bool flag = false;
	for (std::map<std::string, Identifier>::iterator it=idStack.begin(); it!=idStack.end(); ++it) {
		if(it->second.mem == mem && it->second.inRegister != "NULL") {
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
				/*registerValue++;*/
			}
			if(i < (limit - 1)){
				pushCommand("ADD A A");
				/*registerValue *= 2;*/
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
	for (std::map<std::string, Identifier>::iterator it=idStack.begin(); it!=idStack.end(); ++it) {
		if(it->second.inRegister == reg ) {
			mem = it->second.mem;
			break;
		}
	}

	pushCommand("SUB A A");
	std::string bin = decToBin(mem);
	long long int limit = bin.size();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC A");
			/*registerValue++;*/
		}
		if(i < (limit - 1)){
	        pushCommand("ADD A A");
	        /*registerValue *= 2;*/
		}
	}
    pushCommand("STORE " + reg); 
}
void registerToMem(std::string reg, long long int mem) {
	
	std::string srcReg;
	bool flag = false;
	for (std::map<std::string, Identifier>::iterator it=idStack.begin(); it!=idStack.end(); ++it) {
		if(it->second.mem == mem && it->second.inRegister != "NULL") {
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
				/*registerValue++;*/
			}
			if(i < (limit - 1)){
				pushCommand("ADD A A");
				/*registerValue *= 2;*/
			}
		}
		pushCommand("STORE " + reg); 
	}
}

void createIdentifier(Identifier* id, std::string name, bool isLocal, std::string type) {
	id->name = name;
	id->mem = memCounter;
	id->type = type;
	id->initialized = false;
	id->local = isLocal;
	id->isTable = false;
	id->beginTable = -1;
	id->endTable = -1;

	if(type != "IDE")
		id->inRegister = "NULL";
	else
		id->inRegister = registerValue();
}
void createIdentifier(Identifier* id, std::string name, bool isLocal, std::string type, long long int begin, long long int end) {
	id->name = name;
	id->mem = memCounter;
	id->type = type;
	id->initialized = false;
	id->local = isLocal;
	id->isTable = true;
	id->beginTable = begin;
	id->endTable = end;
	id->inRegister = "NULL";
}
void removeIdentifier(std::string key) {
    if(idStack.count(key) > 0) {
		std::string reg = idStack.at(key).inRegister;
		if(reg != "NULL") {
			freeRegisters.push_back(reg);
			pushCommand("SUB " + reg + " " + reg);
		}
        if(idStack.at(key).counter > 0) {
            idStack.at(key).counter = idStack.at(key).counter-1;
        }
        else {
            idStack.erase(key);
            memCounter--;
        }
    }
}
void insertIdentifier(std::string key, Identifier i) {
    if(idStack.count(key) == 0) {
        idStack.insert(make_pair(key, i));
        idStack.at(key).counter = 0;
        memCounter++;
    }
    else {
        idStack.at(key).counter = idStack.at(key).counter+1;
    }
	if(i.inRegister != "NULL")
    	std::cout << "Add: " << key << " name: " << i.name << " type: " << i.type << " memory:" << memCounter-1 << " reg:" << i.inRegister << std::endl;
}

void pushCommand(std::string str) {
    codeStack.push_back(str);
}

void pushCommand(std::string str, long long int num) {
    std::string temp = str + " " + std::to_string(num);
    codeStack.push_back(temp);
}

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
	// std::string registersTab[] = {"NULL","H","G","F","E"};
	// if(freeRegisters == 0) {
	// 	return registersTab[0];
	// } else {
	// 	freeRegisters--;
	// 	return registersTab[freeRegisters+1];
	// }
}

int yyerror(const std::string s) {
	std::cout << "Błąd [około linii " << yylineno << "]: " << s << std::endl;
	exit(1);
}


int main (int argc, char** argv) {

	assignFlag = true;
	memCounter = 0;
	writeFlag = false;
	depth = 0;

	freeRegisters.push_back("H");
	freeRegisters.push_back("G");
	freeRegisters.push_back("F");
	freeRegisters.push_back("E");
	
	//freeRegisters = 4;

	yyin = fopen(argv[1], "r");
    yyparse();

	if(argc < 3) {
		printStdCode();
	} else {
		printCode(argv[2]);
	}

	return 0;
}
