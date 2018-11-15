$(arg): $(arg).l
	flex $(arg).l
	g++ -o $(arg) lex.yy.c -lfl
	./$(arg) < $(arg).txt