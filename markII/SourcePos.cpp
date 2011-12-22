#include "common.hpp"
#include "SourcePos.hpp"
#include "SourceFile.hpp"

using namespace sool;

SourcePos::SourcePos() : file(NULL), begin(0), end(0)
{
}

SourcePos::SourcePos(SourceFile *f, uint b, uint e) : file(f), begin(b), end(e)
{
}

SourcePos SourcePos::To(SourcePos other)
{
	SourcePos temp;
	
	if(file != other.file)
		error("SourcePos::To() - different files");
	
	temp.file = file;
	temp.begin = begin;
	temp.end = other.end;
	
	return temp;
}

std::string SourcePos::Text()
{
	if(!file)
		error("SourcePos::Text() - no file");
	
	int len = end-begin+1;
	return file->text.substr(begin,len);
}

void SourcePos::ToLineCol(LineCol *b, LineCol *e)
{
	if(!file)
		error("SourcePos::ToLineCol() - no file");
	
	*b = file->ToLineCol(begin);
	*e = file->ToLineCol(end);
}
