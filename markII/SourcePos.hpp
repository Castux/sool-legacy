#ifndef SOURCEPOS_HPP
#define SOURCEPOS_HPP

namespace sool
{
	class SourceFile;
	struct LineCol;
	
	class SourcePos
	{
		public:
		
		SourceFile *file;
		int begin;
		int end;
		
		SourcePos();
		SourcePos To(SourcePos other);
		std::string Text();
		
		void ToLineCol(LineCol *b, LineCol *e);
	};
}

#endif // SOURCEPOS_HPP

