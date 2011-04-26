#ifndef LEXER_H
#define LEXER_H

#include <string>
#include <vector>

#include "Error.h"

using namespace std;

namespace sool
{

class Token
{
	public:
	
	string kind;	// Name, ClassName, Symbol, Number, String, or complete string for others
	string value;	// Original text
	Position pos;	// Position in source
};

class File
{
	string text;
	vector<Token> tokens;
	vector<Error> errors;
	
	void AddErr(ErrorType type, string message, Position pos = Position());
	
	public:
	
	bool ReadIn(const char *path);
	bool Tokenize();
	
	vector<Error> *GetErrors() { return &errors; }
};



}		// namespace sool

#endif	// LEXER_H
