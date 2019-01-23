%{
    #include <iostream>
    int lines = 1, words = 0;
%}
 
%% 
^[ \t]+ ;
[ \t]+$ ;
[ \t]+ {
    std::cout << " ";
}
[^ \t\n]+ {
    std::cout << yytext;
    words++;
}
[\n][ \t\n]*[^ \t\n] {
    std::cout << "\n" << yytext[yyleng-1];
    lines++;
}
[\n][ \t\n]* ;
%%
 
int main()
{
    yylex();
    std::cout << std::endl << "#words = " << words << " #lines = " << lines << std::endl;
}

