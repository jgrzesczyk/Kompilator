#include <iostream>
#include <string>
#include <vector>
#include <algorithm>

std::vector<int> returnAlphabet(std::string pattern) {
	std::vector<int> alpha;
	for (unsigned i = 0; i < pattern.size(); ++i) {
		if (std::find(alpha.begin(), alpha.end(), pattern.at(i)) == alpha.end()) {
			alpha.push_back(pattern.at(i));
		}
        
	}

	return alpha;
}

std::vector< std::vector<int> > returnStates(std::string pattern, std::vector<int> alphabet) {
	std::vector< std::vector<int> > states;
	int offset;

	for (unsigned currState = 0; currState <= pattern.size(); ++currState) {

		std::vector<int> state;
		state.push_back(currState);
		for (unsigned currLetter = 0; currLetter < alphabet.size(); ++currLetter) {
			if (currState != pattern.size() && pattern.at(currState) == alphabet.at(currLetter)) {
				state.push_back(currState+1);
			} else {
				offset = 0;
				std::string changedPattern = pattern.substr(0, currState);
				changedPattern += alphabet.at(currLetter);
			//gdy i=6 to sprawdzam od 0 do 5 -> dla 0 biorę samą at(6), dla 1 biorę at(5) at(6) itd. 
			// domyslnie set 0 jak jest cos okej to setuję na 1..6
				for (unsigned matchSize = 0; matchSize < currState; ++matchSize) {

					bool match = true;
					
					for (unsigned i = 0; i <= matchSize; ++i) {
						if (changedPattern[currState - matchSize + i] != pattern[i]) {
							match = false;
							break;
						}
					}
					if (match) {
						offset = matchSize+1;
					}
				}

				state.push_back(offset);
			}
		}
		states.push_back(state);
	}

	return states;
}

int stateChanger(int currState, char c, std::vector<int> alphabet, std::vector< std::vector<int> > states) {

	for (unsigned i = 0; i < alphabet.size(); ++i) {
		if (c == alphabet[i]) {
			return states[currState][i + 1];
		}
	}
	return 0;
}

std::vector<int> matcher(std::string text, std::string pattern, int(*f)(int, char, std::vector<int>, std::vector< std::vector<int> >)) {
	int n = text.length(), q = 0;
	std::vector<int> offsets;
	std::vector<int> alphabet = returnAlphabet(pattern);
	std::vector< std::vector<int> > states = returnStates(pattern, alphabet);

	for (int i = 0; i < n; ++i) {
		q = f(q, text.at(i), alphabet, states);
		if (q == pattern.length()) {
			offsets.push_back(i + 1 - pattern.length());
		}
	}
	return offsets;
}

int main(int argc, char** argv) {
	if (argc != 3) {
		return -1;
	}
    
	std::string chain = argv[1];
	std::string pattern = argv[2];
	std::vector<int> offsets = matcher(chain, pattern, *stateChanger);

	unsigned counter = 0;
	std::cout << "Pattern - " << pattern << std::endl;
	std::cout << chain << std::endl;
	for (unsigned i = 0; i < chain.size() && counter < offsets.size(); i++) {
		if(offsets[counter] == i) {
			std::cout << "^";
			counter++;
		} else {
			std::cout << " ";
		}
        if(!(chain[i] >= 32 && chain[i] <= 126)) {
            i++;
        }
	}
	std::cout << std::endl;

	return 0;
}