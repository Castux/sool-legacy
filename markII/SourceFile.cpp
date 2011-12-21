#include <fstream>
#include <sstream>
#include <string>

#include "common.hpp"
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
	
	for(int i = 0 ; i < text.size() ; i++)
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

LineCol SourceFile::ToLineCol(int offset)
{
	LineCol tmp = {0,0};
	
	for(int i = 0 ; i < lines.size() ; i++)
	{
		if(offset <= lines[i].end)
		{
			tmp.line = i + 1;
			tmp.col = offset - lines[i].begin + 1;
			
			break;
		}
	}
	
	return tmp;
}
