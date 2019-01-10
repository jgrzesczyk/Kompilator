4: lex.yy.c y.tab.c
	g++ -std=c++11 -g lex.yy.c y.tab.c -o 4
	rm y.tab.c y.tab.h lex.yy.c

lex.yy.c: y.tab.c 4.l
	lex 4.l

y.tab.c: opt4.y
	yacc -d opt4.y

clean: 
	rm -rf lex.yy.c y.tab.c y.tab.h 4

t:
	./4 ./mytests/$(arg) ./maszyna/plik.txt
	./maszyna/maszyna-rejestrowa ./maszyna/plik.txt

gt:
	./4 ./officialtests/$(arg) ./maszyna/plik.txt
	./maszyna/maszyna-rejestrowa ./maszyna/plik.txt