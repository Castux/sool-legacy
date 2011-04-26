#ifndef ERROR_H
#define ERROR_H

#include <string>

using namespace std;

namespace sool
{

class File;

class Position
{
	int first,last;
	File *file;
	
	public:
	
	Position() : first(0), last(0), file(NULL)
	{
	}
	
	Position(int f, int l, File *fp) : first(f), last(l), file(fp)
	{
	}
};

enum ErrorType
{
	ErrError,
	ErrWarning,
	ErrInfo
};

class Error
{
	string origin;
	ErrorType type;
	string message;
	Position pos;
	
	public:
	
	Error(string o, ErrorType t, string m, Position p) : origin(o), type(t), message(m), pos(p)
	{
	}
	
	void Print();
};

}	// namespace sool

#endif		// ERROR_H
