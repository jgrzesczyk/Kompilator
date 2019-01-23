3: lex.yy.c y.tab.c
	g++ -std=c++11 -g lex.yy.c y.tab.c -o 3
	rm y.tab.c y.tab.h lex.yy.c

lex.yy.c: y.tab.c 3.l
	lex 3.l

y.tab.c: 3.y
	yacc -d 3.y

clean: 
	rm -rf lex.yy.c y.tab.c y.tab.h 3

