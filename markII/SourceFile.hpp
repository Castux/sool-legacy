#ifndef SOURCEFILE_HPP
#define SOURCEFILE_HPP

#include <vector>

#include "SourcePos.hpp"

namespace sool
{
	class SourcePos;
	
	struct LineCol
	{
		uint line;
		uint col;
	};
	
	class SourceFile
	{
		public:
		
		std::string name;
		std::string text;
		std::vector<SourcePos> lines;
		
		// Read in file with given path, compute line positions
		// Return true in case of success, false otherwise
		bool Load(std::string path);
		
		// Convert offset into human-friendly line and column
		// Return {0,0} in case of error
		LineCol ToLineCol(uint offset);
	};
}

#endif // SOURCEFILE_HPP
