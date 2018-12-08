#include <vector>
#include <string>
enum options { GET, PUT, LOAD, STORE, COPY, ADD, SUB, HALF, INC, DEC, JUMP, JZERO, JODD, HALT };

struct instruction{
	enum options option;
	unsigned long long argument;
	int cost;
};

std::vector<instruction> instructions;

std::string option(enum options option){
	switch(option){
		case GET: return "GET";
		case PUT: return "PUT";
		case LOAD: return "LOAD";
		case STORE: return "STORE";
		case ADD: return "ADD";
		case SUB: return "SUB";
		case INC: return "INC";
		case DEC: return "DEC";
		case JUMP: return "JUMP";
		case JZERO: return "JZERO";
		case JODD: return "JODD";
		case HALT: return "HALT";		
	}
}

void addOperation(enum options option, unsigned long long argument){
	struct instruction newInstruction{};
	newInstruction.argument=argument;
	switch(option){
		case GET:
			newInstruction.option=GET;
			newInstruction.cost=100;
			break;
		case PUT:
			newInstruction.option=PUT;
			newInstruction.cost=100;
			break;
		case STORE:
			newInstruction.option=STORE;
			newInstruction.cost=10;
			break;
		case LOAD:
			newInstruction.option=LOAD;
			newInstruction.cost=10;
			break;
		case ADD:
			newInstruction.option=ADD;
			newInstruction.cost=10;
			break;
		case SUB:
			newInstruction.option=SUB;
			newInstruction.cost=10;
			break;
		case INC:
			newInstruction.option=INC;
			newInstruction.cost=1;
			break;
		case DEC:
			newInstruction.option=DEC;
			newInstruction.cost=1;
			break;
		case JUMP:
			newInstruction.option=JUMP;
			newInstruction.cost=1;
			break;
		case JZERO:
			newInstruction.option=JZERO;
			newInstruction.cost=10;
			break;
		case JODD:
			newInstruction.option=JODD;
			newInstruction.cost=10;
			break;
		case HALT:
			newInstruction.option=HALT;
			newInstruction.cost=0;
			break;
	}
    instructions.push_back(newInstruction);
}