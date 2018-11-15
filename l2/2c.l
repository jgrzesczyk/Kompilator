%{
    #include <iostream>
    bool leaveDoc = false;
%}
%x INBRACE
%x COMMENTING1
%x COMMENTING2
%%  
<INITIAL>[\"] {
    BEGIN(INBRACE);
    std::cout << yytext;
}
<INITIAL>[\/][\*] {
    if(!leaveDoc) {
        BEGIN(COMMENTING1);
    } else {
        std::cout << yytext;
    }
}
<INBRACE>(\\\\)*[\\][\"] std::cout << yytext;
<INBRACE>(\\\\)*[\"] {
    BEGIN(INITIAL);
    std::cout  << yytext;
}

<INBRACE>. std::cout << yytext;

<COMMENTING1>[\*][\/] {
    BEGIN(INITIAL);
}
<COMMENTING1>. ; 

<INITIAL>[\/][\/] {
    BEGIN(COMMENTING2);
}
<COMMENTING2>[\\]\n {
}
<COMMENTING2>\n {
    std::cout << yytext;
    BEGIN(INITIAL);
}
<COMMENTING2>. ;
%% 
 
int main(int argc, char** argv)
{ 
    if(argc > 1) {
        leaveDoc = true;
    }
    
    return yylex();
}

