default: main

DEBUG=0

#
# GNU gcc
# -pg
ifeq ($(DEBUG),1)
CC = gcc -g
CXX = g++ -g
else
CC = gcc -O3
CXX = g++ -O3
endif

######################
# TARGET
######################
OBJ = ./toojpeg/toojpeg.o bmpimage.o test.o

main: $(OBJ)
	$(CC) $(FLAGS) -o main $(OBJ) -lstdc++ -lm

clean:
	rm -f *.o *% core ./main ./toojpeg/*.o img.bmp img.jpg test.txt

./toojpeg/toojpeg.o: toojpeg/toojpeg.cpp toojpeg/toojpeg.h
#	$(CXX) -c ./toojpeg/toojpeg.cpp -o ./toojpeg/toojpeg.o
bmpimage.o: bmpimage.cpp bmpimage.h
test.o: test.cpp ./toojpeg/toojpeg.o bmpimage.o
