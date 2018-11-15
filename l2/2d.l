%{
    #include <iostream>
    #include <stack>
    #include <string>
    #include <cstdlib>
    #include <cmath>
    //#define TRACE
    std::stack <int> numbers;
    bool error = false;
%}
%%
[-]?[1-9][0-9]* { 
    #ifdef TRACE 
    std::cout << strtol(yytext, NULL, 10) << " pushed\n";
    #endif
    numbers.push(strtol(yytext, NULL, 10));
}
[*] {
    if(numbers.size() < 2 && !error) {
        std::cout << "Za mało liczb!\n";
        error = true;
    }
    if(!error) {

        #ifdef TRACE 
        std::cout << "* pushed\n";
        #endif
        int a = numbers.top();
        numbers.pop();
        int b = numbers.top();
        numbers.pop();
        numbers.push(a*b);
    }
}
[-] {
    if(numbers.size() < 2 && !error) {
        std::cout << "Za mało liczb!\n";
        error = true;
    }
    if(!error) {

        #ifdef TRACE 
        std::cout << "- pushed\n";
        #endif
        int b = numbers.top();
        numbers.pop();
        int a = numbers.top();
        numbers.pop();
        numbers.push(a-b); 
    }
}

[+] {
    if(numbers.size() < 2 && !error) {
        std::cout << "Za mało liczb!\n";
        error = true;
    }
    if(!error) {

        #ifdef TRACE 
        std::cout << "+ pushed\n";
        #endif
        int b = numbers.top();
        numbers.pop();
        int a = numbers.top();
        numbers.pop();
        numbers.push(a+b); 
    }
}

[/] {
    if(numbers.size() < 2 && !error) {
        std::cout << "Za mało liczb!\n";
        error = true;
    }
    if(!error) {

        #ifdef TRACE 
        std::cout << "/ pushed\n";
        #endif
        int b = numbers.top();
        numbers.pop();
        int a = numbers.top();
        numbers.pop();
        if(b == 0){
            error = true;
            std::cout << "Dzielisz przez 0!\n";
        } else {
            numbers.push(a/b); 
        }
    }
}
[%] {
    if(numbers.size() < 2 && !error) {
        std::cout << "Za mało liczb!\n";
        error = true;
    }
    if(!error) {

        #ifdef TRACE 
        std::cout << "% pushed\n";
        #endif
        int b = numbers.top();
        numbers.pop();
        int a = numbers.top();
        numbers.pop();
        if(b == 0){
            error = true;
            std::cout << "Dzielisz przez 0!\n";
        } else {
            numbers.push(a%b); 
        }
    } 
} 
[\^] {
    if(numbers.size() < 2  && !error) {
        std::cout << "Za mało liczb!\n";
        error = true;
    }
    if(!error) {

        #ifdef TRACE 
        std::cout << "^ pushed\n";
        #endif
        int b = numbers.top();
        numbers.pop();
        int a = numbers.top();
        numbers.pop();
        numbers.push((int)pow(a,b));
    }
}
[\n] {
    if(numbers.size() != 1 && !error) {
        std::cout << "Za mało operatorów!\n";
    } else if(!error){ 
        std::cout << "= " << numbers.top() << "\n";
    }
    error = false;
    while(!numbers.empty()) {
        numbers.pop();
    }
}
[ \t] ;
[^0-9 \t*+\/\-\^%] {
    error = true;
    std::cout << "Zły znak \"" << yytext  << "\"!\n";
}


%% 
int main()
{
    yyin = stdin;
    yylex();
    return 0;
}

