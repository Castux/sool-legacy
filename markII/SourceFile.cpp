#include <fstream>
#include <sstream>
#include <string>

#include "SourceFile.hpp"

using namespace sool;

bool SourceFile::Load(std::string path)
{
	std::ifstream file(path.c_str());
	
	if(!file.is_open())
	{
		return false;
	}
	
	// Load entire file
	
	std::stringstream tmp;
	tmp << file.rdbuf();
	text = tmp.str();
	
	name = path;
	
	// Fill in line positions
	
	int begin = 0;
	
	for(uint i = 0 ; i < text.size() ; i++)
	{
		if(text[i] == '\n')
		{
			SourcePos pos;
			pos.file = this;
			pos.begin = begin;
			pos.end = i;
			lines.push_back(pos);
			
			begin = i+1;
		}
	}
	
	return true;
}

LineCol SourceFile::ToLineCol(uint offset)
{
	LineCol tmp = {0,0};
	
	for(uint i = 0 ; i < lines.size() ; i++)
	{
		if(offset >= lines[i].begin && offset <= lines[i].end)
		{
			tmp.line = i + 1;
			tmp.col = offset - lines[i].begin + 1;
			
			break;
		}
	}
	
	return tmp;
}

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
