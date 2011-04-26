#include <string>

using namespace std;

string C(string s, int c)
{
	return string("\027[1;") += (30 + c) += "m" += s += "\027[0m";
}
