4: lex.yy.c y.tab.c
	g++ -std=c++11 -g lex.yy.c y.tab.c -o 4
	rm y.tab.c y.tab.h lex.yy.c

lex.yy.c: y.tab.c 4.l
	lex 4.l

y.tab.c: 4.y
	yacc -d 4.y

clean: 
	rm -rf lex.yy.c y.tab.c y.tab.h 4

t:
	./4 ./data/test2.txt ./data/myerror0.imp
	./data/maszyna_rejestrowa/maszyna-rejestrowa ./data/myerror0.imp