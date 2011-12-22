#ifndef SOURCEPOS_HPP
#define SOURCEPOS_HPP

#include "common.hpp"

namespace sool
{
	class SourceFile;
	struct LineCol;
	
	class SourcePos
	{
		public:
		
		SourceFile *file;
		uint begin;
		uint end;
		
		SourcePos();
		SourcePos(SourceFile *f, uint b, uint e);
		SourcePos To(SourcePos other);
		std::string Text();
		
		void ToLineCol(LineCol *b, LineCol *e);
	};
}

#endif // SOURCEPOS_HPP

