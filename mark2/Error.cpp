#include <iostream>

#include "Error.h"
#include "color.h"

using namespace std;
using namespace sool;

void Error::Print()
{
	cout << origin << " ";
	
	switch(type)
	{
		case ErrError:
			cout << "error";
			break;
		case ErrWarning:
			cout << "warning";
			break;
		case ErrInfo:
			cout << "info";
			break;
	}
	
	return;
}
