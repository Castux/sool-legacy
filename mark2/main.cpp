#include <iostream>
#include <string>

#include "Lexer.h"

using namespace std;

int main()
{
	sool::File f;
	
	if (!f.ReadIn("example.soola"))
	{
		(*f.GetErrors())[0].Print();
	}
	
	return 0;
}
