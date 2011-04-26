#include <fstream>
#include <iostream>

#include "Lexer.h"

using namespace std;
using namespace sool;

void File::AddErr(ErrorType type, string message, Position pos)
{
	errors.push_back(Error("Compiler", type, message, pos));
}

bool File::ReadIn(const char *path)
{
	ifstream file(path);
	char c;
	
	if(!file.is_open())
	{
		AddErr(ErrError, string("could not read file ") += path);
		return false;
	}
	
	while((c = file.get()) != EOF)
	{
		text += c;
	}
	
	file.close();
	
	return true;
}

bool File::Tokenize()
{
	return true;
}
