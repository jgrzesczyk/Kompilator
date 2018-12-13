%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <sstream>
#include <cmath>
#include <vector>
#include <map>

typedef struct {
	std::string name;
    std::string type; //NUM, IDE, ARR
    bool initialized;
    int counter;
	long long int mem;
	bool local;
	bool isTable;
  	long long int beginTable;
	long long int endTable;
} Identifier;

typedef struct {
    long long int placeInStack;
    long long int depth;
} Jump;

std::vector<std::string> codeStack;
std::map<std::string, Identifier> idStack;

int yyerror (const std::string);
extern int yylineno;
extern FILE * yyin;
int yylex();


void add(Identifier a, Identifier b);
void addTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex);
void arrayIndexToRegister(Identifier tab, Identifier index, std::string reg);
void arrayIndexToRegister(Identifier tab, long long int index, std::string reg);
void setRegister(std::string, std::string);
void createIdentifier(Identifier* id, std::string name, bool isLocal, std::string type);
void createIdentifier(Identifier* id, std::string name, bool isLocal, std::string type, long long int begin, long long int end);
void removeIdentifier(std::string key);
void insertIdentifier(std::string key, Identifier i);
void pushCommand(std::string);
void pushCommand(std::string, long long int);
long long int valueInMemory(long long int mem);
void memToRegister(long long int, std::string);
std::string decToBin(long long int n);
void registerToMem(std::string, long long int);
long long int memCounter;
long long int depth;
bool assignFlag;
bool writeFlag;
Identifier assignTarget;
std::string tabAssignTargetIndex = "-1";
std::string expressionArguments[2] = {"-1", "-1"};
std::string argumentsTabIndex[2] = {"-1", "-1"};
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
		setRegister("B", std::to_string(ide.mem+1));
        registerToMem("B", ide.mem);
	}
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
			memToRegister(index.mem, "C");
			setRegister("A", std::to_string(offset));
			setRegister("D", std::to_string(assignTarget.beginTable));
			pushCommand("ADD A C");
			pushCommand("SUB A D");
			pushCommand("STORE B");
		}
	}
	else if(!assignTarget.local) {
		std::cout << "WPISUJE do pamiec" << assignTarget.mem << std::endl;
		registerToMem("B", assignTarget.mem);
	}
	else {
		std::cout << "Błąd [okolice linii " << yylineno << "]: Próba modyfikacji iteratora pętli." << std::endl;
		exit(1);
	}
	idStack.at(assignTarget.name).initialized = true;
	assignFlag = true;
}
| IF condition THEN commands ifbody {
	
}
| WHILE condition DO commands ENDWHILE {
	
}
| DO commands WHILE condition ENDDO {
	
}
| FOR IDENT FROM value forbody {
	
}
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
			memToRegister(index.mem, "C");
			setRegister("A", std::to_string(offset));
			setRegister("D", std::to_string(assignTarget.beginTable));
			pushCommand("ADD A C");
			pushCommand("SUB A D");
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
		
		if(false) { //todo warunek na zly indeks tablicy?
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
        if(bIndex.type == "NUM") { //  1+d(2)
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
        else if(bIndex.type == "IDE") { //1+d(b)

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
    
        if(cIndex.type == "NUM") { // a + d(1)
			long long int addr = b.mem + stoll(cIndex.name) + 1 - b.beginTable;
			memToRegister(a.mem, "B");
			memToRegister(addr, "C");
            pushCommand("ADD B C");
            removeIdentifier(cIndex.name);
        }
        else if(cIndex.type == "IDE") { // a + d(b)
			arrayIndexToRegister(b, cIndex, "B"); //wartosc z tablicy
			memToRegister(a.mem, "C");
			pushCommand("ADD B C");
        }
    }//todo do tej pory zrobione 
    else if(a.type == "ARR" && b.type == "ARR") {
        if(aIndex.type == "NUM" && bIndex.type == "NUM") {// a(2)+a(3)
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
        else if(aIndex.type == "NUM" && bIndex.type == "IDE") { //a(2)+a(b)
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
	memToRegister(index.mem, "C");
	setRegister("A", std::to_string(offset));
	setRegister("D", std::to_string(tab.beginTable));
	pushCommand("ADD A C");
	pushCommand("SUB A D");
	pushCommand("LOAD " + reg);
}
void arrayIndexToRegister(Identifier tab, long long int index, std::string reg) {
	long long int offset = tab.mem + 1 + index;
	setRegister("A", std::to_string(offset));
	setRegister("D", std::to_string(tab.beginTable));
	pushCommand("SUB A D");
	pushCommand("LOAD " + reg);
}

void setRegister(std::string reg, std::string number) {
	std::cout << "do rejestru "<< reg <<" przyposuje wartosc " << number << std::endl;
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

long long int valueInMemory(long long int mem) {
	std::string bin = decToBin(mem);
	long long int limit = bin.size(), value = 0;
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC A");
			value++;
		}
		if(i < (limit - 1)){
	        pushCommand("ADD A A");
	        value *= 2;
		}
	}
	return value;
}
void memToRegister(long long int mem, std::string reg) {
	std::cout << "do rejestru "<< reg <<" przyposuje wartosc z pamieci p_" << std::to_string(mem) << std::endl;
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
    pushCommand("LOAD " + reg); //todo many registers
}

std::string decToBin(long long int n) {
    std::string r;
    while(n!=0) {r=(n%2==0 ?"0":"1")+r; n/=2;}
    return r;
}

void registerToMem(std::string reg, long long int mem) {
	std::cout << "z rejestru "<< reg <<" przyposuje wartosc do pamieci p_" << std::to_string(mem) << std::endl;
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
    pushCommand("STORE " + reg); //todo many registers
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
}
void removeIdentifier(std::string key) {
    if(idStack.count(key) > 0) {
        if(idStack.at(key).counter > 0) {
            idStack.at(key).counter = idStack.at(key).counter-1;
        }
        else {
            idStack.erase(key);
            memCounter--;
        }
    }
    std::cout << "Remove: " << key << std::endl;
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
    std::cout << "Add: " << key << " name: " << i.name << " type: " << i.type << " memory:" << memCounter-1 << std::endl;
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

int main (int argc, char** argv) {
	assignFlag = true;
	memCounter = 12;
	writeFlag = false;
	depth = 0;

	yyin = fopen(argv[1], "r");
    yyparse();

	if(argc < 3) {
		printStdCode();
	} else {
		printCode(argv[2]);
	}
	return 0;
}

int yyerror(const std::string s) {
	std::cout << "Błąd [około linii " << yylineno << "]: " << s << std::endl;
	exit(1);
}